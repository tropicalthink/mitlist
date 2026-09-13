package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestGroup_CreateGroup(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "group@example.com", "Password123!")
	token := generateTestToken(user.ID)

	body := map[string]any{"name": "My Group", "currency": "USD"}
	rec := execRequest(t, router, "POST", "/api/v1/groups", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "My Group", resp["name"])
}

func TestGroup_CreateGroup_Unauthorized(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)

	body := map[string]any{"name": "My Group"}
	rec := execRequest(t, router, "POST", "/api/v1/groups", body, "")
	requireStatus(t, rec, http.StatusUnauthorized)
}

func TestGroup_ListGroups(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "list@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	listedGroup := &models.Group{
		ID:        uuid.New(),
		Name:      "Test Group",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), listedGroup))
	addTestMembership(t, listedGroup.ID, user.ID, "admin")

	rec := execRequest(t, router, "GET", "/api/v1/groups?limit=10&offset=0", nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestGroup_GetGroup(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "get@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Get Group",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	rec := execRequest(t, router, "GET", "/api/v1/groups/"+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, group.Name, resp["name"])
}

func TestGroup_GetGroup_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "nf@example.com", "Password123!")
	token := generateTestToken(user.ID)

	// GetGroup checks membership before existence to avoid leaking whether a
	// group exists, so a nonexistent group yields 403 for a non-member.
	rec := execRequest(t, router, "GET", "/api/v1/groups/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusForbidden)
}

func TestGroup_UpdateGroup(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "update@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Old Name",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{"name": "New Name"}
	rec := execRequest(t, router, "PATCH", "/api/v1/groups/"+group.ID.String(), body, token)
	requireStatus(t, rec, http.StatusOK)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "New Name", resp["name"])
}

func TestGroup_DeleteGroup(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	user := createTestUser(t, "delete@example.com", "Password123!")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Delete Me",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	rec := execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)

	// Membership is checked before existence (privacy-preserving), so a deleted
	// group the user no longer belongs to yields 403 rather than 404.
	rec = execRequest(t, router, "GET", "/api/v1/groups/"+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusForbidden)
}

