package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestGroupRepository_CreateGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	group := &models.Group{
		Name:        "Home",
		Description: strPtr("Our home"),
		Currency:    "USD",
		CreatedBy:   fixedUUID(),
	}

	mock.ExpectExec("INSERT INTO groups").
		WithArgs(pgxmock.AnyArg(), group.Name, group.Description, group.Currency, group.CreatedBy, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateGroup(context.Background(), group)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, group.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetGroupByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "name", "description", "currency", "created_by", "created_at", "updated_at"}).
		AddRow(id, "Home", nil, "USD", fixedUUID(), fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM groups WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	group, err := repo.GetGroupByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, group.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetGroupByID_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM groups WHERE id = .*").
		WithArgs(id).
		WillReturnError(pgx.ErrNoRows)

	group, err := repo.GetGroupByID(context.Background(), id)
	require.Error(t, err)
	assert.Nil(t, group)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_ListGroupsByUser(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	userID := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "name", "description", "currency", "created_by", "created_at", "updated_at"}).
		AddRow(fixedUUID(), "Home", nil, "USD", userID, fixedTime(), fixedTime())

	mock.ExpectQuery("SELECT .* FROM groups g JOIN group_memberships gm").
		WithArgs(userID, 50, 0).
		WillReturnRows(rows)

	groups, err := repo.ListGroupsByUser(context.Background(), userID, 0, 0)
	require.NoError(t, err)
	assert.Len(t, groups, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_UpdateGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE groups SET").
		WithArgs("New Name", pgxmock.AnyArg(), pgxmock.AnyArg(), id, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	group := &models.Group{ID: id, Name: "New Name"}
	err := repo.UpdateGroup(context.Background(), group)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_DeleteGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM groups WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteGroup(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_CreateMembership(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	m := &models.GroupMembership{
		GroupID: fixedUUID(),
		UserID:  fixedUUID(),
		Role:    "admin",
	}

	mock.ExpectExec("INSERT INTO group_memberships").
		WithArgs(pgxmock.AnyArg(), m.GroupID, m.UserID, m.Role, pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateMembership(context.Background(), m)
	require.NoError(t, err)
	assert.NotEqual(t, uuid.Nil, m.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetMembership(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	gid := fixedUUID()
	uid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "user_id", "role", "joined_at"}).
		AddRow(fixedUUID(), gid, uid, "member", fixedTime())

	mock.ExpectQuery("SELECT .* FROM group_memberships WHERE group_id = .* AND user_id = .*").
		WithArgs(gid, uid).
		WillReturnRows(rows)

	m, err := repo.GetMembership(context.Background(), gid, uid)
	require.NoError(t, err)
	assert.Equal(t, "member", m.Role)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetMembership_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	gid := fixedUUID()
	uid := fixedUUID()

	mock.ExpectQuery("SELECT .* FROM group_memberships WHERE group_id = .* AND user_id = .*").
		WithArgs(gid, uid).
		WillReturnError(pgx.ErrNoRows)

	m, err := repo.GetMembership(context.Background(), gid, uid)
	require.Error(t, err)
	assert.Nil(t, m)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_UpdateMembership(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("UPDATE group_memberships SET role = .* WHERE id = .*").
		WithArgs("admin", id).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	m := &models.GroupMembership{ID: id, Role: "admin"}
	err := repo.UpdateMembership(context.Background(), m)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_DeleteMembership(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM group_memberships WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeleteMembership(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_CreateInvite(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	invite := &models.GroupInvite{
		GroupID:   fixedUUID(),
		Code:      "code123",
		ExpiresAt: fixedTime(),
	}

	mock.ExpectExec("INSERT INTO group_invites").
		WithArgs(pgxmock.AnyArg(), invite.GroupID, invite.Code, invite.ExpiresAt, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreateInvite(context.Background(), invite)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetInviteByCode(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	id := fixedUUID()
	rows := pgxmock.NewRows([]string{"id", "group_id", "code", "expires_at", "used_by", "used_at"}).
		AddRow(id, fixedUUID(), "code123", fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM group_invites WHERE code = .*").
		WithArgs("code123").
		WillReturnRows(rows)

	invite, err := repo.GetInviteByCode(context.Background(), "code123")
	require.NoError(t, err)
	assert.Equal(t, "code123", invite.Code)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetInviteByCode_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	mock.ExpectQuery("SELECT .* FROM group_invites WHERE code = .*").
		WithArgs("missing").
		WillReturnError(pgx.ErrNoRows)

	invite, err := repo.GetInviteByCode(context.Background(), "missing")
	require.Error(t, err)
	assert.Nil(t, invite)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_ConsumeInvite(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	inviteID := fixedUUID()
	userID := fixedUUID()

	mock.ExpectExec("UPDATE group_invites SET used_by = .* WHERE id = .*").
		WithArgs(userID, pgxmock.AnyArg(), inviteID).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	err := repo.ConsumeInvite(context.Background(), inviteID, userID)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_CreatePendingClaim(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	claim := &models.PendingClaim{
		GroupID:   fixedUUID(),
		Code:      "claim123",
		ExpiresAt: fixedTime(),
	}

	mock.ExpectExec("INSERT INTO pending_claims").
		WithArgs(pgxmock.AnyArg(), claim.GroupID, claim.Code, claim.ExpiresAt, pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))

	err := repo.CreatePendingClaim(context.Background(), claim)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetPendingClaimByCode(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	id := fixedUUID()
	rows := pgxmock.NewRows([]string{"id", "group_id", "code", "expires_at", "claimed_by", "claimed_at"}).
		AddRow(id, fixedUUID(), "claim123", fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM pending_claims WHERE code = .*").
		WithArgs("claim123").
		WillReturnRows(rows)

	claim, err := repo.GetPendingClaimByCode(context.Background(), "claim123")
	require.NoError(t, err)
	assert.Equal(t, "claim123", claim.Code)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetPendingClaimByCode_NotFound(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)

	mock.ExpectQuery("SELECT .* FROM pending_claims WHERE code = .*").
		WithArgs("missing").
		WillReturnError(pgx.ErrNoRows)

	claim, err := repo.GetPendingClaimByCode(context.Background(), "missing")
	require.Error(t, err)
	assert.Nil(t, claim)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_DeletePendingClaim(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	mock.ExpectExec("DELETE FROM pending_claims WHERE id = .*").
		WithArgs(id).
		WillReturnResult(pgxmock.NewResult("DELETE", 1))

	err := repo.DeletePendingClaim(context.Background(), id)
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_ListMembershipsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "user_id", "role", "joined_at"}).
		AddRow(fixedUUID(), gid, fixedUUID(), "member", fixedTime()).
		AddRow(fixedUUID(), gid, fixedUUID(), "admin", fixedTime())

	mock.ExpectQuery("SELECT .* FROM group_memberships WHERE group_id = .*").
		WithArgs(gid).
		WillReturnRows(rows)

	memberships, err := repo.ListMembershipsByGroup(context.Background(), gid)
	require.NoError(t, err)
	assert.Len(t, memberships, 2)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_ListPendingClaimsByGroup(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	gid := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "code", "expires_at", "claimed_by", "claimed_at"}).
		AddRow(fixedUUID(), gid, "claim1", fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM pending_claims WHERE group_id = .*").
		WithArgs(gid).
		WillReturnRows(rows)

	claims, err := repo.ListPendingClaimsByGroup(context.Background(), gid)
	require.NoError(t, err)
	assert.Len(t, claims, 1)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestGroupRepository_GetPendingClaimByID(t *testing.T) {
	mock := newMockDB(t)
	repo := NewGroupRepository(mock)
	id := fixedUUID()

	rows := pgxmock.NewRows([]string{"id", "group_id", "code", "expires_at", "claimed_by", "claimed_at"}).
		AddRow(id, fixedUUID(), "claim1", fixedTime(), nil, nil)

	mock.ExpectQuery("SELECT .* FROM pending_claims WHERE id = .*").
		WithArgs(id).
		WillReturnRows(rows)

	claim, err := repo.GetPendingClaimByID(context.Background(), id)
	require.NoError(t, err)
	assert.Equal(t, id, claim.ID)
	assert.NoError(t, mock.ExpectationsWereMet())
}
