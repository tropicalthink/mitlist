package oauth

import (
	"net/url"
	"strings"
	"testing"

	"github.com/mitlist-app/mitlist/internal/config"
)

// TestAppleAuthURL_FormPostAndProviderCallback verifies that the Apple auth URL
// requests response_mode=form_post (required by Apple when name/email scopes are
// requested) and uses the operator-configured provider callback.
func TestAppleAuthURL_FormPostAndProviderCallback(t *testing.T) {
	cfg := &config.Config{
		AppleClientID:          "me.mitlist.service",
		AppleTeamID:            "TEAM",
		AppleKeyID:             "KEY",
		ApplePrivateKey:        "pem",
		AppleRedirectURI:       "https://api.mitlist.me/api/v1/oauth/apple/callback",
		OAuthRedirectAllowlist: "https://app.mitlist.me/auth/callback",
		FrontendURL:            "https://app.mitlist.me",
	}
	raw := NewAppleClient(cfg).AuthURL("state123")

	if !strings.HasPrefix(raw, "https://appleid.apple.com/auth/authorize") {
		t.Fatalf("unexpected authorize base: %s", raw)
	}
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse auth url: %v", err)
	}
	q := u.Query()
	if got := q.Get("response_mode"); got != "form_post" {
		t.Errorf("response_mode = %q, want form_post", got)
	}
	if got := q.Get("redirect_uri"); got != cfg.AppleRedirectURI {
		t.Errorf("redirect_uri = %q, want %q", got, cfg.AppleRedirectURI)
	}
	if got := q.Get("state"); got != "state123" {
		t.Errorf("state = %q, want state123", got)
	}
}

// TestAllowRedirect_SeparateFromAuthURL is a regression test for the allowlist
// self-validation bug: AuthURL (which uses the app's own provider callback) must
// build successfully even though that provider callback is intentionally NOT in
// the client redirect allowlist. AllowRedirect governs only client-supplied URIs.
func TestAllowRedirect_SeparateFromAuthURL(t *testing.T) {
	cfg := &config.Config{
		GoogleClientID:         "id",
		GoogleClientSecret:     "secret",
		GoogleRedirectURI:      "https://api.mitlist.me/api/v1/oauth/google/callback",
		OAuthRedirectAllowlist: "https://app.mitlist.me/auth/callback",
		FrontendURL:            "https://app.mitlist.me",
	}
	c := NewGoogleClient(cfg)

	if !c.AllowRedirect("https://app.mitlist.me/auth/callback") {
		t.Error("expected the configured client redirect to be allowed")
	}
	if c.AllowRedirect("https://evil.example/callback") {
		t.Error("expected an unlisted client redirect to be rejected")
	}
	// The provider callback is deliberately absent from the client allowlist.
	if c.AllowRedirect(cfg.GoogleRedirectURI) {
		t.Error("provider callback must not need to be in the client allowlist")
	}
	// ...yet AuthURL must still build using it (previously returned "").
	u, err := url.Parse(c.AuthURL("s"))
	if err != nil {
		t.Fatalf("parse auth url: %v", err)
	}
	if got := u.Query().Get("redirect_uri"); got != cfg.GoogleRedirectURI {
		t.Errorf("redirect_uri = %q, want %q", got, cfg.GoogleRedirectURI)
	}
}
