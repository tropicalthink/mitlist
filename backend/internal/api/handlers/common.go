package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/middleware"
	"github.com/yourorg/mitlist/internal/models"
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
		respondError(w, api.ErrUnauthorized)
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
// Response helpers
// ---------------------------------------------------------------------------

func respondJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func respondError(w http.ResponseWriter, err error) {
	status, body := mapError(err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

type errorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
	Field   string `json:"field,omitempty"`
}

func mapError(err error) (int, errorResponse) {
	var notFound *api.NotFoundError
	if errors.As(err, &notFound) {
		return http.StatusNotFound, errorResponse{Error: "not_found", Message: notFound.Error()}
	}

	var perm *api.PermissionDeniedError
	if errors.As(err, &perm) {
		return http.StatusForbidden, errorResponse{Error: "permission_denied", Message: perm.Error()}
	}

	var val *api.ValidationError
	if errors.As(err, &val) {
		return http.StatusBadRequest, errorResponse{Error: "validation_error", Message: val.Error(), Field: val.Field}
	}

	var conflict *api.ConflictError
	if errors.As(err, &conflict) {
		return http.StatusConflict, errorResponse{Error: "conflict", Message: conflict.Error()}
	}

	if errors.Is(err, api.ErrUnauthorized) {
		return http.StatusUnauthorized, errorResponse{Error: "unauthorized", Message: "unauthorized"}
	}

	return http.StatusInternalServerError, errorResponse{Error: "internal_error", Message: "internal server error"}
}
