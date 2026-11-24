package services

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/security"
)

// CalendarSyncError is a failed ICS fetch or parse, reduced to one of the
// contract's last_error codes. It never carries the URL or the underlying
// error text, which can contain it.
type CalendarSyncError struct{ Code string }

func (e *CalendarSyncError) Error() string { return "calendar sync failed: " + e.Code }

func syncErr(code string) error { return &CalendarSyncError{Code: code} }

// ICSFetchResult is a fetched feed, or NotModified for a 304.
type ICSFetchResult struct {
	Body         []byte
	NotModified  bool
	ETag         string
	LastModified string
}

// ICSFetcher fetches an ICS subscription. Errors are *CalendarSyncError.
type ICSFetcher interface {
	Fetch(ctx context.Context, rawURL, etag, lastModified string) (*ICSFetchResult, error)
}

const (
	maxICSBytes     = 5 << 20
	maxICSRedirects = 5
	icsFetchTimeout = 20 * time.Second
	maxICSURLLength = 2048
)

// normalizeICSURL accepts https:// and webcal:// (read as https://) links.
func normalizeICSURL(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", &api.ValidationError{Field: "url", Message: "url is required"}
	}
	if len(raw) > maxICSURLLength {
		return "", &api.ValidationError{Field: "url", Message: "url is too long"}
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return "", &api.ValidationError{Field: "url", Message: "url must be an absolute https or webcal link"}
	}
	switch strings.ToLower(u.Scheme) {
	case "webcal", "webcals", "https":
		u.Scheme = "https"
	default:
		return "", &api.ValidationError{Field: "url", Message: "url must be an https or webcal link"}
	}
	if u.User != nil {
		return "", &api.ValidationError{Field: "url", Message: "url must not contain credentials"}
	}
	u.Fragment = ""
	return u.String(), nil
}

// safeICSFetcher fetches feeds with the repo's SSRF guard
// (security.ValidateAndResolveURL + NewPinnedTransport, as the recipe
// scraper does): every hop is https, re-validated and pinned to the
// addresses it was validated against, with a 5 MB cap and a timeout.
type safeICSFetcher struct {
	validate  func(ctx context.Context, raw string) (*security.ValidatedURL, error)
	transport func(v *security.ValidatedURL) http.RoundTripper
	timeout   time.Duration
	maxBytes  int64
}

// NewICSFetcher returns the production fetcher.
func NewICSFetcher() ICSFetcher {
	return &safeICSFetcher{
		validate: security.ValidateAndResolveURL,
		transport: func(v *security.ValidatedURL) http.RoundTripper {
			if t := security.NewPinnedTransport(v); t != nil {
				return t
			}
			return nil
		},
		timeout:  icsFetchTimeout,
		maxBytes: maxICSBytes,
	}
}

func (f *safeICSFetcher) Fetch(ctx context.Context, rawURL, etag, lastModified string) (*ICSFetchResult, error) {
	ctx, cancel := context.WithTimeout(ctx, f.timeout)
	defer cancel()

	current := rawURL
	for hop := 0; ; hop++ {
		u, err := url.Parse(current)
		if err != nil || !strings.EqualFold(u.Scheme, "https") {
			return nil, syncErr(models.CalendarErrFetchFailed)
		}
		validated, err := f.validate(ctx, current)
		if err != nil {
			return nil, syncErr(models.CalendarErrFetchFailed)
		}
		rt := f.transport(validated)
		if rt == nil {
			return nil, syncErr(models.CalendarErrFetchFailed)
		}
		resp, err := f.do(ctx, rt, validated.URL.String(), etag, lastModified)
		if t, ok := rt.(interface{ CloseIdleConnections() }); ok {
			defer t.CloseIdleConnections()
		}
		if err != nil {
			return nil, syncErr(models.CalendarErrFetchFailed)
		}
		if resp.StatusCode >= 300 && resp.StatusCode < 400 && resp.StatusCode != http.StatusNotModified {
			next, lerr := resp.Location()
			resp.Body.Close()
			if lerr != nil || hop >= maxICSRedirects {
				return nil, syncErr(models.CalendarErrFetchFailed)
			}
			current = next.String()
			continue
		}
		defer resp.Body.Close()
		return f.read(resp)
	}
}

func (f *safeICSFetcher) do(ctx context.Context, rt http.RoundTripper, target, etag, lastModified string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "text/calendar, text/plain;q=0.9, */*;q=0.5")
	req.Header.Set("User-Agent", "mitlist-calendar/1.0")
	if etag != "" {
		req.Header.Set("If-None-Match", etag)
	}
	if lastModified != "" {
		req.Header.Set("If-Modified-Since", lastModified)
	}
	client := &http.Client{
		Transport: rt,
		Timeout:   f.timeout,
		// Redirects are followed by hand so each hop is re-validated.
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	return client.Do(req)
}

func (f *safeICSFetcher) read(resp *http.Response) (*ICSFetchResult, error) {
	switch {
	case resp.StatusCode == http.StatusNotModified:
		return &ICSFetchResult{NotModified: true, ETag: resp.Header.Get("ETag"), LastModified: resp.Header.Get("Last-Modified")}, nil
	case resp.StatusCode == http.StatusUnauthorized, resp.StatusCode == http.StatusForbidden,
		resp.StatusCode == http.StatusNotFound, resp.StatusCode == http.StatusGone:
		// Google answers 404 once a secret address is reset.
		return nil, syncErr(models.CalendarErrUnauthorized)
	case resp.StatusCode != http.StatusOK:
		return nil, syncErr(models.CalendarErrFetchFailed)
	}
	if resp.ContentLength > f.maxBytes {
		return nil, syncErr(models.CalendarErrTooLarge)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, f.maxBytes+1))
	if err != nil {
		return nil, syncErr(models.CalendarErrFetchFailed)
	}
	if int64(len(body)) > f.maxBytes {
		return nil, syncErr(models.CalendarErrTooLarge)
	}
	return &ICSFetchResult{Body: body, ETag: resp.Header.Get("ETag"), LastModified: resp.Header.Get("Last-Modified")}, nil
}

// asSyncError maps any error to a CalendarSyncError, defaulting to
// fetch_failed, so nothing else (a URL inside a *url.Error) leaks.
func asSyncError(err error) *CalendarSyncError {
	var se *CalendarSyncError
	if errors.As(err, &se) {
		return se
	}
	return &CalendarSyncError{Code: models.CalendarErrFetchFailed}
}
