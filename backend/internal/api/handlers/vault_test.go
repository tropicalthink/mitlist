package handlers

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/models"
)

func TestVault_CreateVaultItem(t *testing.T) {
	clearTables(t)
	router, _ := newVaultRouter(t)
	user := createTestUser(t, "vault@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Vault Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

	body := map[string]any{
		"group_id": group.ID.String(),
		"type":     "note",
		"title":    "Passport",
		"content":  "12345",
	}
	rec := execRequest(t, router, "POST", "/vault", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Passport", resp["title"])
}

func TestVault_ListVaultItems(t *testing.T) {
	clearTables(t)
	router, _ := newVaultRouter(t)
	user := createTestUser(t, "lsvault@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	vaultRepo := newTestVaultRepo()
	require.NoError(t, vaultRepo.CreateVaultItem(context.Background(), &models.VaultItem{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Type:      "note",
		Title:     "Secret",
		Content:   "data",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/vault?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestVault_GetVaultItem_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newVaultRouter(t)
	user := createTestUser(t, "nfvault@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/vault/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestVault_DeleteVaultItem(t *testing.T) {
	clearTables(t)
	router, _ := newVaultRouter(t)
	user := createTestUser(t, "delvault@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	vaultRepo := newTestVaultRepo()
	item := &models.VaultItem{
		ID:        uuid.New(),
		GroupID:   group.ID,
		Type:      "note",
		Title:     "Del",
		Content:   "data",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, vaultRepo.CreateVaultItem(context.Background(), item))

	rec := execRequest(t, router, "DELETE", "/vault/"+item.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}