func TestGroup_JoinGroup(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	owner := createTestUser(t, "owner@example.com", "Password123!")
	member := createTestUser(t, "member@example.com", "Password123!")
	memberToken := generateTestToken(member.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Join Group",
		Currency:  "USD",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	invite := &models.GroupInvite{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Code:      "JOINCODE123",
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	require.NoError(t, groupRepo.CreateInvite(context.Background(), invite))

	body := map[string]any{"code": invite.Code}
	rec := execRequest(t, router, "POST", "/api/v1/groups/join", body, memberToken)
	requireStatus(t, rec, http.StatusOK)
}

func TestGroup_PreviewInvite(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	owner := createTestUser(t, "preview-owner@example.com", "Password123!")
	invitee := createTestUser(t, "preview-invitee@example.com", "Password123!")
	inviteeToken := generateTestToken(invitee.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Preview House",
		Currency:  "USD",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, owner.ID, "admin")

	invite := &models.GroupInvite{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Code:      "PREVIEWCODE1",
		ExpiresAt: time.Now().Add(24 * time.Hour),
	}
	require.NoError(t, groupRepo.CreateInvite(context.Background(), invite))

	rec := execRequest(t, router, "GET", "/api/v1/groups/invites/previewcode1", nil, inviteeToken)
	requireStatus(t, rec, http.StatusOK)

	var preview models.InvitePreview
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &preview))
	assert.Equal(t, "Preview House", preview.GroupName)
	assert.Equal(t, group.ID, preview.GroupID)
	assert.Equal(t, 1, preview.MemberCount)
	assert.Equal(t, models.InviteStatusValid, preview.Status)

	// Looking does not join.
	membership, err := groupRepo.GetMembership(context.Background(), group.ID, invitee.ID)
	assert.Error(t, err)
	assert.Nil(t, membership)

	// Unknown codes are a 404, not a validation error.
	rec = execRequest(t, router, "GET", "/api/v1/groups/invites/NOSUCHCODE", nil, inviteeToken)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestGroup_RemoveMember(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	owner := createTestUser(t, "owner2@example.com", "Password123!")
	member := createTestUser(t, "member2@example.com", "Password123!")
	ownerToken := generateTestToken(owner.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Remove Group",
		Currency:  "USD",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, owner.ID, "admin")
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		ID:       uuid.New(),
		GroupID:  group.ID,
		UserID:   member.ID,
		Role:     "member",
		JoinedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String()+"/members/"+member.ID.String(), nil, ownerToken)
	requireStatus(t, rec, http.StatusNoContent)

	// Removal is soft. The default roster (what older clients see) drops the
	// person; asking for former members returns them with left_at set so
	// their expenses and chores keep a name.
	membersURL := "/api/v1/groups/" + group.ID.String() + "/members"
	rec = execRequest(t, router, "GET", membersURL, nil, ownerToken)
	requireStatus(t, rec, http.StatusOK)
	var roster []models.GroupMemberProfile
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &roster))
	require.Len(t, roster, 1)
	assert.Equal(t, owner.ID, roster[0].UserID)

	rec = execRequest(t, router, "GET", membersURL+"?include_former=true", nil, ownerToken)
	requireStatus(t, rec, http.StatusOK)
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &roster))
	require.Len(t, roster, 2)
	var former *models.GroupMemberProfile
	for i := range roster {
		if roster[i].UserID == member.ID {
			former = &roster[i]
		}
	}
	require.NotNil(t, former)
	assert.NotNil(t, former.LeftAt)

	// The removed person is locked out of the household.
	rec = execRequest(t, router, "GET", membersURL, nil, generateTestToken(member.ID))
	requireStatus(t, rec, http.StatusForbidden)

	// Removing them again is a 404, not a second stamp.
	rec = execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String()+"/members/"+member.ID.String(), nil, ownerToken)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestGroup_RemoveMember_ByPlainMember(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	owner := createTestUser(t, "owner2b@example.com", "Password123!")
	member := createTestUser(t, "member2b@example.com", "Password123!")
	other := createTestUser(t, "other2b@example.com", "Password123!")
	outsider := createTestUser(t, "outsider2b@example.com", "Password123!")
	memberToken := generateTestToken(member.ID)
	outsiderToken := generateTestToken(outsider.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Remove Group B",
		Currency:  "USD",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, owner.ID, "admin")
	for _, u := range []uuid.UUID{member.ID, other.ID} {
		require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
			ID:       uuid.New(),
			GroupID:  group.ID,
			UserID:   u,
			Role:     "member",
			JoinedAt: time.Now().UTC(),
		}))
	}

	// Someone outside the household cannot remove anyone.
	rec := execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String()+"/members/"+other.ID.String(), nil, outsiderToken)
	requireStatus(t, rec, http.StatusForbidden)

	// A plain member can remove another member without being an admin.
	rec = execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String()+"/members/"+other.ID.String(), nil, memberToken)
	requireStatus(t, rec, http.StatusNoContent)

	// The last admin is still protected.
	rec = execRequest(t, router, "DELETE", "/api/v1/groups/"+group.ID.String()+"/members/"+owner.ID.String(), nil, memberToken)
	requireStatus(t, rec, http.StatusBadRequest)
}

func TestGroup_UpdateMemberRole(t *testing.T) {
	clearTables(t)
	router, _ := newGroupRouter(t)
	owner := createTestUser(t, "owner3@example.com", "Password123!")
	member := createTestUser(t, "member3@example.com", "Password123!")
	ownerToken := generateTestToken(owner.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Role Group",
		Currency:  "USD",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, owner.ID, "admin")
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		ID:       uuid.New(),
		GroupID:  group.ID,
		UserID:   member.ID,
		Role:     "member",
		JoinedAt: time.Now().UTC(),
	}))

	body := map[string]any{"role": "admin"}
	rec := execRequest(t, router, "PATCH", "/api/v1/groups/"+group.ID.String()+"/members/"+member.ID.String(), body, ownerToken)
	requireStatus(t, rec, http.StatusNoContent)
}
