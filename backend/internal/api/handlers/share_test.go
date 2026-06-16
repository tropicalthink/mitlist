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

func TestShare_CreateListFromShare(t *testing.T) {
	clearTables(t)
	router, _ := newShareRouter(t)
	user := createTestUser(t, "share@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Share Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id": group.ID.String(),
		"text":     "Milk, Eggs, Bread",
	}
	rec := execRequest(t, router, "POST", "/share-target/lists", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.NotNil(t, resp["list"])
}

func TestShare_CreateRecipeFromShare(t *testing.T) {
	clearTables(t)
	router, _ := newShareRouter(t)
	user := createTestUser(t, "sharerec@example.com", "password123")
	token := generateTestToken(user.ID)

	body := map[string]any{"text": "Pasta recipe from https://example.com/pasta"}
	rec := execRequest(t, router, "POST", "/share-target/recipes", body, token)
	requireStatus(t, rec, http.StatusCreated)
}
