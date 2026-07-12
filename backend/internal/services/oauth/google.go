package oauth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"

	"github.com/mitlist-app/mitlist/internal/config"
)

// GoogleUser represents the userinfo response from Google.
type GoogleUser struct {
	ID            string `json:"id"`
	Email         string `json:"email"`
	Name          string `json:"name"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Picture       string `json:"picture"`
	VerifiedEmail bool   `json:"verified_email"`
}

// GoogleClient wraps Google's OAuth2 endpoints.
type GoogleClient struct {
	config    *oauth2.Config
	allowlist []string
}

// NewGoogleClient creates a Google OAuth client from application config.
func NewGoogleClient(cfg *config.Config) *GoogleClient {
	allowlist := parseAllowlist(cfg.OAuthRedirectAllowlist)
	if len(allowlist) == 0 {
		allowlist = defaultClientRedirectAllowlist(cfg.FrontendURL)
	}

	return &GoogleClient{
		config: &oauth2.Config{
			ClientID:     cfg.GoogleClientID,
			ClientSecret: cfg.GoogleClientSecret,
			RedirectURL:  cfg.GoogleRedirectURI,
			Endpoint:     google.Endpoint,
			Scopes:       []string{"openid", "email", "profile"},
		},
		allowlist: allowlist,
	}
}

func defaultClientRedirectAllowlist(frontendURL string) []string {
	allowlist := []string{"mitlist:///auth/callback"}
	if trimmed := strings.TrimRight(frontendURL, "/"); trimmed != "" {
		allowlist = append(allowlist, trimmed+"/auth/callback")
	}
	return allowlist
}

// AllowRedirect reports whether a client-supplied redirect URI is permitted by
// the configured allowlist.
func (c *GoogleClient) AllowRedirect(redirectURI string) bool {
	return isAllowed(redirectURI, c.allowlist)
}

// AuthURL returns the Google authorization URL for the configured provider
// callback (RedirectURI). It does not consult the allowlist: the callback is
// operator-configured, not client-supplied, so it must not be filtered by the
// client redirect allowlist.
func (c *GoogleClient) AuthURL(state string) string {
	return c.config.AuthCodeURL(state, oauth2.AccessTypeOnline)
}

// RedirectURI returns the configured provider callback URI used for server-side exchanges.
func (c *GoogleClient) RedirectURI() string {
	return c.config.RedirectURL
}

// Configured reports whether the operator supplied Google OAuth credentials.
func (c *GoogleClient) Configured() bool {
	return c.config.ClientID != "" && c.config.ClientSecret != ""
}

// ExchangeCode exchanges an authorization code for an OAuth2 token.
func (c *GoogleClient) ExchangeCode(code string) (*oauth2.Token, error) {
	if c.config.ClientID == "" || c.config.ClientSecret == "" {
		return nil, fmt.Errorf("google oauth not fully configured")
	}
	return c.config.Exchange(context.Background(), code)
}

// GetUserInfo fetches the user's profile from Google using the provided token.
func (c *GoogleClient) GetUserInfo(token *oauth2.Token) (*GoogleUser, error) {
	client := c.config.Client(context.Background(), token)
	resp, err := client.Get("https://www.googleapis.com/oauth2/v2/userinfo")
	if err != nil {
		return nil, fmt.Errorf("fetch google userinfo: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("google userinfo returned status %d", resp.StatusCode)
	}

	var user GoogleUser
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, fmt.Errorf("decode google userinfo: %w", err)
	}
	return &user, nil
}

func parseAllowlist(raw string) []string {
	if raw == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if t := strings.TrimSpace(p); t != "" {
			out = append(out, t)
		}
	}
	return out
}

func isAllowed(uri string, allowlist []string) bool {
	if uri == "" {
		return false
	}
	for _, allowed := range allowlist {
		if strings.EqualFold(uri, allowed) {
			return true
		}
	}
	return false
}
