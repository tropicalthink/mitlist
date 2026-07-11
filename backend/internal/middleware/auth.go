package middleware

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/getsentry/sentry-go"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	"github.com/mitlist-app/mitlist/pkg/logger"
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

			// Attribute Sentry events (panics, captured errors) for this request
			// to the authenticated user. This middleware runs inside sentryhttp,
			// so the request hub is present on the context.
			if hub := sentry.GetHubFromContext(ctx); hub != nil {
				hub.Scope().SetUser(sentry.User{ID: claims.Subject})
			}
			// Carry user_id on the request logger so downstream error logs — and
			// thus the Sentry bridge — can attribute issues to the user.
			ctx = logger.ToContext(ctx, logger.FromContext(ctx).WithField("user_id", claims.Subject))

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
