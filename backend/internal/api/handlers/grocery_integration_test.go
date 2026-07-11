package handlers

import (
	"context"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func newGroceryRouter(t *testing.T) (chi.Router, *GroceryHandler) {
	t.Helper()

	h := NewGroceryHandler(newTestGroceryService())

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	return r, h
}

func TestGroceryGraphSyncRoundTrip(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)

	user := createTestUser(t, "grocery@example.com", "password123")
	token := generateTestToken(user.ID)

	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Grocery Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, newTestGroupRepo().CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	canonicalID := uuid.MustParse("11111111-2222-3333-4444-555555555555")
	now := time.Now().UTC()
	_, err := testDB.Exec(context.Background(), `
		INSERT INTO canonical_items (id, group_id, name_de, name_en, category, default_unit, is_global, version, created_at, updated_at)
		VALUES ($1, $2, 'Vollmilch', 'whole milk', 'dairy', 'l', false, 0, $3, $3)`,
		canonicalID, group.ID, now)
	require.NoError(t, err)

	rec := execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var initial models.GroceryGraphDelta
	parseJSONResponse(t, rec, &initial)
	assert.Equal(t, int64(0), initial.MaxVersion)
	assert.Empty(t, initial.CanonicalItems)
	assert.Empty(t, initial.ItemAliases)
	assert.Empty(t, initial.Corrections)
	assert.Empty(t, initial.StoreAisles)
	assert.Empty(t, initial.PurchaseHistory)
	assert.Empty(t, initial.ItemCooccurrence)

	correctionBody := map[string]any{
		"raw_text":          "vollmilch",
		"kind":              "alias",
		"canonical_item_id": canonicalID.String(),
		"canonical_item": map[string]any{
			"id":           canonicalID.String(),
			"name_de":      "Vollmilch",
			"name_en":      "whole milk",
			"category":     "dairy",
			"default_unit": "l",
		},
		"lang": "de",
	}
	rec = execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/corrections", correctionBody, token)
	requireStatus(t, rec, http.StatusOK)
	var versionResp struct {
		Version int64 `json:"version"`
	}
	parseJSONResponse(t, rec, &versionResp)
	assert.Equal(t, int64(1), versionResp.Version)

	rec = execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var afterCorrection models.GroceryGraphDelta
	parseJSONResponse(t, rec, &afterCorrection)
	assert.Equal(t, int64(1), afterCorrection.MaxVersion)
	require.Len(t, afterCorrection.Corrections, 1)
	require.Len(t, afterCorrection.ItemAliases, 1)
	assert.Equal(t, "vollmilch", afterCorrection.ItemAliases[0].AliasText)

	rec = execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=1", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var cursorDelta models.GroceryGraphDelta
	parseJSONResponse(t, rec, &cursorDelta)
	assert.Equal(t, int64(1), cursorDelta.MaxVersion)
	assert.Empty(t, cursorDelta.Corrections)
	assert.Empty(t, cursorDelta.ItemAliases)

	aisleBody := map[string]any{
		"aisles": []map[string]any{
			{
				"canonical_item_id": canonicalID.String(),
				"aisle":             "dairy",
				"sort_order":        3,
			},
		},
	}
	rec = execRequest(t, router, "PATCH", "/groups/"+group.ID.String()+"/grocery/aisles", aisleBody, token)
	requireStatus(t, rec, http.StatusOK)
	parseJSONResponse(t, rec, &versionResp)
	assert.Equal(t, int64(2), versionResp.Version)

	outsider := createTestUser(t, "grocery-outsider@example.com", "password123")
	outsiderToken := generateTestToken(outsider.ID)
	rec = execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, outsiderToken)
	requireStatus(t, rec, http.StatusForbidden)
}

