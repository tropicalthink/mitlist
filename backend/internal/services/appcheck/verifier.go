// Package appcheck verifies Firebase App Check JWTs for requests that create
// unauthenticated guest accounts.
package appcheck

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
)

const (
	defaultJWKSURL = "https://firebaseappcheck.googleapis.com/v1/jwks"
	maxJWKSBytes   = 1 << 20
	maxCacheAge    = 6 * time.Hour // Firebase says never cache these keys longer.
	requestTimeout = 5 * time.Second
)

var (
	ErrDisabled = errors.New("firebase app check is disabled")
	ErrMissing  = errors.New("firebase app check token is missing")
	ErrInvalid  = errors.New("firebase app check token is invalid")
)

// Claims contains the verified common App Check claims. AppID is copied from
// sub, matching Firebase Admin SDK semantics.
type Claims struct {
	jwt.RegisteredClaims
	AppID string `json:"-"`
}

// QuotaIdentity binds a well-formed client installation UUID to a verified app
// identity. The UUID is not proof by itself and invalid values are discarded.
// IP quotas are enforced separately so network changes cannot reset this key.
func (c *Claims) QuotaIdentity(installationID string) string {
	if c == nil || c.AppID == "" {
		return ""
	}
	parsed, err := uuid.Parse(strings.TrimSpace(installationID))
	if err != nil || parsed == uuid.Nil {
		return ""
	}
	return "app:" + c.AppID + ":installation:" + parsed.String()
}

