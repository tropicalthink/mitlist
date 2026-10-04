package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

type widgetGroupsFake struct {
	groups   []models.Group
	profiles map[uuid.UUID][]models.GroupMemberProfile
}

func (f *widgetGroupsFake) ListGroups(context.Context, uuid.UUID, int, int) ([]models.Group, error) {
	return append([]models.Group(nil), f.groups...), nil
}

func (f *widgetGroupsFake) ListMemberProfiles(_ context.Context, _ uuid.UUID, groupID uuid.UUID, includeFormer bool) ([]models.GroupMemberProfile, error) {
	if !includeFormer {
		return nil, errors.New("widget snapshot must include former members")
	}
	return f.profiles[groupID], nil
}

type widgetListsFake struct {
	lists map[uuid.UUID][]models.List
	items map[uuid.UUID][]models.ListItem
	err   error
}

func (f *widgetListsFake) ListLists(_ context.Context, _ *models.User, groupID uuid.UUID, limit, _ int) ([]models.List, error) {
	if f.err != nil {
		return nil, f.err
	}
	lists := f.lists[groupID]
	if len(lists) > limit {
		lists = lists[:limit]
	}
	return lists, nil
}

func (f *widgetListsFake) ListItems(_ context.Context, _ *models.User, listID uuid.UUID, _, _ int) ([]models.ListItem, error) {
	return f.items[listID], nil
}

type widgetChoresFake struct {
	current map[uuid.UUID][]models.CurrentChore
}

func (f *widgetChoresFake) ListCurrentChores(_ context.Context, _ *models.User, groupID uuid.UUID, _, _, dueSoonDays int) ([]models.CurrentChore, error) {
	if dueSoonDays != 1 {
		return nil, fmt.Errorf("dueSoonDays = %d, want 1", dueSoonDays)
	}
	return f.current[groupID], nil
}

