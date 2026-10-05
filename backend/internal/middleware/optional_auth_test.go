package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
)

// OptionalAuth never turns a request away: without a usable session it goes
// on anonymously, with no user in the context.
func TestOptionalAuth_LetsAnonymousAndBadTokensThrough(t *testing.T) {
	cfg := &config.Config{SecretKey: "test-secret-key-min-32-chars-long!!!", AccessTokenExpireMinutes: 60}
	jwtSvc := jwtservice.New(cfg, nil)

	for name, header := range map[string]string{
		"no token":               "",
		"malformed token":        "Bearer not-a-jwt",
		"integration credential": "Bearer ml_int_abc",
	} {
		t.Run(name, func(t *testing.T) {
			var sawUser bool
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				_, sawUser = api.UserFromContext(r.Context())
				w.WriteHeader(http.StatusAccepted)
			})
			req := httptest.NewRequest(http.MethodPost, "/events", nil)
			if header != "" {
				req.Header.Set("Authorization", header)
			}
			rec := httptest.NewRecorder()
			// nil userSvc is safe: every case returns before the user lookup.
			OptionalAuth(jwtSvc, nil)(next).ServeHTTP(rec, req)

			if rec.Code != http.StatusAccepted {
				t.Fatalf("status = %d, want the request to go through", rec.Code)
			}
			if sawUser {
				t.Fatal("an unauthenticated request must not carry a user")
			}
		})
	}
}
