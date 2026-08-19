package middleware

import (
	"context"
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

type integrationCredentialContextKey struct{}

// IntegrationCredentialFromContext returns the integration authorization
// identity, if this request was authenticated with a scoped bearer token.
func IntegrationCredentialFromContext(ctx context.Context) (*services.CredentialIdentity, bool) {
	identity, ok := ctx.Value(integrationCredentialContextKey{}).(*services.CredentialIdentity)
	return identity, ok
}

func WithIntegrationCredential(ctx context.Context, identity *services.CredentialIdentity) context.Context {
	return context.WithValue(ctx, integrationCredentialContextKey{}, identity)
}

// HasScope reports whether the current integration credential grants scope.
// Interactive JWT sessions always have full application permissions.
func HasScope(ctx context.Context, scope string) bool {
	identity, ok := IntegrationCredentialFromContext(ctx)
	if !ok {
		return true
	}
	for _, granted := range identity.Scopes {
		if granted == "write" && strings.HasSuffix(scope, ":read") {
			return true
		}
		if granted == scope || granted == "*" || granted == "read" || granted == "write" {
			if granted == "read" || granted == "write" {
				if strings.HasSuffix(scope, ":"+granted) {
					return true
				}
				if scope == granted {
					return true
				}
			}
			return true
		}
		if strings.HasSuffix(scope, ":read") && granted == strings.TrimSuffix(scope, ":read")+":*" {
			return true
		}
		if strings.HasSuffix(scope, ":write") && granted == strings.TrimSuffix(scope, ":write")+":*" {
			return true
		}
	}
	return false
}

// AllowsGroup reports whether an integration credential is scoped to groupID.
// Interactive JWT sessions are not group-scoped here; feature services still
// perform their normal membership checks.
func AllowsGroup(ctx context.Context, groupID uuid.UUID) bool {
	identity, ok := IntegrationCredentialFromContext(ctx)
	if !ok {
		return true
	}
	for _, allowed := range identity.GroupIDs {
		if allowed == groupID {
			return true
		}
	}
	return false
}

// CredentialAllowsGroup is the explicit-name alias used by handlers that
// need to authorize a group before calling a feature service.
func CredentialAllowsGroup(ctx context.Context, groupID uuid.UUID) bool {
	return AllowsGroup(ctx, groupID)
}

func CredentialHasScope(ctx context.Context, scope string) bool {
	return HasScope(ctx, scope)
}

// IsIntegrationCredential reports whether authentication came from a managed
// integration token rather than a browser/mobile session.
func IsIntegrationCredential(ctx context.Context) bool {
	_, ok := IntegrationCredentialFromContext(ctx)
	return ok
}

// Auth validates the access token from either an "access_token" cookie or the
// Authorization header. On success it injects the user ID into the request
// context so downstream handlers can identify the caller.
func Auth(jwt *jwtservice.Service, userSvc *services.UserService) func(next http.Handler) http.Handler {
	return AuthWithCredentials(jwt, userSvc, nil)
}

// AuthWithCredentials accepts normal JWT sessions and, when credentialSvc is
// configured, scoped integration bearer tokens. The latter can never access
// credential-management endpoints and must have read/write scope matching the
// HTTP method.
func AuthWithCredentials(jwt *jwtservice.Service, userSvc *services.UserService, credentialSvc *services.IntegrationCredentialService) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token := ExtractToken(r)
			if token == "" {
				api.WriteError(w, fmt.Errorf("sign in required: %w", api.ErrUnauthorized))
				return
			}
			if credentialSvc != nil && strings.HasPrefix(token, services.IntegrationTokenPrefix) {
				if strings.Contains(r.URL.Path, "/auth/integration-credentials") {
					api.WriteError(w, fmt.Errorf("integration credentials require an interactive session: %w", api.ErrPermissionDenied))
					return
				}
				identity, credentialErr := credentialSvc.Authenticate(r.Context(), token, ExtractIP(r), r.UserAgent())
				if credentialErr != nil {
					api.WriteError(w, fmt.Errorf("invalid integration credential: %w", api.ErrUnauthorized))
					return
				}
				requiredScope := services.IntegrationScopeRead
				if r.Method != http.MethodGet && r.Method != http.MethodHead && r.Method != http.MethodOptions {
					requiredScope = services.IntegrationScopeWrite
				}
				domain := integrationDomain(r.URL.Path)
				if !hasCredentialScope(identity, domain, requiredScope) {
					api.WriteError(w, fmt.Errorf("integration credential lacks %s scope: %w", credentialScopeName(domain, requiredScope), api.ErrPermissionDenied))
					return
				}
				groupID, hasGroup := integrationGroupID(r)
				if requiresIntegrationGroup(domain) && !hasGroup {
					api.WriteError(w, fmt.Errorf("integration requests must include group_id or X-Mitlist-Group-ID: %w", api.ErrPermissionDenied))
					return
				}
				if hasGroup && !identityAllowsGroup(identity, groupID) {
					api.WriteError(w, fmt.Errorf("integration credential is not scoped to this group: %w", api.ErrPermissionDenied))
					return
				}
				userID := identity.UserID
				user, userErr := userSvc.GetMe(r.Context(), userID)
				if userErr != nil {
					api.WriteError(w, fmt.Errorf("%s: %w", userErr.Error(), api.ErrUnauthorized))
					return
				}
				ctx := WithIntegrationCredential(r.Context(), identity)
				ctx = WithUserID(ctx, userID.String())
				ctx = api.WithUser(ctx, user)
				next.ServeHTTP(w, r.WithContext(ctx))
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

func hasCredentialScope(identity *services.CredentialIdentity, domain, required string) bool {
	for _, scope := range identity.Scopes {
		if scope == required || (scope == "write" && required == "read") || scope == "*" || (domain != "" && scope == domain+":"+required) || (domain != "" && scope == domain+":*") || (domain != "" && scope == domain+":write" && required == "read") {
			return true
		}
	}
	return false
}

func identityAllowsGroup(identity *services.CredentialIdentity, groupID uuid.UUID) bool {
	for _, allowed := range identity.GroupIDs {
		if allowed == groupID {
			return true
		}
	}
	return false
}

func credentialScopeName(domain, action string) string {
	if domain == "" {
		return action
	}
	return domain + ":" + action
}

func integrationDomain(path string) string {
	path = strings.TrimPrefix(path, "/")
	parts := strings.Split(path, "/")
	for _, part := range parts {
		switch part {
		case "lists", "chores", "calendar", "recipes", "expenses", "finance", "pinwall", "notifications", "grocery", "groceries", "activity", "attachments", "groups":
			if part == "expenses" {
				return "finance"
			}
			if part == "grocery" {
				return "groceries"
			}
			return part
		case "shopping", "shopping-locations", "products", "templates":
			return "lists"
		case "chore-templates":
			return "chores"
		case "meal-plans", "collections":
			return "recipes"
		case "recurring-expenses", "fx":
			return "finance"
		case "events":
			return "groups"
		}
	}
	return ""
}

func integrationGroupID(r *http.Request) (uuid.UUID, bool) {
	if raw := r.Header.Get("X-Mitlist-Group-ID"); raw != "" {
		id, err := uuid.Parse(raw)
		return id, err == nil
	}
	if raw := r.URL.Query().Get("group_id"); raw != "" {
		id, err := uuid.Parse(raw)
		return id, err == nil
	}
	// The groups endpoint's first UUID is unambiguously a group id. Other
	// resources use entity IDs, so they must provide group_id explicitly.
	parts := strings.Split(strings.Trim(r.URL.Path, "/"), "/")
	for i, part := range parts {
		if part == "groups" && i+1 < len(parts) {
			id, err := uuid.Parse(parts[i+1])
			return id, err == nil
		}
	}
	return uuid.Nil, false
}

func requiresIntegrationGroup(domain string) bool {
	switch domain {
	case "lists", "chores", "calendar", "recipes", "finance", "pinwall", "groceries", "activity", "attachments":
		return true
	default:
		return false
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
