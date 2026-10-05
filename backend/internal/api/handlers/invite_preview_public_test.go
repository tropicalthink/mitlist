package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
)

// The signed-out invite preview (plans/048 stage 7): no session, only what
// the welcome screen shows, and a 404 for anything that is not a live code.
func TestGroup_PreviewInvitePublic(t *testing.T) {
	clearTables(t)
	authed, h := newGroupRouter(t)
	public := chi.NewRouter()
	public.Route("/api/v1", h.RegisterPublicRoutes)
	limitKey := "ratelimit:invite-preview:ip:192.0.2.1"
	middleware.ResetLimit(limitKey)
	t.Cleanup(func() { middleware.ResetLimit(limitKey) })

	owner := createTestUser(t, "public-preview-owner@example.com", "Password123!")
	ownerToken := generateTestToken(owner.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Flat 3B",
		Currency:  "EUR",
		CreatedBy: owner.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, owner.ID, "admin")

	// Minting through the API records who invited.
	rec := execRequest(t, authed, "POST", "/api/v1/groups/"+group.ID.String()+"/members", map[string]any{"role": "member"}, ownerToken)
	requireStatus(t, rec, http.StatusCreated)
	var invite models.GroupInvite
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &invite))

	rec = execRequest(t, public, "GET", "/api/v1/invites/"+strings.ToLower(invite.Code)+"/preview", nil, "")
	requireStatus(t, rec, http.StatusOK)
	assert.Equal(t, "no-store", rec.Header().Get("Cache-Control"))

	var body map[string]any
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &body))
	assert.Equal(t, map[string]any{
		"household_name": "Flat 3B",
		"inviter_name":   owner.FirstName,
		"member_count":   float64(1),
		"status":         models.InviteStatusValid,
	}, body)
	// Nothing that identifies anyone or reopens the code.
	raw := rec.Body.String()
	for _, leak := range []string{group.ID.String(), owner.ID.String(), owner.Email, invite.Code} {
		assert.NotContains(t, raw, leak)
	}

	// Unknown and malformed codes look the same.
	rec = execRequest(t, public, "GET", "/api/v1/invites/NOSUCHCODE/preview", nil, "")
	requireStatus(t, rec, http.StatusNotFound)
	rec = execRequest(t, public, "GET", "/api/v1/invites/ab/preview", nil, "")
	requireStatus(t, rec, http.StatusNotFound)
}

func TestGroup_PreviewInvitePublic_RateLimited(t *testing.T) {
	clearTables(t)
	_, h := newGroupRouter(t)
	public := chi.NewRouter()
	public.Route("/api/v1", h.RegisterPublicRoutes)
	limitKey := "ratelimit:invite-preview:ip:192.0.2.1"
	middleware.ResetLimit(limitKey)
	t.Cleanup(func() { middleware.ResetLimit(limitKey) })

	for i := 0; i < invitePreviewBurst; i++ {
		rec := execRequest(t, public, "GET", "/api/v1/invites/NOSUCHCODE/preview", nil, "")
		requireStatus(t, rec, http.StatusNotFound)
	}
	rec := execRequest(t, public, "GET", "/api/v1/invites/NOSUCHCODE/preview", nil, "")
	requireStatus(t, rec, http.StatusTooManyRequests)
}
