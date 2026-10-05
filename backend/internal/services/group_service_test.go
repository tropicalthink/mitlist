package services

import (
	"context"
	"encoding/json"
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

		groupRepo.On("GetGroupByIDForUser", ctx, groupID, userID).Return(&models.Group{ID: groupID, Name: "G"}, nil)

		g, err := svc.GetGroup(ctx, userID, groupID)
		require.NoError(t, err)
		assert.Equal(t, "G", g.Name)
	})

	t.Run("not a member", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)

		groupRepo.On("GetGroupByIDForUser", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

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
		// The code remembers who sent it, for the signed-out preview.
		require.NotNil(t, invite.CreatedBy)
		assert.Equal(t, userID, *invite.CreatedBy)
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

func TestGroupService_PreviewInvitePublic(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	inviterID := uuid.New()
	group := &models.Group{ID: groupID, Name: "Flat 3B"}
	live := time.Now().UTC().Add(time.Hour)

	setup := func(invite *models.GroupInvite, members []models.GroupMembership) (*GroupService, *mocks.MockGroupRepo, *mocks.MockUserRepo) {
		groupRepo := new(mocks.MockGroupRepo)
		userRepo := new(mocks.MockUserRepo)
		groupRepo.On("GetInviteByCode", ctx, invite.Code).Return(invite, nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(group, nil)
		groupRepo.On("ListMembershipsByGroup", ctx, groupID).Return(members, nil)
		return NewGroupService(groupRepo, userRepo), groupRepo, userRepo
	}
	invite := func(expires time.Time, inviter *uuid.UUID) *models.GroupInvite {
		return &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "SUNNY-TACO", ExpiresAt: expires, CreatedBy: inviter}
	}

	t.Run("names the household and the inviter's first name", func(t *testing.T) {
		svc, _, userRepo := setup(invite(live, &inviterID), []models.GroupMembership{
			{UserID: inviterID}, {UserID: uuid.New()}, {UserID: uuid.New()},
		})
		userRepo.On("GetByID", ctx, inviterID).Return(&models.User{
			ID: inviterID, FirstName: " Sam ", LastName: "Okafor", Email: "sam@example.com", IsActive: true,
		}, nil)

		p, err := svc.PreviewInvitePublic(ctx, "  sunny-taco ")
		require.NoError(t, err)
		assert.Equal(t, "Flat 3B", p.HouseholdName)
		require.NotNil(t, p.InviterName)
		assert.Equal(t, "Sam", *p.InviterName)
		assert.Equal(t, 3, p.MemberCount)
		assert.Equal(t, models.InviteStatusValid, p.Status)

		// What goes over the wire: no ids, no emails, no last name, no code.
		raw, err := json.Marshal(p)
		require.NoError(t, err)
		var fields map[string]any
		require.NoError(t, json.Unmarshal(raw, &fields))
		assert.ElementsMatch(t, []string{"household_name", "inviter_name", "member_count", "status"}, jsonKeys(fields))
		for _, leak := range []string{groupID.String(), inviterID.String(), "sam@example.com", "Okafor", "SUNNY-TACO"} {
			assert.NotContains(t, string(raw), leak)
		}
	})

	t.Run("an inviter who left is not named", func(t *testing.T) {
		svc, _, userRepo := setup(invite(live, &inviterID), []models.GroupMembership{{UserID: uuid.New()}})

		p, err := svc.PreviewInvitePublic(ctx, "SUNNY-TACO")
		require.NoError(t, err)
		assert.Nil(t, p.InviterName)
		userRepo.AssertNotCalled(t, "GetByID", mock.Anything, mock.Anything)

		raw, _ := json.Marshal(p)
		assert.NotContains(t, string(raw), "inviter_name")
	})

	t.Run("a deactivated inviter is not named", func(t *testing.T) {
		svc, _, userRepo := setup(invite(live, &inviterID), []models.GroupMembership{{UserID: inviterID}})
		userRepo.On("GetByID", ctx, inviterID).Return(&models.User{ID: inviterID, FirstName: "Sam", IsActive: false}, nil)

		p, err := svc.PreviewInvitePublic(ctx, "SUNNY-TACO")
		require.NoError(t, err)
		assert.Nil(t, p.InviterName)
	})

	t.Run("a code minted before inviters were recorded has no name", func(t *testing.T) {
		svc, _, userRepo := setup(invite(live, nil), []models.GroupMembership{{UserID: inviterID}})

		p, err := svc.PreviewInvitePublic(ctx, "SUNNY-TACO")
		require.NoError(t, err)
		assert.Nil(t, p.InviterName)
		assert.Equal(t, "Flat 3B", p.HouseholdName)
		userRepo.AssertNotCalled(t, "GetByID", mock.Anything, mock.Anything)
	})

	t.Run("an expired code still resolves, as expired", func(t *testing.T) {
		svc, _, userRepo := setup(invite(time.Now().UTC().Add(-time.Hour), &inviterID), []models.GroupMembership{{UserID: inviterID}})
		userRepo.On("GetByID", ctx, inviterID).Return(&models.User{ID: inviterID, FirstName: "Sam", IsActive: true}, nil)

		p, err := svc.PreviewInvitePublic(ctx, "SUNNY-TACO")
		require.NoError(t, err)
		assert.Equal(t, models.InviteStatusExpired, p.Status)
	})

	t.Run("an unknown code is not found", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		groupRepo.On("GetInviteByCode", ctx, "NOPE").Return(nil, pgx.ErrNoRows)

		_, err := svc.PreviewInvitePublic(ctx, "nope")
		var nf *api.NotFoundError
		require.ErrorAs(t, err, &nf)
	})
}

