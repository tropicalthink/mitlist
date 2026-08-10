// Package validation provides common input validation helpers for mitlist.
package validation

import (
	"net/mail"
	"strings"
	"unicode/utf8"
)

// Limits for common string fields.
const (
	MaxEmailLength       = 254
	MaxPasswordLength    = 72
	MaxNameLength        = 100
	MaxTitleLength       = 200
	MaxDescriptionLength = 2000
	MaxContentLength     = 10000
	MaxListNameLength    = 100
	MaxItemNameLength    = 200
	MaxGroupNameLength   = 100
	MinPasswordLength    = 12
)

// NewFieldError creates a validation error for a specific field.
func NewFieldError(field, message string) error {
	return fieldError{field: field, message: message}
}

type fieldError struct {
	field   string
	message string
}

func (e fieldError) Error() string {
	return e.message
}

// Email validates that s is a non-empty, reasonably-well-formed email address.
func Email(s string) error {
	if strings.TrimSpace(s) == "" {
		return NewFieldError("email", "email is required")
	}
	if utf8.RuneCountInString(s) > MaxEmailLength {
		return NewFieldError("email", "email too long")
	}
	addr, err := mail.ParseAddress(s)
	if err != nil || addr.Address != strings.TrimSpace(s) {
		return NewFieldError("email", "invalid email format")
	}
	return nil
}

// NormalizeEmail returns the canonical identity used for storage, lookup, and
// throttling. Domain and local-part casing are treated case-insensitively by
// mitlist to avoid duplicate and rate-limit-bypass identities.
func NormalizeEmail(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}

// Password validates password length constraints.
func Password(s string) error {
	if len(s) < MinPasswordLength {
		return NewFieldError("password", "password must be at least 12 characters")
	}
	if len(s) > MaxPasswordLength {
		return NewFieldError("password", "password too long")
	}
	return nil
}

// RequiredString validates that s is non-empty after trimming.
func RequiredString(s, field string) error {
	if strings.TrimSpace(s) == "" {
		return NewFieldError(field, field+" is required")
	}
	return nil
}

// MaxLength validates that s does not exceed max runes.
func MaxLength(s string, max int, field string) error {
	if utf8.RuneCountInString(s) > max {
		return NewFieldError(field, field+" too long")
	}
	return nil
}

// Name validates a personal or display name.
func Name(s, field string) error {
	if err := RequiredString(s, field); err != nil {
		return err
	}
	return MaxLength(s, MaxNameLength, field)
}
