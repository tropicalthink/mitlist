package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	jwt "github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/config"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
)

func TestExtractToken(t *testing.T) {
	tests := []struct {
		name   string
		cookie string // empty means no cookie added
		setNil bool   // when true, add a cookie with an empty value
		header string // empty means no header set
		want   string
	}{
		{name: "cookie only", cookie: "abc", want: "abc"},
		{name: "cookie takes precedence over header", cookie: "abc", header: "Bearer xyz", want: "abc"},
		{name: "empty cookie falls back to header", setNil: true, header: "Bearer xyz", want: "xyz"},
		{name: "header only", header: "Bearer xyz", want: "xyz"},
		{name: "wrong scheme", header: "Basic xyz", want: ""},
		{name: "no cookie no header", want: ""},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			if tc.cookie != "" {
				req.AddCookie(&http.Cookie{Name: "access_token", Value: tc.cookie})
			}
			if tc.setNil {
				req.AddCookie(&http.Cookie{Name: "access_token", Value: ""})
			}
			if tc.header != "" {
				req.Header.Set("Authorization", tc.header)
			}

			got := ExtractToken(req)
			if got != tc.want {
				t.Fatalf("ExtractToken() = %q, want %q", got, tc.want)
			}
		})
	}
}

// makeToken crafts a signed JWT directly so we can exercise the parse/reject
// branches of ValidateAccessToken without any Redis dependency.
func makeToken(t *testing.T, secret string, typ string, sub string, exp time.Time) string {
	t.Helper()
	claims := jwt.MapClaims{
		"typ": typ,
		"sub": sub,
		"jti": uuid.NewString(),
		"iat": time.Now().Add(-time.Minute).Unix(),
		"nbf": time.Now().Add(-time.Minute).Unix(),
		"exp": exp.Unix(),
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(secret))
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	return signed
}

func TestAuth_RejectsInvalidTokens(t *testing.T) {
	const secret = "test-secret-key-min-32-chars-long!!!"
	cfg := &config.Config{SecretKey: secret, AccessTokenExpireMinutes: 60}
	jwtSvc := jwtservice.New(cfg, nil) // nil redis is safe for these reject-before-Redis paths

	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	handler := Auth(jwtSvc, nil)(next) // nil userSvc is safe: these paths return before GetMe

	future := time.Now().Add(time.Hour)
	past := time.Now().Add(-time.Hour)

	tests := []struct {
		name  string
		setup func(req *http.Request)
	}{
		{
			name:  "no token",
			setup: func(req *http.Request) {},
		},
		{
			name: "malformed token",
			setup: func(req *http.Request) {
				req.Header.Set("Authorization", "Bearer not-a-jwt")
			},
		},
		{
			name: "wrong signing secret",
			setup: func(req *http.Request) {
				tok := makeToken(t, "a-totally-different-secret-key-32x!!", jwtservice.TokenTypeAccess, uuid.NewString(), future)
				req.Header.Set("Authorization", "Bearer "+tok)
			},
		},
		{
			name: "expired access token",
			setup: func(req *http.Request) {
				tok := makeToken(t, secret, jwtservice.TokenTypeAccess, uuid.NewString(), past)
				req.Header.Set("Authorization", "Bearer "+tok)
			},
		},
		{
			name: "refresh-type token",
			setup: func(req *http.Request) {
				tok := makeToken(t, secret, jwtservice.TokenTypeRefresh, uuid.NewString(), future)
				req.Header.Set("Authorization", "Bearer "+tok)
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			tc.setup(req)
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != http.StatusUnauthorized {
				t.Fatalf("status = %d, want %d", rr.Code, http.StatusUnauthorized)
			}
		})
	}
}