func TestWidgetSnapshotBuildsHouseholds(t *testing.T) {
	me := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	sam, alex := uuid.New(), uuid.New()
	home := models.Group{ID: uuid.New(), Name: "Flat 3B"}
	todo := models.List{ID: uuid.New(), GroupID: home.ID, Name: "Errands", Type: "todo"}
	groceries := models.List{ID: uuid.New(), GroupID: home.ID, Name: "Groceries", Type: "shopping"}

	items := make([]models.ListItem, 0, 40)
	for i := 0; i < 35; i++ {
		items = append(items, models.ListItem{ID: uuid.New(), ListID: groceries.ID, Name: fmt.Sprintf("item %d", i), Position: i, AddedBy: &sam})
	}
	items = append(items, models.ListItem{ID: uuid.New(), ListID: groceries.ID, Name: "done", Checked: true})

	now := time.Date(2026, 10, 2, 9, 0, 0, 0, time.UTC)
	soon, later := now.Add(3*time.Hour), now.Add(6*time.Hour)
	overdue := now.Add(-24 * time.Hour)
	chores := []models.CurrentChore{
		{Chore: models.Chore{ID: uuid.New(), Name: "Later, theirs"}, DueStatus: "due_today",
			PendingAssignment: &models.ChoreAssignment{UserID: alex, DueDate: &later}},
		{Chore: models.Chore{ID: uuid.New(), Name: "Mine"}, DueStatus: "due_today", AssignedToMe: true,
			PendingAssignment: &models.ChoreAssignment{UserID: me.ID, DueDate: &later}, NextAssigneeUserID: &alex},
		{Chore: models.Chore{ID: uuid.New(), Name: "Overdue, theirs"}, DueStatus: "overdue",
			PendingAssignment: &models.ChoreAssignment{UserID: sam, DueDate: &overdue}},
		{Chore: models.Chore{ID: uuid.New(), Name: "Not due"}, DueStatus: "later",
			PendingAssignment: &models.ChoreAssignment{UserID: me.ID, DueDate: &soon}},
		{Chore: models.Chore{ID: uuid.New(), Name: "Unscheduled"}, DueStatus: "unscheduled"},
	}

	service := NewWidgetService(
		&widgetGroupsFake{
			groups: []models.Group{home},
			profiles: map[uuid.UUID][]models.GroupMemberProfile{home.ID: {
				{UserID: me.ID, DisplayName: "Me"}, {UserID: sam, DisplayName: "Sam"}, {UserID: alex, DisplayName: "Alex"},
			}},
		},
		&widgetListsFake{
			lists: map[uuid.UUID][]models.List{home.ID: {todo, groceries}},
			items: map[uuid.UUID][]models.ListItem{groceries.ID: items},
		},
		&widgetChoresFake{current: map[uuid.UUID][]models.CurrentChore{home.ID: chores}},
	)
	service.now = func() time.Time { return now }

	snapshot, err := service.GetSnapshot(context.Background(), me, nil)
	require.NoError(t, err)
	require.Equal(t, WidgetSnapshotVersion, snapshot.Version)
	require.Equal(t, "server", snapshot.Source)
	require.Equal(t, now, snapshot.GeneratedAt)
	require.Len(t, snapshot.Households, 1)

	household := snapshot.Households[0]
	require.Equal(t, "Flat 3B", household.Name)
	require.Len(t, household.Lists, 2)
	require.Empty(t, household.Lists[0].Items)
	shop := household.Lists[1]
	require.Equal(t, 35, shop.OpenCount, "open count covers items beyond the widget cap")
	require.Len(t, shop.Items, widgetMaxItemsPerList)
	require.Equal(t, "item 0", shop.Items[0].Name)
	require.Equal(t, "Sam", shop.Items[0].AddedByName)

	require.Equal(t, []string{"Mine", "Overdue, theirs", "Later, theirs"}, choreTitles(household.Chores))
	require.True(t, household.Chores[0].IsMine)
	require.Equal(t, "Alex", household.Chores[0].NextAssigneeName)
	require.Equal(t, "Sam", household.Chores[1].AssigneeName)

	require.Equal(t, home.ID, *snapshot.Defaults.HouseholdID)
	require.Equal(t, groceries.ID, *snapshot.Defaults.ListID, "default prefers a shopping list")

	// Field names are part of the contract with the app and the widgets.
	raw, err := json.Marshal(snapshot)
	require.NoError(t, err)
	var decoded map[string]any
	require.NoError(t, json.Unmarshal(raw, &decoded))
	for _, key := range []string{"version", "generated_at", "source", "user_id", "defaults", "households"} {
		require.Contains(t, decoded, key)
	}
}

func choreTitles(chores []WidgetChore) []string {
	out := make([]string, len(chores))
	for i, c := range chores {
		out[i] = c.Title
	}
	return out
}

func TestWidgetSnapshotKeepsToCredentialHouseholds(t *testing.T) {
	me := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	a, b := models.Group{ID: uuid.New(), Name: "A"}, models.Group{ID: uuid.New(), Name: "B"}
	service := NewWidgetService(
		&widgetGroupsFake{groups: []models.Group{a, b}},
		&widgetListsFake{},
		&widgetChoresFake{},
	)

	snapshot, err := service.GetSnapshot(context.Background(), me, []uuid.UUID{b.ID})
	require.NoError(t, err)
	require.Len(t, snapshot.Households, 1)
	require.Equal(t, b.ID, snapshot.Households[0].ID)
	require.Nil(t, snapshot.Defaults.ListID)

	// A credential issued before the person joined any household sees none,
	// rather than everything.
	snapshot, err = service.GetSnapshot(context.Background(), me, []uuid.UUID{})
	require.NoError(t, err)
	require.Empty(t, snapshot.Households)
	require.Nil(t, snapshot.Defaults.HouseholdID)
}

func TestWidgetSnapshotFailsWhenAHouseholdCannotBeRead(t *testing.T) {
	me := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	service := NewWidgetService(
		&widgetGroupsFake{groups: []models.Group{{ID: uuid.New()}}},
		&widgetListsFake{err: &api.PermissionDeniedError{Message: "not a member"}},
		&widgetChoresFake{},
	)
	_, err := service.GetSnapshot(context.Background(), me, nil)
	require.Error(t, err)
}

