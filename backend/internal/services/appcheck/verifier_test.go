package appcheck

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func TestVerifierVerifiesFirebaseAppCheckTokenWithoutLiveNetwork(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	const kid = "test-kid"
	serveCount := 0
	client := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		serveCount++
		body, _ := json.Marshal(jwkSet{Keys: []jwk{{
			Kty: "RSA", Use: "sig", Alg: "RS256", Kid: kid,
			N: base64.RawURLEncoding.EncodeToString(key.PublicKey.N.Bytes()),
			E: base64.RawURLEncoding.EncodeToString([]byte{1, 0, 1}),
		}}})
		return &http.Response{StatusCode: http.StatusOK, Status: "200 OK", Body: io.NopCloser(strings.NewReader(string(body))), Header: make(http.Header)}, nil
	})}

	v := NewForTesting("1234567890", "https://jwks.test", client)
	token := signedToken(t, key, kid, "1:1234567890:android:abc")
	claims, err := v.Verify(t.Context(), token)
	if err != nil {
		t.Fatalf("Verify() error = %v", err)
	}
	if claims.AppID != "1:1234567890:android:abc" || claims.QuotaIdentity("123e4567-e89b-12d3-a456-426614174000") != "app:1:1234567890:android:abc:installation:123e4567-e89b-12d3-a456-426614174000" {
		t.Fatalf("unexpected claims: %+v", claims)
	}
	if identity := claims.QuotaIdentity("not-a-uuid"); identity != "" {
		t.Fatalf("invalid installation ID produced identity %q", identity)
	}
	if serveCount != 1 {
		t.Fatalf("JWKS requests = %d, want 1", serveCount)
	}
	// The cached keys are reused, proving verification does not call Google
	// (or the test server) for every guest request.
	if _, err := v.Verify(t.Context(), token); err != nil {
		t.Fatalf("cached Verify() error = %v", err)
	}
	if serveCount != 1 {
		t.Fatalf("cached JWKS requests = %d, want 1", serveCount)
	}
}

func TestVerifierRejectsWrongProjectAndExpiredTokens(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := json.Marshal(jwkSet{Keys: []jwk{{
		Kty: "RSA", Use: "sig", Alg: "RS256", Kid: "kid",
		N: base64.RawURLEncoding.EncodeToString(key.PublicKey.N.Bytes()),
		E: base64.RawURLEncoding.EncodeToString([]byte{1, 0, 1}),
	}}})
	client := &http.Client{Transport: roundTripFunc(func(r *http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: http.StatusOK, Status: "200 OK", Body: io.NopCloser(strings.NewReader(string(body))), Header: make(http.Header)}, nil
	})}
	v := NewForTesting("1234567890", "https://jwks.test", client)

	wrongAudience := signedTokenWithAudience(t, key, "kid", "1:123", jwt.ClaimStrings{"projects/other"}, time.Now().Add(time.Hour))
	if _, err := v.Verify(t.Context(), wrongAudience); err == nil {
		t.Fatal("wrong audience was accepted")
	}
	expired := signedTokenWithAudience(t, key, "kid", "1:123", jwt.ClaimStrings{"projects/1234567890"}, time.Now().Add(-time.Minute))
	if _, err := v.Verify(t.Context(), expired); err == nil {
		t.Fatal("expired token was accepted")
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(r *http.Request) (*http.Response, error) {
	return f(r)
}

func signedToken(t *testing.T, key *rsa.PrivateKey, kid, appID string) string {
	t.Helper()
	return signedTokenWithAudience(t, key, kid, appID, jwt.ClaimStrings{"projects/1234567890"}, time.Now().Add(time.Hour))
}

func signedTokenWithAudience(t *testing.T, key *rsa.PrivateKey, kid, appID string, audience jwt.ClaimStrings, expires time.Time) string {
	t.Helper()
	claims := Claims{RegisteredClaims: jwt.RegisteredClaims{
		Issuer:    "https://firebaseappcheck.googleapis.com/1234567890",
		Subject:   appID,
		Audience:  audience,
		IssuedAt:  jwt.NewNumericDate(time.Now().Add(-time.Minute)),
		ExpiresAt: jwt.NewNumericDate(expires),
	}}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = kid
	signed, err := token.SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	return signed
}
