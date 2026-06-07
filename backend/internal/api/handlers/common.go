package handlers

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
)

// ---------------------------------------------------------------------------
// Context helpers
// ---------------------------------------------------------------------------

type contextKey int

const userContextKey contextKey = iota

// WithUser stores a user in the request context.
func WithUser(r *http.Request, user *models.User) *http.Request {
	return r.WithContext(WithUserContext(r.Context(), user))
}

// WithUserContext stores a user in a context.
func WithUserContext(ctx context.Context, user *models.User) context.Context {
	return context.WithValue(ctx, userContextKey, user)
}

// UserFromContext retrieves the current user from context.
func UserFromContext(ctx context.Context) *models.User {
	u, _ := ctx.Value(userContextKey).(*models.User)
	return u
}

// RequireUser returns the authenticated user ID or responds with 401 if missing.
func RequireUser(w http.ResponseWriter, r *http.Request) uuid.UUID {
	id, err := getUserID(r)
	if err != nil {
		api.RespondError(w, api.ErrUnauthorized)
		return uuid.Nil
	}
	return id
}

// getUserID extracts the user ID from the request context (set by auth middleware).
func getUserID(r *http.Request) (uuid.UUID, error) {
	idStr := middleware.UserIDFromContext(r.Context())
	if idStr == "" {
		return uuid.Nil, api.ErrUnauthorized
	}
	return uuid.Parse(idStr)
}

// ---------------------------------------------------------------------------
// Request helpers
// ---------------------------------------------------------------------------

func decodeJSON(r *http.Request, v any) error {
	defer r.Body.Close()
	dec := json.NewDecoder(io.LimitReader(r.Body, 1<<20))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return &api.ValidationError{Message: "invalid JSON body"}
	}
	return nil
}

func parseUUIDParam(r *http.Request, key string) (uuid.UUID, error) {
	raw := chi.URLParam(r, key)
	id, err := uuid.Parse(raw)
	if err != nil {
		return uuid.Nil, &api.ValidationError{Field: key, Message: "invalid UUID"}
	}
	return id, nil
}

func parsePagination(r *http.Request) (limit, offset int) {
	limitStr := r.URL.Query().Get("limit")
	offsetStr := r.URL.Query().Get("offset")

	limit, _ = strconv.Atoi(limitStr)
	offset, _ = strconv.Atoi(offsetStr)

	if limit <= 0 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}

// parseLimitOffset is an alias for parsePagination kept for callers that expect a distinct name.
func parseLimitOffset(r *http.Request) (limit, offset int) {
	return parsePagination(r)
}

// ---------------------------------------------------------------------------
// Response helpers (delegated to api.WriteError / api.RespondError in api/errors.go)
// ---------------------------------------------------------------------------