// widgetCredentialRepoFake records what the service stores.
type widgetCredentialRepoFake struct {
	repositories.IntegrationCredentialRepo
	replaced      *models.IntegrationCredential
	replacedHash  string
	revokedDevice string
}

func (f *widgetCredentialRepoFake) ReplaceWidgetCredential(_ context.Context, c *models.IntegrationCredential, hash string) error {
	f.replaced, f.replacedHash = c, hash
	return nil
}

func (f *widgetCredentialRepoFake) RevokeWidgetCredential(_ context.Context, _ uuid.UUID, deviceID string) error {
	f.revokedDevice = deviceID
	return nil
}

func TestIssueWidgetCredentialCoversCurrentHouseholds(t *testing.T) {
	userID := uuid.New()
	a, b := models.Group{ID: uuid.New()}, models.Group{ID: uuid.New()}
	groups := new(mocks.MockGroupRepo)
	groups.On("ListGroupsByUser", mock.Anything, userID, maxWidgetCredentialGroups, 0).Return([]models.Group{a, b}, nil)
	repo := &widgetCredentialRepoFake{}
	service := NewIntegrationCredentialService(repo, groups)

	credential, token, err := service.IssueWidgetCredential(context.Background(), userID, "  install-7f3a9c  ")
	require.NoError(t, err)
	require.Same(t, repo.replaced, credential)
	require.Equal(t, HashIntegrationToken(token), repo.replacedHash)
	require.Greater(t, len(token), len(IntegrationTokenPrefix)+40)
	require.Equal(t, IntegrationTokenPrefix, token[:len(IntegrationTokenPrefix)])
	require.Equal(t, CredentialKindWidget, credential.Kind)
	require.Equal(t, "install-7f3a9c", credential.DeviceID)
	require.Equal(t, []uuid.UUID{a.ID, b.ID}, credential.GroupIDs)
	require.Equal(t, []string{"widget:write", "lists:write", "chores:write"}, credential.Scopes)
	require.NotNil(t, credential.ExpiresAt)
	require.WithinDuration(t, time.Now().Add(WidgetCredentialLifetime), *credential.ExpiresAt, time.Minute)
	require.True(t, credential.CreatedAt.IsZero(), "the database stamps created_at")

	require.NoError(t, service.RevokeWidgetCredential(context.Background(), userID, "install-7f3a9c"))
	require.Equal(t, "install-7f3a9c", repo.revokedDevice)
}

func TestWidgetDeviceIDValidation(t *testing.T) {
	service := NewIntegrationCredentialService(&widgetCredentialRepoFake{}, new(mocks.MockGroupRepo))
	for _, deviceID := range []string{"", "short", "has space in it", "slash/es-12345", string(make([]byte, 129))} {
		_, _, err := service.IssueWidgetCredential(context.Background(), uuid.New(), deviceID)
		var validation *api.ValidationError
		require.ErrorAs(t, err, &validation, "device id %q", deviceID)
		require.ErrorAs(t, service.RevokeWidgetCredential(context.Background(), uuid.New(), deviceID), &validation)
	}
}

type widgetMealsFake struct {
	plans []models.MealPlan
	from  time.Time
}

func (f *widgetMealsFake) ListMealPlans(_ context.Context, _ *models.User, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error) {
	if !from.Equal(to) {
		return nil, fmt.Errorf("want a single day, got %s..%s", from, to)
	}
	f.from = from
	var out []models.MealPlan
	for _, p := range f.plans {
		if p.GroupID == groupID {
			out = append(out, p)
		}
	}
	return out, nil
}

type widgetRecipesFake map[uuid.UUID]*models.Recipe

func (f widgetRecipesFake) GetRecipesByIDs(_ context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
	out := map[uuid.UUID]*models.Recipe{}
	for _, id := range ids {
		if r, ok := f[id]; ok {
			out[id] = r
		}
	}
	return out, nil
}

