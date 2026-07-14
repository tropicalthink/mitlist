package services

import (
	"context"

	"github.com/google/uuid"
)

// CanonicalNameResolver links a grocery-like name to the shared grocery graph.
// Generation flows treat resolution as best-effort and remain usable when it
// is unavailable or a name is not represented in the catalog.
type CanonicalNameResolver func(ctx context.Context, groupID uuid.UUID, name string) (*uuid.UUID, error)
