package oauth

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"io"
	"math/big"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Apple signs identity tokens with RS256 and publishes RSA keys in its JWKS.
// This exercises the full validation path against a stubbed JWKS endpoint;
// the client used to accept only EC keys, which made every real Apple login
// fail with "apple public key not found".

type stubTransport struct{ body string }

func (s stubTransport) RoundTrip(*http.Request) (*http.Response, error) {
	return &http.Response{
		StatusCode: http.StatusOK,
		Body:       io.NopCloser(strings.NewReader(s.body)),
		Header:     http.Header{},
	}, nil
}

func TestValidateIdentityToken_RS256(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}

	jwks, err := json.Marshal(map[string]interface{}{
		"keys": []map[string]string{{
			"kty": "RSA",
			"kid": "test-kid",
			"alg": "RS256",
			"n":   base64.RawURLEncoding.EncodeToString(key.N.Bytes()),
			"e":   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes()),
		}},
	})
	if err != nil {
		t.Fatal(err)
	}

	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss":            "https://appleid.apple.com",
		"aud":            "com.example.app",
		"sub":            "001234.abcdef",
		"email":          "user@example.com",
		"email_verified": "true",
		"exp":            time.Now().Add(time.Hour).Unix(),
	})
	tok.Header["kid"] = "test-kid"
	signed, err := tok.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}

	c := &AppleClient{
		clientID:   "com.example.app",
		httpClient: &http.Client{Transport: stubTransport{body: string(jwks)}},
		jwkCache:   &jwkCache{},
	}

	user, err := c.ValidateIdentityToken(signed)
	if err != nil {
		t.Fatalf("ValidateIdentityToken: %v", err)
	}
	if user.ID != "001234.abcdef" {
		t.Errorf("sub = %q, want %q", user.ID, "001234.abcdef")
	}
	if user.Email != "user@example.com" {
		t.Errorf("email = %q, want %q", user.Email, "user@example.com")
	}
	if !user.EmailVerified {
		t.Error("email_verified not carried through")
	}
}

func TestValidateIdentityToken_RS256_WrongAudience(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}

	jwks, err := json.Marshal(map[string]interface{}{
		"keys": []map[string]string{{
			"kty": "RSA",
			"kid": "test-kid",
			"alg": "RS256",
			"n":   base64.RawURLEncoding.EncodeToString(key.N.Bytes()),
			"e":   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.E)).Bytes()),
		}},
	})
	if err != nil {
		t.Fatal(err)
	}

	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": "https://appleid.apple.com",
		"aud": "com.other.app",
		"sub": "001234.abcdef",
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	tok.Header["kid"] = "test-kid"
	signed, err := tok.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}

	c := &AppleClient{
		clientID:   "com.example.app",
		httpClient: &http.Client{Transport: stubTransport{body: string(jwks)}},
		jwkCache:   &jwkCache{},
	}

	if _, err := c.ValidateIdentityToken(signed); err == nil {
		t.Fatal("expected audience mismatch error, got nil")
	}
}