type widgetFinanceFake map[uuid.UUID]*models.FinanceSummary

func (f widgetFinanceFake) GetFinanceSummary(_ context.Context, _ uuid.UUID, groupID uuid.UUID) (*models.FinanceSummary, error) {
	return f[groupID], nil
}

func TestWidgetSnapshotHouseholdToday(t *testing.T) {
	me := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	sam, alex := uuid.New(), uuid.New()
	home := models.Group{ID: uuid.New(), Name: "Flat 3B", Currency: "EUR"}
	quiet := models.Group{ID: uuid.New(), Name: "Quiet", Currency: "GBP"}
	lunch, dinner := uuid.New(), uuid.New()

	meals := &widgetMealsFake{plans: []models.MealPlan{
		{GroupID: home.ID, Slot: "dinner", RecipeID: dinner},
		{GroupID: home.ID, Slot: "lunch", RecipeID: lunch},
	}}
	svc := NewWidgetService(
		&widgetGroupsFake{groups: []models.Group{home, quiet}, profiles: map[uuid.UUID][]models.GroupMemberProfile{
			home.ID: {{UserID: sam, DisplayName: "Sam"}, {UserID: alex, DisplayName: "Alex"}},
		}},
		&widgetListsFake{},
		&widgetChoresFake{},
	).WithHouseholdToday(meals,
		widgetRecipesFake{dinner: {Title: "Lasagne"}, lunch: {Title: "Soup"}},
		widgetFinanceFake{home.ID: {
			Balances: []models.BalanceEntry{{UserID: me.ID, Total: -1700}, {UserID: sam, Total: 1200}, {UserID: alex, Total: 500}},
			Reimbursements: []models.ReimbursementSuggestion{
				{FromUserID: me.ID, ToUserID: alex, ToDisplayName: "stale", Amount: 500},
				{FromUserID: me.ID, ToUserID: sam, ToDisplayName: "stale", Amount: 1200},
			},
		}},
	)
	svc.now = func() time.Time { return time.Date(2026, 10, 2, 21, 30, 0, 0, time.FixedZone("CEST", 2*3600)) }

	snap, err := svc.GetSnapshot(context.Background(), me, nil)
	require.NoError(t, err)
	require.Equal(t, time.Date(2026, 10, 2, 0, 0, 0, 0, time.UTC), meals.from, "today is the server's UTC date")

	got := snap.Households[0]
	require.Equal(t, &WidgetMeal{Title: "Lasagne", Slot: "dinner", RecipeID: dinner}, got.TonightMeal)
	require.Equal(t, &WidgetBalance{Currency: "EUR", NetCents: -1700, SettleWithName: "Sam", SettleCents: 1200}, got.Balance)

	// No plans and no money activity: both fields are left out.
	require.Nil(t, snap.Households[1].TonightMeal)
	require.Nil(t, snap.Households[1].Balance)
}

func TestWidgetSnapshotMealFallsBackToLastSlot(t *testing.T) {
	me := &models.User{ID: uuid.New()}
	home := models.Group{ID: uuid.New(), Name: "Home"}
	breakfast, lunch, gone := uuid.New(), uuid.New(), uuid.New()
	svc := NewWidgetService(&widgetGroupsFake{groups: []models.Group{home}}, &widgetListsFake{}, &widgetChoresFake{}).
		WithHouseholdToday(&widgetMealsFake{plans: []models.MealPlan{
			{GroupID: home.ID, Slot: "breakfast", RecipeID: breakfast}, {GroupID: home.ID, Slot: "lunch", RecipeID: lunch},
		}}, widgetRecipesFake{breakfast: {Title: "Porridge"}, lunch: {Title: "Soup"}}, widgetFinanceFake{})

	snap, err := svc.GetSnapshot(context.Background(), me, nil)
	require.NoError(t, err)
	require.Equal(t, "Soup", snap.Households[0].TonightMeal.Title)

	// A plan whose recipe was deleted shows nothing rather than "Meal".
	svc.WithHouseholdToday(&widgetMealsFake{plans: []models.MealPlan{{GroupID: home.ID, Slot: "dinner", RecipeID: gone}}}, widgetRecipesFake{}, widgetFinanceFake{})
	snap, err = svc.GetSnapshot(context.Background(), me, nil)
	require.NoError(t, err)
	require.Nil(t, snap.Households[0].TonightMeal)
}