type jwk struct {
	Kty string `json:"kty"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type jwkSet struct {
	Keys []jwk `json:"keys"`
}

// Verifier validates App Check JWTs and caches Google's rotating JWKS.
type Verifier struct {
	enabled       bool
	projectNumber string
	allowedAppIDs map[string]struct{}
	jwksURL       string
	client        *http.Client
	now           func() time.Time

	mu         sync.Mutex
	keys       map[string]*rsa.PublicKey
	cacheUntil time.Time
}

// New creates a verifier from the existing Firebase configuration. It does
// not make a network request; keys are fetched lazily on the first token.
func New(cfg *config.Config) (*Verifier, error) {
	if cfg == nil {
		return nil, errors.New("firebase app check config is nil")
	}
	enabled := cfg.FirebaseAppCheckRequired
	if enabled && strings.TrimSpace(cfg.FirebaseProjectNumber) == "" {
		return nil, errors.New("FIREBASE_PROJECT_NUMBER is required when Firebase App Check is enabled")
	}
	allowed := make(map[string]struct{})
	for _, id := range strings.Split(cfg.FirebaseAppCheckAllowedAppIDs, ",") {
		if id = strings.TrimSpace(id); id != "" {
			allowed[id] = struct{}{}
		}
	}
	if enabled && len(allowed) == 0 {
		return nil, errors.New("FIREBASE_APP_CHECK_ALLOWED_APP_IDS is required when Firebase App Check is enabled")
	}
	return &Verifier{
		enabled:       enabled,
		projectNumber: strings.TrimSpace(cfg.FirebaseProjectNumber),
		allowedAppIDs: allowed,
		jwksURL:       defaultJWKSURL,
		client:        &http.Client{},
		now:           time.Now,
	}, nil
}

// NewForTesting creates a verifier with an injected JWKS endpoint and client.
// It is intentionally exported so package-level tests can avoid live Google
// network calls while exercising real signature validation.
func NewForTesting(projectNumber, jwksURL string, client *http.Client) *Verifier {
	return &Verifier{
		enabled:       true,
		projectNumber: projectNumber,
		jwksURL:       jwksURL,
		client:        client,
		now:           time.Now,
		allowedAppIDs: make(map[string]struct{}),
	}
}

func (v *Verifier) Enabled() bool { return v != nil && v.enabled }

// Verify validates a Firebase App Check token according to Firebase's custom
// backend protocol: RS256/JWT, Google's issuer, the project audience, expiry,
// and a non-empty subject. It also supports app-ID allowlisting.
func (v *Verifier) Verify(ctx context.Context, raw string) (*Claims, error) {
	if v == nil || !v.enabled {
		return nil, ErrDisabled
	}
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil, ErrMissing
	}
	if v.projectNumber == "" {
		return nil, ErrInvalid
	}

	var parsed *jwt.Token
	var claims Claims
	parse := func(keys map[string]*rsa.PublicKey) error {
		var err error
		claims = Claims{}
		parsed, err = jwt.ParseWithClaims(raw, &claims, func(token *jwt.Token) (any, error) {
			if token.Method != jwt.SigningMethodRS256 || token.Header["alg"] != "RS256" {
				return nil, ErrInvalid
			}
			if typ, ok := token.Header["typ"].(string); !ok || typ != "JWT" {
				return nil, ErrInvalid
			}
			kid, ok := token.Header["kid"].(string)
			if !ok || kid == "" {
				return nil, ErrInvalid
			}
			key := keys[kid]
			if key == nil {
				return nil, ErrInvalid
			}
			return key, nil
		}, jwt.WithValidMethods([]string{"RS256"}), jwt.WithIssuer("https://firebaseappcheck.googleapis.com/"+v.projectNumber), jwt.WithAudience("projects/"+v.projectNumber), jwt.WithIssuedAt(), jwt.WithLeeway(time.Minute))
		if err != nil {
			return err
		}
		if parsed == nil || !parsed.Valid {
			return ErrInvalid
		}
		return nil
	}

	keys, err := v.getKeys(ctx, false)
	if err != nil {
		return nil, ErrInvalid
	}
	if err = parse(keys); err != nil {
		// A kid miss can be caused by Google's key rotation. Refresh once,
		// bypassing the cache; never accept a token without a matching key.
		keys, refreshErr := v.getKeys(ctx, true)
		if refreshErr != nil {
			return nil, ErrInvalid
		}
		if err = parse(keys); err != nil {
			return nil, ErrInvalid
		}
	}

	if claims.Subject == "" || claims.Issuer != "https://firebaseappcheck.googleapis.com/"+v.projectNumber || claims.IssuedAt == nil || claims.ExpiresAt == nil {
		return nil, ErrInvalid
	}
	claims.AppID = claims.Subject
	if len(v.allowedAppIDs) > 0 {
		if _, ok := v.allowedAppIDs[claims.AppID]; !ok {
			return nil, ErrInvalid
		}
	}
	return &claims, nil
}

func (v *Verifier) getKeys(ctx context.Context, force bool) (map[string]*rsa.PublicKey, error) {
	now := v.now()
	v.mu.Lock()
	if !force && len(v.keys) > 0 && now.Before(v.cacheUntil) {
		keys := v.keys
		v.mu.Unlock()
		return keys, nil
	}
	v.mu.Unlock()

	fetchCtx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(fetchCtx, http.MethodGet, v.jwksURL, nil)
	if err != nil {
		return nil, err
	}
	client := v.client
	if client == nil {
		client = http.DefaultClient
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("JWKS endpoint returned %s", resp.Status)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxJWKSBytes+1))
	if err != nil || len(body) > maxJWKSBytes {
		return nil, errors.New("invalid JWKS response body")
	}
	var set jwkSet
	if err := json.Unmarshal(body, &set); err != nil {
		return nil, err
	}
	keys := make(map[string]*rsa.PublicKey, len(set.Keys))
	for _, item := range set.Keys {
		key, err := parseJWK(item)
		if err != nil {
			return nil, err
		}
		keys[item.Kid] = key
	}
	if len(keys) == 0 {
		return nil, errors.New("JWKS response contains no usable keys")
	}
	v.mu.Lock()
	v.keys = keys
	v.cacheUntil = v.now().Add(maxCacheAge)
	v.mu.Unlock()
	return keys, nil
}

func parseJWK(item jwk) (*rsa.PublicKey, error) {
	if item.Kty != "RSA" || item.Alg != "RS256" || (item.Use != "" && item.Use != "sig") || item.Kid == "" || item.N == "" || item.E == "" {
		return nil, errors.New("unsupported App Check JWK")
	}
	decode := func(value string) ([]byte, error) {
		return base64.RawURLEncoding.DecodeString(value)
	}
	nBytes, err := decode(item.N)
	if err != nil || len(nBytes) == 0 {
		return nil, errors.New("invalid App Check JWK modulus")
	}
	eBytes, err := decode(item.E)
	if err != nil || len(eBytes) == 0 {
		return nil, errors.New("invalid App Check JWK exponent")
	}
	e := 0
	for _, b := range eBytes {
		e = e<<8 | int(b)
	}
	if e < 2 {
		return nil, errors.New("invalid App Check JWK exponent")
	}
	return &rsa.PublicKey{N: new(big.Int).SetBytes(nBytes), E: e}, nil
}
