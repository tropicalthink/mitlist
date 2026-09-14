// Package staffroom forwards data mitlist collects on the public site into
// the studio's Staffroom (reqtrack) workspace over its intake API, so the
// team works from one list instead of exporting CSVs from here.
package staffroom

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

const (
	requestTimeout   = 8 * time.Second
	maxResponseBytes = 1 << 12
)

// ErrDisabled is returned when no intake URL or key is configured.
var ErrDisabled = errors.New("staffroom intake is not configured")

// Client posts to the Staffroom intake API on behalf of one app.
type Client struct {
	baseURL string
	key     string
	http    *http.Client
}

// New builds a client that is disabled unless both STAFFROOM_INTAKE_URL and
// STAFFROOM_INTAKE_KEY are set. Absent config is not an error.
func New(cfg *config.Config) *Client {
	if cfg == nil {
		return &Client{}
	}
	return NewWithHTTP(cfg.StaffroomIntakeURL, cfg.StaffroomIntakeKey, nil)
}

// NewWithHTTP builds a client against an explicit endpoint, for tests.
func NewWithHTTP(baseURL, key string, client *http.Client) *Client {
	if client == nil {
		client = &http.Client{Timeout: requestTimeout}
	}
	return &Client{
		baseURL: strings.TrimRight(strings.TrimSpace(baseURL), "/"),
		key:     strings.TrimSpace(key),
		http:    client,
	}
}

// Enabled reports whether forwarding is configured.
func (c *Client) Enabled() bool {
	return c != nil && c.baseURL != "" && c.key != ""
}

// ForwardTester records one testing signup on the app's tester list. The
// intake endpoint is idempotent per email and platform, so re-sending a
// signup that already arrived is harmless and never resets what the team
// did with it.
func (c *Client) ForwardTester(ctx context.Context, signup repositories.TestingSignup) error {
	if !c.Enabled() {
		return ErrDisabled
	}
	payload := map[string]any{
		"email":    signup.Email,
		"platform": signup.Platform,
	}
	if signup.ConsentVersion != "" {
		payload["consentVersion"] = signup.ConsentVersion
	}
	if !signup.CreatedAt.IsZero() {
		payload["signedUpAt"] = signup.CreatedAt.UnixMilli()
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	reqCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, c.baseURL+"/testers", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-App-Key", c.key)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		return nil
	}
	detail, _ := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	return fmt.Errorf("staffroom intake: %s: %s", resp.Status, strings.TrimSpace(string(detail)))
}
