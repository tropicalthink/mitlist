// Command smoke verifies a deployed mitlist API. Its default read-only mode
// checks liveness and readiness. Full mode creates a disposable account and
// household, exercises auth, lists, object storage, quota accounting, cleanup,
// and account deletion.
package main

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

type config struct {
	baseURL     string
	mode        string
	allowWrites bool
	emailDomain string
	timeout     time.Duration
	out         io.Writer
}

type client struct {
	baseURL string
	http    *http.Client
	out     io.Writer
}

type tokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

type entity struct {
	ID string `json:"id"`
}

type uploadIntent struct {
	Attachment entity `json:"attachment"`
	UploadURL  string `json:"upload_url"`
}

type storageUsage struct {
	UsedBytes     int64 `json:"used_bytes"`
	ReservedBytes int64 `json:"reserved_bytes"`
	LimitBytes    int64 `json:"limit_bytes"`
	Unlimited     bool  `json:"unlimited"`
}

type createdResources struct {
	accessToken  string
	attachmentID string
	groupID      string
	listID       string
}

func main() {
	var cfg config
	flag.StringVar(&cfg.baseURL, "base-url", os.Getenv("MITLIST_SMOKE_BASE_URL"), "deployed API origin, for example https://api.mitlist.me")
	flag.StringVar(&cfg.mode, "mode", "read-only", "smoke depth: read-only or full")
	flag.BoolVar(&cfg.allowWrites, "allow-writes", false, "required with -mode=full; creates and deletes disposable production data")
	flag.StringVar(&cfg.emailDomain, "email-domain", "example.invalid", "domain for the disposable smoke account")
	flag.DurationVar(&cfg.timeout, "timeout", 45*time.Second, "overall smoke-test timeout")
	cfg.out = os.Stdout
	flag.Parse()

	if err := run(context.Background(), cfg); err != nil {
		fmt.Fprintf(os.Stderr, "smoke failed: %v\n", err)
		os.Exit(1)
	}
}

func run(parent context.Context, cfg config) error {
	baseURL, err := normalizeBaseURL(cfg.baseURL)
	if err != nil {
		return err
	}
	if cfg.out == nil {
		cfg.out = io.Discard
	}
	if cfg.timeout <= 0 {
		return errors.New("timeout must be positive")
	}
	if cfg.mode != "read-only" && cfg.mode != "full" {
		return errors.New("mode must be read-only or full")
	}
	if cfg.mode == "full" && !cfg.allowWrites {
		return errors.New("full mode requires the explicit -allow-writes flag")
	}

	ctx, cancel := context.WithTimeout(parent, cfg.timeout)
	defer cancel()
	c := &client{
		baseURL: baseURL,
		http: &http.Client{
			Timeout: min(cfg.timeout, 15*time.Second),
			CheckRedirect: func(req *http.Request, via []*http.Request) error {
				if len(via) >= 3 {
					return errors.New("too many redirects")
				}
				return nil
			},
		},
		out: cfg.out,
	}

	if err := c.expect(ctx, http.MethodGet, "/healthz", "", nil, http.StatusOK, nil); err != nil {
		return fmt.Errorf("liveness: %w", err)
	}
	c.pass("liveness")
	if err := c.expect(ctx, http.MethodGet, "/readyz", "", nil, http.StatusOK, nil); err != nil {
		return fmt.Errorf("readiness: %w", err)
	}
	c.pass("readiness")
	if cfg.mode == "read-only" {
		fmt.Fprintln(cfg.out, "smoke passed (read-only)")
		return nil
	}

	if err := validateEmailDomain(cfg.emailDomain); err != nil {
		return err
	}
	if err := c.fullJourney(ctx, cfg.emailDomain); err != nil {
		return err
	}
	fmt.Fprintln(cfg.out, "smoke passed (full journey; resources cleaned up)")
	return nil
}