func TestGroceryCorrectionCreatesUnseededCanonicalItem(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)

	user := createTestUser(t, "grocery-unseeded@example.com", "password123")
	token := generateTestToken(user.ID)

	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Unseeded Grocery Group",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, newTestGroupRepo().CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	canonicalID := uuid.MustParse("caaf4e84-1dec-5ed5-a18b-9462df102dc4")
	correctionBody := map[string]any{
		"raw_text":          "hafermilch",
		"kind":              "alias",
		"canonical_item_id": canonicalID.String(),
		"canonical_item": map[string]any{
			"id":           canonicalID.String(),
			"name_de":      "Hafermilch",
			"name_en":      "oat milk",
			"category":     "dairy",
			"default_unit": "l",
		},
		"lang": "de",
	}

	rec := execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/corrections", correctionBody, token)
	requireStatus(t, rec, http.StatusOK)
	var versionResp struct {
		Version int64 `json:"version"`
	}
	parseJSONResponse(t, rec, &versionResp)
	assert.Equal(t, int64(1), versionResp.Version)

	var canonicalCount int
	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT count(*) FROM canonical_items WHERE id = $1`, canonicalID).Scan(&canonicalCount))
	assert.Equal(t, 1, canonicalCount)

	var aliasCanonicalID uuid.UUID
	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT canonical_item_id FROM item_aliases WHERE group_id = $1 AND alias_text = 'hafermilch'`,
		group.ID,
	).Scan(&aliasCanonicalID))
	assert.Equal(t, canonicalID, aliasCanonicalID)

	rec = execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var graph models.GroceryGraphDelta
	parseJSONResponse(t, rec, &graph)
	assert.Equal(t, int64(1), graph.MaxVersion)
	require.Len(t, graph.CanonicalItems, 1)
	require.Len(t, graph.ItemAliases, 1)
	assert.Equal(t, canonicalID, graph.CanonicalItems[0].ID)
	assert.Equal(t, canonicalID, graph.ItemAliases[0].CanonicalItemID)

	rec = execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/corrections", correctionBody, token)
	requireStatus(t, rec, http.StatusOK)
	parseJSONResponse(t, rec, &versionResp)
	assert.Equal(t, int64(2), versionResp.Version)

	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT count(*) FROM canonical_items WHERE id = $1`, canonicalID).Scan(&canonicalCount))
	assert.Equal(t, 1, canonicalCount)
}

func TestGroceryPurchaseBatchIsIdempotent(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)
	user := createTestUser(t, "grocery-purchases@example.com", "password123")
	token := generateTestToken(user.ID)
	group := createGroceryTestGroup(t, user.ID, "Purchase Learning Group")

	eventID := uuid.New()
	milkID := uuid.MustParse("11111111-1111-5111-8111-111111111111")
	cerealID := uuid.MustParse("22222222-2222-5222-8222-222222222222")
	body := map[string]any{"events": []map[string]any{{
		"id": eventID.String(),
		"canonical_item": map[string]any{
			"id": milkID.String(), "name_de": "Milch", "name_en": "Milk",
			"category": "dairy", "default_unit": "l",
		},
		"quantity": 1, "unit": "l", "purchased_at": time.Now().UTC(),
		"peers": []map[string]any{{
			"id": cerealID.String(), "name_de": "Muesli", "name_en": "Cereal",
			"category": "pantry", "default_unit": "g",
		}},
	}}}

	for range 2 {
		rec := execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/purchases", body, token)
		requireStatus(t, rec, http.StatusOK)
	}

	var purchaseCount, pairCount int
	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT count(*) FROM purchase_history WHERE id = $1`, eventID).Scan(&purchaseCount))
	require.NoError(t, testDB.QueryRow(context.Background(),
		`SELECT count FROM item_cooccurrence WHERE group_id = $1`, group.ID).Scan(&pairCount))
	assert.Equal(t, 1, purchaseCount)
	assert.Equal(t, 1, pairCount)

	rec := execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var graph models.GroceryGraphDelta
	parseJSONResponse(t, rec, &graph)
	require.Len(t, graph.PurchaseHistory, 1)
	require.Len(t, graph.ItemCooccurrence, 1)
}

func TestGroceryCorrectionRecorrectionUpdatesAliasCanonicalID(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)

	user := createTestUser(t, "grocery-recorrection@example.com", "password123")
	token := generateTestToken(user.ID)
	group := createGroceryTestGroup(t, user.ID, "Grocery Recorrection Group")

	firstID := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	secondID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	insertGroceryCanonicalItem(t, group.ID, firstID, "Milch")
	insertGroceryCanonicalItem(t, group.ID, secondID, "Hafermilch")

	postCorrection := func(canonicalID uuid.UUID, name string) {
		t.Helper()
		body := map[string]any{
			"raw_text":          "melk",
			"kind":              "alias",
			"scope":             "household",
			"canonical_item_id": canonicalID.String(),
			"canonical_item": map[string]any{
				"id":           canonicalID.String(),
				"name_de":      name,
				"name_en":      name,
				"category":     "dairy",
				"default_unit": "l",
			},
			"lang": "de",
		}
		rec := execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/corrections", body, token)
		requireStatus(t, rec, http.StatusOK)
	}

	postCorrection(firstID, "Milch")
	postCorrection(secondID, "Hafermilch")

	rec := execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version=0", nil, token)
	requireStatus(t, rec, http.StatusOK)
	var graph models.GroceryGraphDelta
	parseJSONResponse(t, rec, &graph)

	var melkAliases []models.ItemAlias
	for _, alias := range graph.ItemAliases {
		if alias.AliasText == "melk" {
			melkAliases = append(melkAliases, alias)
		}
	}
	require.Len(t, melkAliases, 1)
	assert.Equal(t, secondID, melkAliases[0].CanonicalItemID)
	assert.Equal(t, 2, melkAliases[0].Weight)
}

