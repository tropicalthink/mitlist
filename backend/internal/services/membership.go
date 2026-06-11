package services

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
)

// requireGroupMember returns a *api.PermissionDeniedError (which unwraps to
// api.ErrPermissionDenied) unless userID has role "admin" or "member" in
// groupID. Other repository errors are propagated unchanged.
func requireGroupMember(ctx context.Context, groups GroupMembershipChecker, groupID, userID uuid.UUID) error {
	m, err := groups.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{}
		}
		return err
	}
	if m.Role != "admin" && m.Role != "member" {
		return &api.PermissionDeniedError{}
	}
	return nil
}

// requireGroupAdmin returns a *api.PermissionDeniedError (which unwraps to
// api.ErrPermissionDenied) unless userID has role "admin" in groupID.
// Other repository errors are propagated unchanged.
func requireGroupAdmin(ctx context.Context, groups GroupMembershipChecker, groupID, userID uuid.UUID) error {
	m, err := groups.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{}
		}
		return err
	}
	if m.Role != "admin" {
		return &api.PermissionDeniedError{}
	}
	return nil
}
