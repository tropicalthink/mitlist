package api

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"

	"github.com/getsentry/sentry-go"
)

// Common domain errors used across the application.
var (
	ErrNotFound         = errors.New("resource not found")
	ErrPermissionDenied = errors.New("permission denied")
	ErrValidation       = errors.New("validation failed")
	ErrConflict         = errors.New("resource conflict")
	ErrUnauthorized     = errors.New("unauthorized")
)

// NotFoundError indicates a requested resource does not exist.
type NotFoundError struct {
	Resource string
	ID       string
}

func (e *NotFoundError) Error() string {
	if e.Resource != "" && e.ID != "" {
		return fmt.Sprintf("%s %s not found", e.Resource, e.ID)
	}
	if e.Resource != "" {
		return fmt.Sprintf("%s not found", e.Resource)
	}
	return "not found"
}

func (e *NotFoundError) Unwrap() error {
	return ErrNotFound
}

// PermissionDeniedError indicates the user lacks required permissions.
type PermissionDeniedError struct {
	Action  string
	Message string
}

func (e *PermissionDeniedError) Error() string {
	if e.Message != "" {
		return e.Message
	}
	if e.Action != "" {
		return fmt.Sprintf("permission denied: %s", e.Action)
	}
	return "permission denied"
}

func (e *PermissionDeniedError) Unwrap() error {
	return ErrPermissionDenied
}

// ValidationError wraps field-level validation failures.
type ValidationError struct {
	Field   string
	Message string
}

func (e *ValidationError) Error() string {
	if e.Field != "" && e.Message != "" {
		return fmt.Sprintf("validation error on %s: %s", e.Field, e.Message)
	}
	if e.Message != "" {
		return e.Message
	}
	return "validation error"
}

func (e *ValidationError) Unwrap() error {
	return ErrValidation
}

// ConflictError indicates a resource conflict such as a duplicate.
type ConflictError struct {
	Resource string
	Message  string
}

func (e *ConflictError) Error() string {
	if e.Message != "" {
		return e.Message
	}
	if e.Resource != "" {
		return fmt.Sprintf("%s already exists", e.Resource)
	}
	return "conflict"
}

func (e *ConflictError) Unwrap() error {
	return ErrConflict
}

// ErrorResponse is the standard JSON shape returned for errors.
type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message,omitempty"`
	Field   string `json:"field,omitempty"`
}

// CodeForError maps domain errors to stable error codes.
// These codes are intended for clients to branch on.
func CodeForError(err error) string {
	if err == nil {
		return "ok"
	}
	var nf *NotFoundError
	if errors.As(err, &nf) || errors.Is(err, ErrNotFound) {
		return "not_found"
	}
	var pd *PermissionDeniedError
	if errors.As(err, &pd) || errors.Is(err, ErrPermissionDenied) {
		return "permission_denied"
	}
	var ve *ValidationError
	if errors.As(err, &ve) || errors.Is(err, ErrValidation) {
		return "validation_error"
	}
	var ce *ConflictError
	if errors.As(err, &ce) || errors.Is(err, ErrConflict) {
		return "conflict"
	}
	if errors.Is(err, ErrUnauthorized) {
		return "unauthorized"
	}
	return "internal_error"
}

// HTTPStatusForError maps domain errors to HTTP status codes.
func HTTPStatusForError(err error) int {
	if err == nil {
		return http.StatusOK
	}
	var nf *NotFoundError
	if errors.As(err, &nf) || errors.Is(err, ErrNotFound) {
		return http.StatusNotFound
	}
	var pd *PermissionDeniedError
	if errors.As(err, &pd) || errors.Is(err, ErrPermissionDenied) {
		return http.StatusForbidden
	}
	var ve *ValidationError
	if errors.As(err, &ve) || errors.Is(err, ErrValidation) {
		return http.StatusBadRequest
	}
	var ce *ConflictError
	if errors.As(err, &ce) || errors.Is(err, ErrConflict) {
		return http.StatusConflict
	}
	if errors.Is(err, ErrUnauthorized) {
		return http.StatusUnauthorized
	}
	return http.StatusInternalServerError
}

// WriteError writes a JSON error response with the appropriate HTTP status.
func WriteError(w http.ResponseWriter, err error) {
	status := HTTPStatusForError(err)
	// Internal errors are otherwise swallowed here (message replaced with a
	// generic string, never logged), so report them to Sentry/GlitchTip. This
	// is the single funnel for the ~600 handler error-response call sites.
	if status >= http.StatusInternalServerError && err != nil {
		captureServerError(err)
	}
	resp := ErrorResponse{Error: CodeForError(err)}
	var ve *ValidationError
	if errors.As(err, &ve) {
		resp.Message = ve.Error()
		resp.Field = ve.Field
	} else if err != nil {
		if status == http.StatusInternalServerError {
			resp.Message = "internal server error"
		} else {
			resp.Message = err.Error()
		}
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(resp)
}

// captureServerError reports an unexpected server-side error to Sentry/GlitchTip,
// grouped by the error value so distinct failures surface as distinct issues.
// It is a no-op when Sentry is not configured. The attached stacktrace points at
// the handler that returned the error.
func captureServerError(err error) {
	hub := sentry.CurrentHub()
	if hub.Client() == nil {
		return
	}
	hub.CaptureException(err)
}