func jsonKeys(m map[string]any) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
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
		groupRepo.On("EndMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

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
		groupRepo.On("EndMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

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
		groupRepo.On("EndMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.RemoveMember(ctx, userID, groupID, targetID)
		require.NoError(t, err)
		groupRepo.AssertCalled(t, "EndMembership", ctx, mock.AnythingOfType("uuid.UUID"))
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
		groupRepo.AssertNotCalled(t, "EndMembership", mock.Anything, mock.Anything)
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
		groupRepo.AssertNotCalled(t, "EndMembership", mock.Anything, mock.Anything)
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

// stubMemberOrderSyncer records rotation rebuild requests and fails with err.
type stubMemberOrderSyncer struct {
	groupIDs []uuid.UUID
	err      error
}

func (s *stubMemberOrderSyncer) SyncMemberOrderForGroup(_ context.Context, groupID uuid.UUID) error {
	s.groupIDs = append(s.groupIDs, groupID)
	return s.err
}

// attachChoreRotation gives svc a real ChoreService over one chore whose
// rotation starts as order. members is the household after the change, and
// the rebuild must write want. Contexts are matched loosely because the
// rebuild runs on a context detached from the request.
func attachChoreRotation(svc *GroupService, groupRepo *mocks.MockGroupRepo, groupID uuid.UUID, order, members, want []uuid.UUID) *mocks.MockChoreRepo {
	choreRepo := new(mocks.MockChoreRepo)
	svc.SetMemberOrderSyncer(NewChoreService(choreRepo, groupRepo, nil))

	memberships := make([]models.GroupMembership, 0, len(members))
	for _, id := range members {
		memberships = append(memberships, models.GroupMembership{GroupID: groupID, UserID: id})
	}
	choreID := uuid.New()
	groupRepo.On("ListMembershipsByGroup", mock.Anything, groupID).Return(memberships, nil)
	choreRepo.On("ListChoresByGroup", mock.Anything, groupID, rebuildChorePageSize, 0).Return([]models.Chore{{ID: choreID, GroupID: groupID}}, nil)
	choreRepo.On("GetRotationStatesByChoreIDs", mock.Anything, []uuid.UUID{choreID}).Return([]models.ChoreRotationState{
		{ID: uuid.New(), ChoreID: choreID, MemberOrder: order},
	}, nil)
	choreRepo.On("BulkUpdateRotationStates", mock.Anything, mock.MatchedBy(func(states []models.ChoreRotationState) bool {
		return len(states) == 1 && states[0].ChoreID == choreID && assert.ObjectsAreEqual(want, states[0].MemberOrder)
	})).Return(nil)
	return choreRepo
}

// A chore created before someone joined must still rotate to them, and stop
// rotating to someone who left (plans/048 stage 1).
func TestGroupService_MembershipChangesRebuildChoreRotations(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	founder := uuid.New()
	flatmate := uuid.New()

	t.Run("join adds the new member to an existing chore", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		choreRepo := attachChoreRotation(svc, groupRepo, groupID,
			[]uuid.UUID{founder}, []uuid.UUID{founder, flatmate}, []uuid.UUID{founder, flatmate})

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		_, err := svc.JoinGroup(ctx, flatmate, "CODE123")
		require.NoError(t, err)
		choreRepo.AssertExpectations(t)
	})

	t.Run("approved claim adds the claimant to an existing chore", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		choreRepo := attachChoreRotation(svc, groupRepo, groupID,
			[]uuid.UUID{founder}, []uuid.UUID{founder, flatmate}, []uuid.UUID{founder, flatmate})
		claimID := uuid.New()

		groupRepo.On("GetMembership", ctx, groupID, founder).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetPendingClaimByID", ctx, claimID).Return(&models.PendingClaim{ID: claimID, GroupID: groupID, ClaimedBy: &flatmate}, nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("DeletePendingClaim", ctx, claimID).Return(nil)

		err := svc.ApproveClaim(ctx, founder, groupID, claimID)
		require.NoError(t, err)
		choreRepo.AssertExpectations(t)
	})

	t.Run("leaving takes the member out of the rotation", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		choreRepo := attachChoreRotation(svc, groupRepo, groupID,
			[]uuid.UUID{founder, flatmate}, []uuid.UUID{founder}, []uuid.UUID{founder})

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("EndMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.LeaveGroup(ctx, flatmate, groupID)
		require.NoError(t, err)
		choreRepo.AssertExpectations(t)
	})

	t.Run("removal takes the member out of the rotation", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		choreRepo := attachChoreRotation(svc, groupRepo, groupID,
			[]uuid.UUID{founder, flatmate}, []uuid.UUID{founder}, []uuid.UUID{founder})

		groupRepo.On("WithTx", ctx, mock.Anything).Return(nil)
		groupRepo.On("LockGroup", ctx, groupID).Return(nil)
		groupRepo.On("GetMembership", ctx, groupID, founder).Return(&models.GroupMembership{Role: "admin"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(&models.GroupMembership{ID: uuid.New(), Role: "member"}, nil)
		groupRepo.On("EndMembership", ctx, mock.AnythingOfType("uuid.UUID")).Return(nil)

		err := svc.RemoveMember(ctx, founder, groupID, flatmate)
		require.NoError(t, err)
		choreRepo.AssertExpectations(t)
	})

	t.Run("a failed rebuild does not fail the join", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		syncer := &stubMemberOrderSyncer{err: assert.AnError}
		svc.SetMemberOrderSyncer(syncer)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(nil, pgx.ErrNoRows)
		groupRepo.On("CreateMembership", ctx, mock.AnythingOfType("*models.GroupMembership")).Return(nil)
		groupRepo.On("GetGroupByID", ctx, groupID).Return(&models.Group{ID: groupID}, nil)

		g, err := svc.JoinGroup(ctx, flatmate, "CODE123")
		require.NoError(t, err)
		assert.Equal(t, groupID, g.ID)
		assert.Equal(t, []uuid.UUID{groupID}, syncer.groupIDs)
	})

	t.Run("a failed join does not rebuild", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewGroupService(groupRepo, nil)
		syncer := &stubMemberOrderSyncer{}
		svc.SetMemberOrderSyncer(syncer)

		invite := &models.GroupInvite{ID: uuid.New(), GroupID: groupID, Code: "CODE123", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		groupRepo.On("GetInviteByCode", ctx, "CODE123").Return(invite, nil)
		groupRepo.On("GetMembership", ctx, groupID, flatmate).Return(&models.GroupMembership{}, nil)

		_, err := svc.JoinGroup(ctx, flatmate, "CODE123")
		require.Error(t, err)
		assert.Empty(t, syncer.groupIDs)
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