func TestGroceryGraphDeltaPaginationDrains(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)

	user := createTestUser(t, "grocery-pagination@example.com", "password123")
	token := generateTestToken(user.ID)
	group := createGroceryTestGroup(t, user.ID, "Grocery Pagination Group")

	canonicalID := uuid.MustParse("33333333-3333-3333-3333-333333333333")
	insertGroceryCanonicalItem(t, group.ID, canonicalID, "Milch")
	now := time.Now().UTC()
	_, err := testDB.Exec(context.Background(), `
		INSERT INTO grocery_versions (group_id, current_version, updated_at)
		VALUES ($1, 501, $2)`,
		group.ID, now)
	require.NoError(t, err)
	_, err = testDB.Exec(context.Background(), `
		INSERT INTO item_aliases
			(id, group_id, canonical_item_id, alias_text, lang, source, weight, version, created_at, updated_at)
		SELECT uuid_generate_v4(), $1, $2, 'alias-' || gs::text, 'de', 'correction', 1, gs, $3, $3
		FROM generate_series(1, 501) AS gs`,
		group.ID, canonicalID, now)
	require.NoError(t, err)

	seen := map[string]struct{}{}
	sinceVersion := int64(0)
	for {
		rec := execRequest(t, router, "GET", "/groups/"+group.ID.String()+"/grocery/graph?since_version="+strconv.FormatInt(sinceVersion, 10), nil, token)
		requireStatus(t, rec, http.StatusOK)
		var graph models.GroceryGraphDelta
		parseJSONResponse(t, rec, &graph)
		for _, alias := range graph.ItemAliases {
			if _, exists := seen[alias.AliasText]; exists {
				t.Fatalf("duplicate alias in pagination drain: %s", alias.AliasText)
			}
			seen[alias.AliasText] = struct{}{}
		}
		sinceVersion = graph.MaxVersion
		if !graph.HasMore {
			break
		}
	}
	assert.Len(t, seen, 501)
	assert.Equal(t, int64(501), sinceVersion)
}

func TestGroceryHandlerValidation(t *testing.T) {
	clearTables(t)
	router, _ := newGroceryRouter(t)

	user := createTestUser(t, "grocery-validation@example.com", "password123")
	token := generateTestToken(user.ID)
	group := createGroceryTestGroup(t, user.ID, "Grocery Validation Group")

	rec := execRequest(t, router, "POST", "/groups/"+group.ID.String()+"/grocery/corrections", map[string]any{
		"raw_text": strings.Repeat("x", 201),
		"kind":     "alias",
		"scope":    "household",
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)
	var errResp struct {
		Field string `json:"field"`
	}
	parseJSONResponse(t, rec, &errResp)
	assert.Equal(t, "raw_text", errResp.Field)

	aisles := make([]map[string]any, 201)
	for i := range aisles {
		aisles[i] = map[string]any{
			"canonical_item_id": uuid.New().String(),
			"aisle":             "dry goods",
			"sort_order":        i,
		}
	}
	rec = execRequest(t, router, "PATCH", "/groups/"+group.ID.String()+"/grocery/aisles", map[string]any{
		"aisles": aisles,
	}, token)
	requireStatus(t, rec, http.StatusBadRequest)
	parseJSONResponse(t, rec, &errResp)
	assert.Equal(t, "aisles", errResp.Field)
}

func createGroceryTestGroup(t *testing.T, userID uuid.UUID, name string) *models.Group {
	t.Helper()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      name,
		CreatedBy: userID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, newTestGroupRepo().CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, userID, "admin")
	return group
}

func insertGroceryCanonicalItem(t *testing.T, groupID, canonicalID uuid.UUID, name string) {
	t.Helper()
	now := time.Now().UTC()
	_, err := testDB.Exec(context.Background(), `
		INSERT INTO canonical_items (id, group_id, name_de, name_en, category, default_unit, is_global, version, created_at, updated_at)
		VALUES ($1, $2, $3, $3, 'dairy', 'l', false, 0, $4, $4)`,
		canonicalID, groupID, name, now)
	require.NoError(t, err)
}