func (c *client) fullJourney(ctx context.Context, emailDomain string) (runErr error) {
	suffix, err := randomHex(8)
	if err != nil {
		return fmt.Errorf("generate smoke identity: %w", err)
	}
	passwordPart, err := randomHex(16)
	if err != nil {
		return fmt.Errorf("generate smoke password: %w", err)
	}
	email := fmt.Sprintf("mitlist-smoke+%s@%s", suffix, emailDomain)
	password := "Sm0ke!" + passwordPart
	resources := &createdResources{}
	defer func() {
		if runErr != nil {
			c.cleanup(resources)
		}
	}()

	var registered tokenPair
	if err := c.expect(ctx, http.MethodPost, "/api/v1/auth/register", "", map[string]any{
		"email": email, "password": password, "first_name": "Smoke", "last_name": "Check",
	}, http.StatusCreated, &registered); err != nil {
		return fmt.Errorf("register: %w", err)
	}
	if err := requireTokens(registered); err != nil {
		return fmt.Errorf("register: %w", err)
	}
	resources.accessToken = registered.AccessToken
	c.pass("register")

	var refreshed tokenPair
	if err := c.expect(ctx, http.MethodPost, "/api/v1/auth/token/refresh", "", map[string]string{
		"refresh_token": registered.RefreshToken,
	}, http.StatusOK, &refreshed); err != nil {
		return fmt.Errorf("refresh rotation: %w", err)
	}
	if err := requireTokens(refreshed); err != nil {
		return fmt.Errorf("refresh rotation: %w", err)
	}
	resources.accessToken = refreshed.AccessToken
	c.pass("refresh rotation")

	// A second independent session remains available for deterministic cleanup
	// after the first session is revoked by the logout check.
	var cleanupSession tokenPair
	if err := c.expect(ctx, http.MethodPost, "/api/v1/auth/login", "", map[string]string{
		"email": email, "password": password,
	}, http.StatusOK, &cleanupSession); err != nil {
		return fmt.Errorf("login: %w", err)
	}
	if err := requireTokens(cleanupSession); err != nil {
		return fmt.Errorf("login: %w", err)
	}
	c.pass("login")

	var group entity
	if err := c.expect(ctx, http.MethodPost, "/api/v1/groups", refreshed.AccessToken, map[string]string{
		"name": "Smoke Household " + suffix, "currency": "EUR",
	}, http.StatusCreated, &group); err != nil {
		return fmt.Errorf("create household: %w", err)
	}
	if group.ID == "" {
		return errors.New("create household: response has no id")
	}
	resources.groupID = group.ID
	c.pass("create household")

	var list entity
	if err := c.expect(ctx, http.MethodPost, "/api/v1/lists", refreshed.AccessToken, map[string]string{
		"group_id": group.ID, "name": "Smoke List", "type": "shopping",
	}, http.StatusCreated, &list); err != nil {
		return fmt.Errorf("create list: %w", err)
	}
	if list.ID == "" {
		return errors.New("create list: response has no id")
	}
	resources.listID = list.ID
	var item entity
	if err := c.expect(ctx, http.MethodPost, "/api/v1/lists/"+url.PathEscape(list.ID)+"/items", refreshed.AccessToken, map[string]any{
		"name": "Smoke item", "quantity": 1, "unit": "pc",
	}, http.StatusCreated, &item); err != nil {
		return fmt.Errorf("create list item: %w", err)
	}
	if item.ID == "" {
		return errors.New("create list item: response has no id")
	}
	var items []entity
	if err := c.expect(ctx, http.MethodGet, "/api/v1/lists/"+url.PathEscape(list.ID)+"/items", refreshed.AccessToken, nil, http.StatusOK, &items); err != nil {
		return fmt.Errorf("read list items: %w", err)
	}
	foundItem := false
	for _, listedItem := range items {
		if listedItem.ID == item.ID {
			foundItem = true
			break
		}
	}
	if !foundItem {
		return errors.New("read list items: created item was not returned")
	}
	c.pass("list write/read path")

	var initial storageUsage
	usagePath := "/api/v1/attachments/storage-usage?group_id=" + url.QueryEscape(group.ID)
	if err := c.expect(ctx, http.MethodGet, usagePath, refreshed.AccessToken, nil, http.StatusOK, &initial); err != nil {
		return fmt.Errorf("initial storage usage: %w", err)
	}
	if initial.UsedBytes != 0 || initial.ReservedBytes != 0 {
		return fmt.Errorf("new household storage is not empty: used=%d reserved=%d", initial.UsedBytes, initial.ReservedBytes)
	}
	if !initial.Unlimited && initial.LimitBytes <= 0 {
		return errors.New("storage quota response has no positive limit")
	}
	c.pass("storage quota read")

	payload := []byte("mitlist production smoke\n")
	var intent uploadIntent
	if err := c.expect(ctx, http.MethodPost, "/api/v1/attachments/upload-intent", refreshed.AccessToken, map[string]any{
		"group_id": group.ID, "purpose": "debug_diagnostic", "filename": "smoke.txt",
		"content_type": "text/plain", "byte_size": len(payload),
	}, http.StatusCreated, &intent); err != nil {
		return fmt.Errorf("create upload intent: %w", err)
	}
	if intent.Attachment.ID == "" || intent.UploadURL == "" {
		return errors.New("create upload intent: response is incomplete")
	}
	resources.attachmentID = intent.Attachment.ID

	var reserved storageUsage
	if err := c.expect(ctx, http.MethodGet, usagePath, refreshed.AccessToken, nil, http.StatusOK, &reserved); err != nil {
		return fmt.Errorf("reserved storage usage: %w", err)
	}
	if reserved.ReservedBytes < int64(len(payload)) {
		return fmt.Errorf("storage reservation missing: got %d bytes", reserved.ReservedBytes)
	}
	c.pass("atomic quota reservation")

	if err := c.upload(ctx, intent.UploadURL, payload); err != nil {
		return fmt.Errorf("object upload: %w", err)
	}
	if err := c.expect(ctx, http.MethodPost, "/api/v1/attachments/"+url.PathEscape(intent.Attachment.ID)+"/finalize", refreshed.AccessToken, map[string]string{
		"group_id": group.ID,
	}, http.StatusOK, &entity{}); err != nil {
		return fmt.Errorf("finalize upload: %w", err)
	}
	var finalized storageUsage
	if err := c.expect(ctx, http.MethodGet, usagePath, refreshed.AccessToken, nil, http.StatusOK, &finalized); err != nil {
		return fmt.Errorf("finalized storage usage: %w", err)
	}
	if finalized.UsedBytes < int64(len(payload)) || finalized.ReservedBytes != 0 {
		return fmt.Errorf("storage finalization incorrect: used=%d reserved=%d", finalized.UsedBytes, finalized.ReservedBytes)
	}
	c.pass("object upload and quota finalization")

	if err := c.expect(ctx, http.MethodDelete, "/api/v1/attachments/"+url.PathEscape(intent.Attachment.ID)+"?group_id="+url.QueryEscape(group.ID), refreshed.AccessToken, nil, http.StatusNoContent, nil); err != nil {
		return fmt.Errorf("delete attachment: %w", err)
	}
	resources.attachmentID = ""
	var afterDelete storageUsage
	if err := c.expect(ctx, http.MethodGet, usagePath, refreshed.AccessToken, nil, http.StatusOK, &afterDelete); err != nil {
		return fmt.Errorf("storage usage after delete: %w", err)
	}
	if afterDelete.UsedBytes != 0 || afterDelete.ReservedBytes != 0 {
		return fmt.Errorf("storage was not released: used=%d reserved=%d", afterDelete.UsedBytes, afterDelete.ReservedBytes)
	}
	c.pass("attachment deletion and quota release")

	if err := c.expect(ctx, http.MethodDelete, "/api/v1/lists/"+url.PathEscape(list.ID), refreshed.AccessToken, nil, http.StatusNoContent, nil); err != nil {
		return fmt.Errorf("delete list: %w", err)
	}
	resources.listID = ""
	if err := c.expect(ctx, http.MethodDelete, "/api/v1/groups/"+url.PathEscape(group.ID), refreshed.AccessToken, nil, http.StatusNoContent, nil); err != nil {
		return fmt.Errorf("delete household: %w", err)
	}
	resources.groupID = ""
	c.pass("household cleanup")

	// Preserve the independent session for deferred account cleanup before
	// revoking the session under test.
	resources.accessToken = cleanupSession.AccessToken
	if err := c.expect(ctx, http.MethodPost, "/api/v1/auth/logout", refreshed.AccessToken, map[string]string{
		"refresh_token": refreshed.RefreshToken,
	}, http.StatusNoContent, nil); err != nil {
		return fmt.Errorf("logout: %w", err)
	}
	if err := c.expect(ctx, http.MethodGet, "/api/v1/auth/me", refreshed.AccessToken, nil, http.StatusUnauthorized, nil); err != nil {
		return fmt.Errorf("logout revocation: %w", err)
	}
	c.pass("logout revocation")

	if err := c.expect(ctx, http.MethodDelete, "/api/v1/auth/me", cleanupSession.AccessToken, nil, http.StatusNoContent, nil); err != nil {
		return fmt.Errorf("delete smoke account: %w", err)
	}
	resources.accessToken = ""
	c.pass("account cleanup")
	return nil
}

