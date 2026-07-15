package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestGroupService_CreateGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("CreateGroup", ctx, mock.AnythingOfType("*models.Group")).Return(nil)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)

		group, err := svc.CreateGroup(ctx, userID, CreateGroupInput{Name: "My Group"})
		require.NoError(t, err)
		assert.Equal(t, "My Group", group.Name)
		assert.Equal(t, userID, group.CreatedBy)
	})

	t.Run("missing name", func(t *testing.T) {
		svc := NewGroupService(nil, nil)
		_, err := svc.CreateGroup(ctx, userID, CreateGroupInput{Name: ""})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGroupService_GetGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Name: "G"}, nil)

		g, err := svc.GetGroup(ctx, userID, groupID)
		require.NoError(t, err)
		assert.Equal(t, "G", g.Name)
	})

	t.Run("not a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetGroup(ctx, userID, groupID)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestGroupService_UpdateGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Name: "Old"}, nil)
		groupRepo.On("UpdateGroup", ctx, mock.AnythingOfType("*models.Group")).Return(nil)

		name := "New"
		g, err := svc.UpdateGroup(ctx, userID, groupID, UpdateGroupInput{Name: &name})
		require.NoError(t, err)
		assert.Equal(t, "New", g.Name)
	})

	t.Run("not admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		_, err := svc.UpdateGroup(ctx, userID, groupID, UpdateGroupInput{})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})
}

func TestGroupService_DeleteGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("DeleteGroup", ctx, groupID).Return(nil)

		err := svc.DeleteGroup(ctx, userID, groupID)
		require.NoError(t, err)
	})
}

func TestGroupService_InviteMember(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("CreateInvite", ctx, mock.AnythingOfType("*models.GroupInvite")).Return(nil)

		invite, err := svc.InviteMember(ctx, userID, groupID, "member")
		require.NoError(t, err)
		assert.NotEmpty(t, invite.Code)
		assert.Equal(t, groupID, invite.GroupID)
	})

	t.Run("invalid role", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)

		_, err := svc.InviteMember(ctx, userID, groupID, "hacker")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGroupService_JoinGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("ConsumeInvite", ctx, invite.ID, userID).Return(nil)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, userID, "CODE123")
		require.NoError(t, err)
		assert.Equal(t, groupID, g.ID)
	})

	t.Run("normalizes lowercase and padded code", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("ConsumeInvite", ctx, invite.ID, userID).Return(nil)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, userID, "  code123  ")
		require.NoError(t, err)
		assert.Equal(t, groupID, g.ID)
	})

	t.Run("previously used invite is reusable until expiry", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		usedBy := uuid.New()
		usedAt := time.Now().UTC().Add(-time.Hour)
		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "USED", ExpiresAt: time.Now().UTC().Add(time.Hour), UsedBy: &usedBy, UsedAt: &usedAt}
		groupRepo.On("GetInviteByCode", ctx, "USED").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("ConsumeInvite", ctx, invite.ID, userID).Return(nil)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, userID, "USED")
		require.NoError(t, err)
		assert.Equal(t, groupID, g.ID)
	})

	t.Run("invite expired", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{GroupID: groupID, Code: "EXPIRED", ExpiresAt: time.Now().UTC().Add(-time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "EXPIRED").Return(invite, nil)

		_, err := svc.JoinGroup(ctx, userID, "EXPIRED")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("already a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{}, nil)

		_, err := svc.JoinGroup(ctx, userID, "CODE")
		require.Error(t, err)
		assert.IsType(t, &api.ConflictError{}, err)
	})

	t.Run("consume failure creates no membership", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "RACE", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "RACE").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("ConsumeInvite", ctx, invite.ID, userID).Return(assert.AnError)

		_, err := svc.JoinGroup(ctx, userID, "RACE")
		require.Error(t, err)
		groupRepo.AssertNotCalled(t, "CreateMembership", mock.Anything, mock.Anything)
	})
}

func TestGroupService_LeaveGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.LeaveGroup(ctx, userID, groupID)
		require.NoError(t, err)
	})

	t.Run("last admin cannot leave", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{ID: uuid.New(), Role: "admin"}, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{{UserID: userID, Role: "admin"}}, nil)

		err := svc.LeaveGroup(ctx, userID, groupID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGroupService_UpdateMemberRole(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	targetID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("UpdateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)

		err := svc.UpdateMemberRole(ctx, userID, groupID, targetID, "admin")
		require.NoError(t, err)
	})

	t.Run("cannot demote last admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "admin"}, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{{UserID: targetID, Role: "admin"}}, nil)

		err := svc.UpdateMemberRole(ctx, userID, groupID, targetID, "member")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGroupService_RemoveMember(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	targetID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.NoError(t, err)
	})
}

func TestGroupService_GetPendingClaims(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("ListPendingClaimsByGroup", ctx, groupID).Return([]models.PendingClaim{{}}, nil)

		claims, err := svc.GetPendingClaims(ctx, userID, groupID)
		require.NoError(t, err)
		assert.Len(t, claims, 1)
	})
}

func TestGroupService_ApproveClaim(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	claimID := uuid.New()
	claimedBy := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetPendingClaimByID", ctx, claimID).Return(&models.PendingClaim{ID: claimID, GroupID: groupID, ClaimedBy: &claimedBy}, nil)
		groupRepo.On("GetMembership", ctx, groupID, claimedBy).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("DeletePendingClaim", ctx, claimID).Return(nil)

		err := svc.ApproveClaim(ctx, userID, groupID, claimID)
		require.NoError(t, err)
	})

	t.Run("claim not claimed", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetPendingClaimByID", ctx, claimID).Return(&models.PendingClaim{ID: claimID, GroupID: groupID, ClaimedBy: nil}, nil)

		err := svc.ApproveClaim(ctx, userID, groupID, claimID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestGroupService_RejectClaim(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	claimID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetPendingClaimByID", ctx, claimID).Return(&models.PendingClaim{ID: claimID, GroupID: groupID}, nil)
		groupRepo.On("DeletePendingClaim", ctx, claimID).Return(nil)

		err := svc.RejectClaim(ctx, userID, groupID, claimID)
		require.NoError(t, err)
	})
}

func TestGroupService_IsLastAdmin(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	otherID := uuid.New()

	t.Run("true when only admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: userID, Role: "admin"},
			{UserID: otherID, Role: "member"},
		}, nil)

		isLast, err := svc.isLastAdmin(ctx, groupID, userID)
		require.NoError(t, err)
		assert.True(t, isLast)
	})

	t.Run("false when another admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: userID, Role: "admin"},
			{UserID: otherID, Role: "admin"},
		}, nil)

		isLast, err := svc.isLastAdmin(ctx, groupID, userID)
		require.NoError(t, err)
		assert.False(t, isLast)
	})
}
