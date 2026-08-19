package handlers

import (
	"context"
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