func (c *client) cleanup(resources *createdResources) {
	if resources == nil || resources.accessToken == "" {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if resources.attachmentID != "" && resources.groupID != "" {
		_ = c.expectStatuses(ctx, http.MethodDelete, "/api/v1/attachments/"+url.PathEscape(resources.attachmentID)+"?group_id="+url.QueryEscape(resources.groupID), resources.accessToken, nil, nil, http.StatusNoContent, http.StatusNotFound)
	}
	if resources.listID != "" {
		_ = c.expectStatuses(ctx, http.MethodDelete, "/api/v1/lists/"+url.PathEscape(resources.listID), resources.accessToken, nil, nil, http.StatusNoContent, http.StatusNotFound)
	}
	if resources.groupID != "" {
		_ = c.expectStatuses(ctx, http.MethodDelete, "/api/v1/groups/"+url.PathEscape(resources.groupID), resources.accessToken, nil, nil, http.StatusNoContent, http.StatusNotFound)
	}
	_ = c.expectStatuses(ctx, http.MethodDelete, "/api/v1/auth/me", resources.accessToken, nil, nil, http.StatusNoContent, http.StatusUnauthorized)
}

func (c *client) upload(ctx context.Context, uploadURL string, payload []byte) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, uploadURL, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "text/plain")
	req.ContentLength = int64(len(payload))
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return responseError(resp)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	return nil
}

