package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/security"
)

// testICSFetcher trusts srv's certificate and validates hops with validate.
func testICSFetcher(srv *httptest.Server, validate func(ctx context.Context, raw string) (*security.ValidatedURL, error)) *safeICSFetcher {
	return &safeICSFetcher{
		validate:  validate,
		transport: func(*security.ValidatedURL) http.RoundTripper { return srv.Client().Transport },
		timeout:   5 * time.Second,
		maxBytes:  1000,
	}
}

// allowHost validates like the real guard but lets the test server's
// loopback address through, and records every hop it saw.
func allowHost(host string, seen *[]string) func(ctx context.Context, raw string) (*security.ValidatedURL, error) {
	return func(ctx context.Context, raw string) (*security.ValidatedURL, error) {
		*seen = append(*seen, raw)
		u, err := url.Parse(raw)
		if err != nil {
			return nil, err
		}
		if u.Host != host {
			return security.ValidateAndResolveURL(ctx, raw)
		}
		return &security.ValidatedURL{URL: u, Port: u.Port()}, nil
	}
}

func syncCode(t *testing.T, err error) string {
	t.Helper()
	require.Error(t, err)
	se, ok := err.(*CalendarSyncError)
	require.True(t, ok, "%T %v", err, err)
	return se.Code
}

func TestICSFetcher_ConditionalGetAndStatuses(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/feed.ics":
			if r.Header.Get("If-None-Match") == "\"v1\"" && r.Header.Get("If-Modified-Since") == "Mon, 23 Nov 2026 10:00:00 GMT" {
				w.WriteHeader(http.StatusNotModified)
				return
			}
			w.Header().Set("ETag", "\"v1\"")
			w.Header().Set("Last-Modified", "Mon, 23 Nov 2026 10:00:00 GMT")
			_, _ = w.Write([]byte("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"))
		case "/gone":
			w.WriteHeader(http.StatusNotFound)
		case "/denied":
			w.WriteHeader(http.StatusUnauthorized)
		case "/broken":
			w.WriteHeader(http.StatusInternalServerError)
		case "/big":
			_, _ = w.Write([]byte(strings.Repeat("x", 1001)))
		case "/big-declared":
			w.Header().Set("Content-Length", "5000")
			_, _ = w.Write([]byte(strings.Repeat("x", 5000)))
		}
	}))
	defer srv.Close()
	host := strings.TrimPrefix(srv.URL, "https://")
	var seen []string
	f := testICSFetcher(srv, allowHost(host, &seen))
	ctx := context.Background()

	res, err := f.Fetch(ctx, srv.URL+"/feed.ics", "", "")
	require.NoError(t, err)
	assert.False(t, res.NotModified)
	assert.Equal(t, "\"v1\"", res.ETag)
	res, err = f.Fetch(ctx, srv.URL+"/feed.ics", res.ETag, res.LastModified)
	require.NoError(t, err)
	assert.True(t, res.NotModified)

	_, err = f.Fetch(ctx, srv.URL+"/gone", "", "")
	assert.Equal(t, "unauthorized", syncCode(t, err))
	_, err = f.Fetch(ctx, srv.URL+"/denied", "", "")
	assert.Equal(t, "unauthorized", syncCode(t, err))
	_, err = f.Fetch(ctx, srv.URL+"/broken", "", "")
	assert.Equal(t, "fetch_failed", syncCode(t, err))
	_, err = f.Fetch(ctx, srv.URL+"/big", "", "")
	assert.Equal(t, "too_large", syncCode(t, err))
	_, err = f.Fetch(ctx, srv.URL+"/big-declared", "", "")
	assert.Equal(t, "too_large", syncCode(t, err))
}

func TestICSFetcher_RedirectsAreRevalidated(t *testing.T) {
	var srv *httptest.Server
	srv = httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/hop":
			http.Redirect(w, r, "/feed.ics", http.StatusFound)
		case "/to-http":
			http.Redirect(w, r, "http://"+r.Host+"/feed.ics", http.StatusFound)
		case "/to-internal":
			http.Redirect(w, r, "https://169.254.169.254/latest/meta-data", http.StatusFound)
		case "/to-localhost":
			http.Redirect(w, r, "https://localhost/feed.ics", http.StatusFound)
		case "/loop":
			http.Redirect(w, r, "/loop", http.StatusFound)
		case "/feed.ics":
			_, _ = w.Write([]byte("BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n"))
		}
	}))
	defer srv.Close()
	host := strings.TrimPrefix(srv.URL, "https://")
	ctx := context.Background()

	var seen []string
	f := testICSFetcher(srv, allowHost(host, &seen))
	_, err := f.Fetch(ctx, srv.URL+"/hop", "", "")
	require.NoError(t, err)
	assert.Equal(t, []string{srv.URL + "/hop", srv.URL + "/feed.ics"}, seen, "every hop is validated")

	for _, path := range []string{"/to-http", "/to-internal", "/to-localhost", "/loop"} {
		seen = nil
		_, err := f.Fetch(ctx, srv.URL+path, "", "")
		assert.Equal(t, "fetch_failed", syncCode(t, err), path)
		assert.NotContains(t, err.Error(), host, path)
	}
}

func TestICSFetcher_ProductionGuardRefusesInternalTargets(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Error("the guard let a loopback request through")
	}))
	defer srv.Close()
	f := NewICSFetcher()
	for _, target := range []string{srv.URL + "/feed.ics", "https://127.0.0.1/x.ics", "https://10.0.0.1/x.ics", "https://[::1]/x.ics", "https://localhost/x.ics", "http://example.com/x.ics"} {
		_, err := f.Fetch(context.Background(), target, "", "")
		assert.Equal(t, "fetch_failed", syncCode(t, err), target)
	}
}

func TestNormalizeICSURL(t *testing.T) {
	got, err := normalizeICSURL(" webcal://p52-caldav.icloud.com/published/2/abc#frag ")
	require.NoError(t, err)
	assert.Equal(t, "https://p52-caldav.icloud.com/published/2/abc", got)
	got, err = normalizeICSURL("https://calendar.google.com/calendar/ical/x/private-y/basic.ics")
	require.NoError(t, err)
	assert.Equal(t, "https://calendar.google.com/calendar/ical/x/private-y/basic.ics", got)
	for _, bad := range []string{"", "http://example.com/a.ics", "file:///etc/passwd", "/relative.ics", "https://u:p@example.com/a", "https://" + strings.Repeat("a", 2100)} {
		_, err := normalizeICSURL(bad)
		assert.Error(t, err, bad)
	}
}
