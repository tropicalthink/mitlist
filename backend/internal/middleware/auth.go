package middleware

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/services"
	jwtservice "github.com/yourorg/mitlist/internal/services/jwt"
)

// Auth validates the access token from either an "access_token" cookie or the
// Authorization header. On success it injects the user ID into the request
// context so downstream handlers can identify the caller.
func Auth(jwt *jwtservice.Service, userSvc *services.UserService) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := ExtractToken(r)
			if token == "" {
				api.WriteError(w, fmt.Errorf("sign in required: %w", api.ErrUnauthorized))
				return
			}
			claims, err := jwt.ValidateAccessToken(token)
			if err != nil {
				msg := "session expired or invalid"
				if errors.Is(err, jwtservice.ErrRevokedToken) {
					msg = "session revoked"
				}
				api.WriteError(w, fmt.Errorf("%s: %w", msg, api.ErrUnauthorized))
				return
			}

			userID, err := uuid.Parse(claims.Subject)
			if err != nil {
				api.WriteError(w, fmt.Errorf("invalid session: %w", api.ErrUnauthorized))
				return
			}

			user, err := userSvc.GetMe(r.Context(), userID)
			if err != nil {
				// Preserve the original message (e.g., "account is not active")
				// while still returning an unauthorized code.
				api.WriteError(w, fmt.Errorf("%s: %w", err.Error(), api.ErrUnauthorized))
				return
			}

			ctx := WithUserID(r.Context(), claims.Subject)
			ctx = api.WithUser(ctx, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func ExtractToken(r *http.Request) string {
	if cookie, err := r.Cookie("access_token"); err == nil && cookie.Value != "" {
		return cookie.Value
	}
	bearer := r.Header.Get("Authorization")
	if strings.HasPrefix(bearer, "Bearer ") {
		return strings.TrimPrefix(bearer, "Bearer ")
	}
	return ""
}
