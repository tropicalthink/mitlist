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

		name := "New"
		_, err := svc.UpdateGroup(ctx, userID, groupID, UpdateGroupInput{Name: &name})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})

	t.Run("member edits chore zones", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID, Name: "Home"}, nil)
		groupRepo.On("UpdateGroup", ctx, mock.AnythingOfType("*models.Group")).Return(nil)

		zones := []string{"Kitchen", "Bathroom"}
		g, err := svc.UpdateGroup(ctx, userID, groupID, UpdateGroupInput{ChoreZones: &zones})
		require.NoError(t, err)
		assert.Equal(t, zones, g.ChoreZones)
	})

	t.Run("member cannot rename alongside chore zones", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		name := "New"
		zones := []string{"Kitchen"}
		_, err := svc.UpdateGroup(ctx, userID, groupID, UpdateGroupInput{Name: &name, ChoreZones: &zones})
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

	t.Run("plain members can invite too", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("CreateInvite", ctx, mock.AnythingOfType("*models.GroupInvite")).Return(nil)

		invite, err := svc.InviteMember(ctx, userID, groupID, "")
		require.NoError(t, err)
		assert.NotEmpty(t, invite.Code)
	})

	t.Run("non-members cannot invite", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.InviteMember(ctx, userID, groupID, "")
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})

	t.Run("invalid role", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)

		_, err := svc.InviteMember(ctx, userID, groupID, "hacker")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("full household cannot mint an invite", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		svc.SetMemberGate(stubMemberGate{err: &api.PaymentRequiredError{Message: "full"}})

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)

		_, err := svc.InviteMember(ctx, userID, groupID, "member")
		require.Error(t, err)
		assert.IsType(t, &api.PaymentRequiredError{}, err)
		groupRepo.AssertNotCalled(t, "CreateInvite", mock.Anything, mock.Anything)
	})

	t.Run("household with room mints an invite through the gate", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		svc.SetMemberGate(stubMemberGate{})

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("CreateInvite", ctx, mock.AnythingOfType("*models.GroupInvite")).Return(nil)

		invite, err := svc.InviteMember(ctx, userID, groupID, "")
		require.NoError(t, err)
		assert.NotEmpty(t, invite.Code)
	})
}

// stubMemberGate stands in for the billing service's premium gate.
type stubMemberGate struct{ err error }

func (g stubMemberGate) EnsureCanAddMember(context.Context, uuid.UUID) error { return g.err }

func TestGroupService_PreviewInvite(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()
	group := &models.Group{ID: groupID, Name: "Casa Verde"}

	t.Run("valid invite resolves to the household", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(group, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: uuid.New()}, {UserID: uuid.New()},
		}, nil)

		p, err := svc.PreviewInvite(ctx, userID, "  code123 ")
		require.NoError(t, err)
		assert.Equal(t, "Casa Verde", p.GroupName)
		assert.Equal(t, groupID, p.GroupID)
		assert.Equal(t, 2, p.MemberCount)
		assert.Equal(t, models.InviteStatusValid, p.Status)
		// Looking never joins.
		groupRepo.AssertNotCalled(t, "CreateMembership", mock.Anything, mock.Anything)
	})

	t.Run("expired invite still resolves with an expired status", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(-time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(group, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{}, nil)

		p, err := svc.PreviewInvite(ctx, userID, "CODE123")
		require.NoError(t, err)
		assert.Equal(t, models.InviteStatusExpired, p.Status)
	})

	t.Run("existing member is told so", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(group, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{{UserID: userID}}, nil)

		p, err := svc.PreviewInvite(ctx, userID, "CODE123")
		require.NoError(t, err)
		assert.Equal(t, models.InviteStatusAlreadyMember, p.Status)
		assert.Equal(t, 1, p.MemberCount)
	})

	t.Run("unknown code is not found", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetInviteByCode", ctx, "NOPE").Return(nil, pgx.ErrNoRows)

		_, err := svc.PreviewInvite(ctx, userID, "nope")
		var nf *api.NotFoundError
		require.ErrorAs(t, err, &nf)
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
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, userID, "CODE123")
		require.NoError(t, err)
		assert.Equal(t, groupID, g.ID)
	})

	t.Run("one code admits several people until it expires", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "SHARED", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "SHARED").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, mock.Anything).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		first := uuid.New()
		second := uuid.New()
		_, err := svc.JoinGroup(ctx, first, "SHARED")
		require.NoError(t, err)
		_, err = svc.JoinGroup(ctx, second, "SHARED")
		require.NoError(t, err)

		groupRepo.AssertNumberOfCalls(t, "CreateMembership", 2)
	})

	t.Run("normalizes lowercase and padded code", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, userID, "  code123  ")
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

}

func TestGroupService_LeaveGroup(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.LeaveGroup(ctx, userID, groupID)
		require.NoError(t, err)
	})

	t.Run("last admin cannot leave", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
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

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("UpdateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)

		err := svc.UpdateMemberRole(ctx, userID, groupID, targetID, "admin")
		require.NoError(t, err)
	})

	t.Run("cannot demote last admin", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
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

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.NoError(t, err)
	})

	t.Run("plain member may remove another member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.NoError(t, err)
		groupRepo.AssertCalled(t, "DeleteMembership", ctx, mock.AnythingOfType("uuid.UUID"))
	})

	t.Run("non-member is denied", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
		groupRepo.AssertNotCalled(t, "DeleteMembership", mock.Anything, mock.Anything)
	})

	t.Run("last admin cannot be removed", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, targetID).Return(&models.GroupMembership{ID: uuid.New(), UserID: targetID, Role: "admin"}, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return([]models.GroupMembership{
			{UserID: targetID, Role: "admin"},
			{UserID: userID, Role: "member"},
		}, nil)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		groupRepo.AssertNotCalled(t, "DeleteMembership", mock.Anything, mock.Anything)
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