func (c *client) expect(ctx context.Context, method, path, bearer string, body any, status int, out any) error {
	return c.expectStatuses(ctx, method, path, bearer, body, out, status)
}

func (c *client) expectStatuses(ctx context.Context, method, path, bearer string, body, out any, expected ...int) error {
	if len(expected) == 0 {
		return errors.New("expected status is required")
	}
	statuses := make(map[int]bool)
	for _, status := range expected {
		statuses[status] = true
	}
	var payload io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return err
		}
		payload = bytes.NewReader(encoded)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, payload)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if !statuses[resp.StatusCode] {
		return responseError(resp)
	}
	if out == nil || resp.StatusCode == http.StatusNoContent {
		_, _ = io.Copy(io.Discard, resp.Body)
		return nil
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(out); err != nil {
		return fmt.Errorf("decode %s %s response: %w", method, path, err)
	}
	return nil
}

func responseError(resp *http.Response) error {
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	message := strings.TrimSpace(string(body))
	if message == "" {
		message = http.StatusText(resp.StatusCode)
	}
	return fmt.Errorf("%s %s returned %d: %s", resp.Request.Method, resp.Request.URL.Redacted(), resp.StatusCode, message)
}

func (c *client) pass(step string) { fmt.Fprintf(c.out, "ok  %s\n", step) }

func normalizeBaseURL(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", errors.New("base URL is required (use -base-url or MITLIST_SMOKE_BASE_URL)")
	}
	parsed, err := url.Parse(raw)
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return "", errors.New("base URL must be an absolute http(s) URL")
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return "", errors.New("base URL scheme must be http or https")
	}
	if parsed.RawQuery != "" || parsed.Fragment != "" {
		return "", errors.New("base URL must not contain a query or fragment")
	}
	if parsed.Path != "" && parsed.Path != "/" {
		return "", errors.New("base URL must be an origin without a path")
	}
	return strings.TrimRight(raw, "/"), nil
}

func validateEmailDomain(domain string) error {
	if strings.TrimSpace(domain) != domain || domain == "" || strings.ContainsAny(domain, "@/ :") {
		return errors.New("email domain is invalid")
	}
	return nil
}

func requireTokens(pair tokenPair) error {
	if pair.AccessToken == "" || pair.RefreshToken == "" {
		return errors.New("response has incomplete token pair")
	}
	return nil
}

func randomHex(bytesCount int) (string, error) {
	b := make([]byte, bytesCount)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
