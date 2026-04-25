package oauth

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/oauth2"

	"github.com/yourorg/mitlist/internal/config"
)

// AppleUser represents the claims extracted from an Apple identity token.
type AppleUser struct {
	ID            string `json:"sub"`
	Email         string `json:"email"`
	EmailVerified bool   `json:"email_verified"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
}

var appleEndpoint = oauth2.Endpoint{
	AuthURL:  "https://appleid.apple.com/auth/authorize",
	TokenURL: "https://appleid.apple.com/auth/token",
}

// AppleClient wraps Apple's Sign In with Apple OAuth2 endpoints.
type AppleClient struct {
	clientID    string
	teamID      string
	keyID       string
	privateKey  string
	redirectURI string
	allowlist   []string
	httpClient  *http.Client
	jwkCache    *jwkCache
}

type jwkCache struct {
	keys      map[string]*ecdsa.PublicKey
	fetchedAt time.Time
	mu        sync.RWMutex
}

// NewAppleClient creates an Apple OAuth client from application config.
func NewAppleClient(cfg *config.Config) *AppleClient {
	allowlist := parseAllowlist(cfg.OAuthRedirectAllowlist)
	if len(allowlist) == 0 && cfg.AppleRedirectURI != "" {
		allowlist = []string{cfg.AppleRedirectURI}
	}

	return &AppleClient{
		clientID:    cfg.AppleClientID,
		teamID:      cfg.AppleTeamID,
		keyID:       cfg.AppleKeyID,
		privateKey:  cfg.ApplePrivateKey,
		redirectURI: cfg.AppleRedirectURI,
		allowlist:   allowlist,
		httpClient:  &http.Client{Timeout: 10 * time.Second},
		jwkCache:    &jwkCache{},
	}
}

// GetAuthURL returns an Apple authorization URL. The redirectURI is validated
// against the configured allowlist; if invalid, an empty string is returned.
func (c *AppleClient) GetAuthURL(state, redirectURI string) string {
	if !isAllowed(redirectURI, c.allowlist) {
		return ""
	}
	conf := &oauth2.Config{
		ClientID:    c.clientID,
		Endpoint:    appleEndpoint,
		RedirectURL: redirectURI,
		Scopes:      []string{"name", "email"},
	}
	return conf.AuthCodeURL(state, oauth2.AccessTypeOnline)
}

// ExchangeCode exchanges an authorization code for an OAuth2 token.
func (c *AppleClient) ExchangeCode(code string) (*oauth2.Token, error) {
	if c.clientID == "" || c.teamID == "" || c.keyID == "" || c.privateKey == "" {
		return nil, fmt.Errorf("apple oauth not fully configured")
	}

	clientSecret, err := c.generateClientSecret()
	if err != nil {
		return nil, fmt.Errorf("generate apple client secret: %w", err)
	}

	redirectURI := c.redirectURI
	if redirectURI == "" && len(c.allowlist) > 0 {
		redirectURI = c.allowlist[0]
	}

	conf := &oauth2.Config{
		ClientID:     c.clientID,
		ClientSecret: clientSecret,
		Endpoint:     appleEndpoint,
		RedirectURL:  redirectURI,
	}

	return conf.Exchange(context.Background(), code)
}

// ValidateIdentityToken verifies an Apple ID token (JWT) and returns the user.
func (c *AppleClient) ValidateIdentityToken(idToken string) (*AppleUser, error) {
	unverified, _, err := new(jwt.Parser).ParseUnverified(idToken, jwt.MapClaims{})
	if err != nil {
		return nil, fmt.Errorf("parse apple id token: %w", err)
	}

	kid, ok := unverified.Header["kid"].(string)
	if !ok {
		return nil, errors.New("missing kid in apple id token header")
	}

	pubKey, err := c.getPublicKey(kid)
	if err != nil {
		return nil, fmt.Errorf("fetch apple public key: %w", err)
	}

	parsed, err := jwt.Parse(idToken, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodECDSA); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return pubKey, nil
	})
	if err != nil {
		return nil, fmt.Errorf("verify apple id token: %w", err)
	}

	claims, ok := parsed.Claims.(jwt.MapClaims)
	if !ok {
		return nil, errors.New("invalid apple id token claims")
	}

	iss, _ := claims["iss"].(string)
	if iss != "https://appleid.apple.com" {
		return nil, errors.New("invalid apple id token issuer")
	}

	aud, _ := claims["aud"].(string)
	if aud != c.clientID {
		return nil, errors.New("invalid apple id token audience")
	}

	user := &AppleUser{
		ID:    stringClaim(claims, "sub"),
		Email: stringClaim(claims, "email"),
	}

	if ev, ok := claims["email_verified"].(bool); ok {
		user.EmailVerified = ev
	} else if evStr, ok := claims["email_verified"].(string); ok {
		user.EmailVerified = evStr == "true"
	}

	return user, nil
}

func (c *AppleClient) generateClientSecret() (string, error) {
	now := time.Now()
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": c.teamID,
		"iat": now.Unix(),
		"exp": now.Add(24 * time.Hour).Unix(),
		"aud": "https://appleid.apple.com",
		"sub": c.clientID,
	})
	tok.Header["kid"] = c.keyID

	privateKey, err := jwt.ParseECPrivateKeyFromPEM([]byte(c.privateKey))
	if err != nil {
		return "", fmt.Errorf("parse apple private key: %w", err)
	}

	return tok.SignedString(privateKey)
}

func (c *AppleClient) getPublicKey(kid string) (*ecdsa.PublicKey, error) {
	c.jwkCache.mu.RLock()
	if key, ok := c.jwkCache.keys[kid]; ok && time.Since(c.jwkCache.fetchedAt) < time.Hour {
		c.jwkCache.mu.RUnlock()
		return key, nil
	}
	c.jwkCache.mu.RUnlock()

	resp, err := c.httpClient.Get("https://appleid.apple.com/auth/keys")
	if err != nil {
		return nil, fmt.Errorf("fetch apple jwks: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("apple jwks returned status %d", resp.StatusCode)
	}

	var jwks struct {
		Keys []map[string]interface{} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("decode apple jwks: %w", err)
	}

	keys := make(map[string]*ecdsa.PublicKey, len(jwks.Keys))
	for _, jwk := range jwks.Keys {
		key, err := jwkToECPublicKey(jwk)
		if err != nil {
			continue
		}
		if k, ok := jwk["kid"].(string); ok {
			keys[k] = key
		}
	}

	c.jwkCache.mu.Lock()
	defer c.jwkCache.mu.Unlock()

	if key, ok := c.jwkCache.keys[kid]; ok && time.Since(c.jwkCache.fetchedAt) < time.Hour {
		return key, nil
	}

	c.jwkCache.keys = keys
	c.jwkCache.fetchedAt = time.Now()

	if key, ok := keys[kid]; ok {
		return key, nil
	}
	return nil, fmt.Errorf("apple public key %q not found", kid)
}

func jwkToECPublicKey(jwk map[string]interface{}) (*ecdsa.PublicKey, error) {
	kty, _ := jwk["kty"].(string)
	if kty != "EC" {
		return nil, errors.New("not an EC key")
	}

	crv, _ := jwk["crv"].(string)
	var curve elliptic.Curve
	switch crv {
	case "P-256":
		curve = elliptic.P256()
	case "P-384":
		curve = elliptic.P384()
	case "P-521":
		curve = elliptic.P521()
	default:
		return nil, fmt.Errorf("unsupported curve: %s", crv)
	}

	xStr, ok := jwk["x"].(string)
	if !ok {
		return nil, errors.New("missing x coordinate")
	}
	yStr, ok := jwk["y"].(string)
	if !ok {
		return nil, errors.New("missing y coordinate")
	}

	xBytes, err := base64.RawURLEncoding.DecodeString(xStr)
	if err != nil {
		return nil, err
	}
	yBytes, err := base64.RawURLEncoding.DecodeString(yStr)
	if err != nil {
		return nil, err
	}

	x := new(big.Int).SetBytes(xBytes)
	y := new(big.Int).SetBytes(yBytes)

	return &ecdsa.PublicKey{Curve: curve, X: x, Y: y}, nil
}

func stringClaim(claims jwt.MapClaims, key string) string {
	if v, ok := claims[key].(string); ok {
		return v
	}
	return ""
}
