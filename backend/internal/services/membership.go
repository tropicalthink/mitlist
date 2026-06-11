package services

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
)

// requireGroupMember returns api.ErrPermissionDenied unless userID has role
// "admin" or "member" in groupID.
func requireGroupMember(ctx context.Context, groups GroupMembershipChecker, groupID, userID uuid.UUID) error {
	m, err := groups.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrPermissionDenied
		}
		return err
	}
	if m.Role != "admin" && m.Role != "member" {
		return api.ErrPermissionDenied
	}
	return nil
}

// requireGroupAdmin returns api.ErrPermissionDenied unless userID has role
// "admin" in groupID.
func requireGroupAdmin(ctx context.Context, groups GroupMembershipChecker, groupID, userID uuid.UUID) error {
	m, err := groups.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrPermissionDenied
		}
		return err
	}
	if m.Role != "admin" {
		return api.ErrPermissionDenied
	}
	return nil
}