// TestWidgetSnapshotMatchesGoldenFixture keeps the server's JSON and the
// shared fixture (read by the Dart, Kotlin and Swift suites) in step: every
// key the server can emit is in the fixture and vice versa.
func TestWidgetSnapshotMatchesGoldenFixture(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("..", "..", "..", "contracts", "widgets", "snapshot_v1.json"))
	require.NoError(t, err)
	var fixture any
	require.NoError(t, json.Unmarshal(raw, &fixture))

	due := time.Now()
	id := uuid.New()
	full := WidgetSnapshot{
		Version: WidgetSnapshotVersion, Source: "server",
		Defaults: WidgetDefaults{HouseholdID: &id, ListID: &id},
		Households: []WidgetHousehold{{
			Lists:       []WidgetList{{Items: []WidgetListItem{{Quantity: 1, Unit: "l", AddedByName: "Sam"}}}},
			Chores:      []WidgetChore{{DueAt: &due, AssigneeName: "Jo", NextAssigneeName: "Alex"}},
			TonightMeal: &WidgetMeal{Title: "Lasagne"},
			Balance:     &WidgetBalance{SettleWithName: "Sam", SettleCents: 1},
		}},
	}
	encoded, err := json.Marshal(full)
	require.NoError(t, err)
	var server any
	require.NoError(t, json.Unmarshal(encoded, &server))

	require.Equal(t, jsonKeyPaths(fixture, ""), jsonKeyPaths(server, ""))
	require.EqualValues(t, WidgetSnapshotVersion, fixture.(map[string]any)["version"])
}

// jsonKeyPaths lists every object key path in v; array elements share the
// path "[]", so the result is the schema, not the data.
func jsonKeyPaths(v any, prefix string) []string {
	set := map[string]struct{}{}
	var walk func(v any, prefix string)
	walk = func(v any, prefix string) {
		switch typed := v.(type) {
		case map[string]any:
			for key, child := range typed {
				path := prefix + "." + key
				set[path] = struct{}{}
				walk(child, path)
			}
		case []any:
			for _, child := range typed {
				walk(child, prefix+"[]")
			}
		}
	}
	walk(v, prefix)
	paths := make([]string, 0, len(set))
	for path := range set {
		paths = append(paths, path)
	}
	sort.Strings(paths)
	return paths
}

func TestWidgetSnapshotTimesAreWholeSecondUTC(t *testing.T) {
	me := &models.User{ID: uuid.New()}
	home := models.Group{ID: uuid.New(), Name: "Home"}
	berlin := time.FixedZone("CEST", 2*3600)
	due := time.Date(2026, 10, 3, 23, 57, 45, 643731000, berlin)
	svc := NewWidgetService(&widgetGroupsFake{groups: []models.Group{home}}, &widgetListsFake{},
		&widgetChoresFake{current: map[uuid.UUID][]models.CurrentChore{home.ID: {{
			Chore: models.Chore{ID: uuid.New(), Name: "Bins"}, DueStatus: "due_soon",
			PendingAssignment: &models.ChoreAssignment{UserID: me.ID, DueDate: &due},
		}}}})
	svc.now = func() time.Time { return time.Date(2026, 10, 2, 23, 57, 34, 794763000, berlin) }

	snap, err := svc.GetSnapshot(context.Background(), me, nil)
	require.NoError(t, err)
	encoded, err := json.Marshal(snap)
	require.NoError(t, err)
	require.Contains(t, string(encoded), `"generated_at":"2026-10-02T21:57:34Z"`)
	require.Contains(t, string(encoded), `"due_at":"2026-10-03T21:57:45Z"`)
}
