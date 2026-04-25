package middleware

import (
	"net/http"
	"strings"

	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	jwtservice "github.com/yourorg/mitlist/internal/services/jwt"
	"github.com/yourorg/mitlist/internal/services"
)

// Auth validates the access token from either an "access_token" cookie or the
// Authorization header. On success it injects the user ID into the request
// context so downstream handlers can identify the caller.
func Auth(jwt *jwtservice.Service, userSvc *services.UserService) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := extractToken(r)
			if token == "" {
				api.WriteError(w, api.ErrUnauthorized)
				return
			}
			claims, err := jwt.ValidateAccessToken(token)
			if err != nil {
				api.WriteError(w, api.ErrUnauthorized)
				return
			}

			userID, err := uuid.Parse(claims.Subject)
			if err != nil {
				api.WriteError(w, api.ErrUnauthorized)
				return
			}

			user, err := userSvc.GetMe(r.Context(), userID)
			if err != nil {
				api.WriteError(w, api.ErrUnauthorized)
				return
			}

			ctx := WithUserID(r.Context(), claims.Subject)
			ctx = api.WithUser(ctx, user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func extractToken(r *http.Request) string {
	if cookie, err := r.Cookie("access_token"); err == nil && cookie.Value != "" {
		return cookie.Value
	}
	bearer := r.Header.Get("Authorization")
	if strings.HasPrefix(bearer, "Bearer ") {
		return strings.TrimPrefix(bearer, "Bearer ")
	}
	return ""
}
