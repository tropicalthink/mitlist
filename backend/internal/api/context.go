package api

import (
	"context"

	"github.com/yourorg/mitlist/internal/models"
)

type ctxKey int

const userCtxKey ctxKey = iota

// WithUser injects a user into the context.
func WithUser(ctx context.Context, user *models.User) context.Context {
	return context.WithValue(ctx, userCtxKey, user)
}

// UserFromContext retrieves the user from the context.
func UserFromContext(ctx context.Context) (*models.User, bool) {
	user, ok := ctx.Value(userCtxKey).(*models.User)
	return user, ok
}
