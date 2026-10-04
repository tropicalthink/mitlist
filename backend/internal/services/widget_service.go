package services

import (
	"context"
	"sort"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// WidgetSnapshotVersion is the schema version of WidgetSnapshot. Readers
// ignore unknown fields; the version only changes for breaking changes
// (plans/047, contract C1; golden fixture contracts/widgets/snapshot_v1.json).
const WidgetSnapshotVersion = 1

const (
	widgetMaxHouseholds   = 20
	widgetMaxLists        = 12
	widgetMaxItemsPerList = 30
	widgetItemFetchLimit  = 500
	widgetMaxChores       = 20
	widgetChoreFetchLimit = 200
)

// WidgetSnapshot is everything the home screen widgets render, for every
// household the caller may see. Widgets keep the last one on disk and draw
// from it, so it stays small: open items only, a few lists, due chores only.
type WidgetSnapshot struct {
	Version     int               `json:"version"`
	GeneratedAt time.Time         `json:"generated_at"`
	Source      string            `json:"source"`
	UserID      uuid.UUID         `json:"user_id"`
	Defaults    WidgetDefaults    `json:"defaults"`
	Households  []WidgetHousehold `json:"households"`
}

// WidgetDefaults is what an unconfigured widget shows.
type WidgetDefaults struct {
	HouseholdID *uuid.UUID `json:"household_id,omitempty"`
	ListID      *uuid.UUID `json:"list_id,omitempty"`
}

type WidgetHousehold struct {
	ID          uuid.UUID      `json:"id"`
	Name        string         `json:"name"`
	Lists       []WidgetList   `json:"lists"`
	Chores      []WidgetChore  `json:"chores"`
	TonightMeal *WidgetMeal    `json:"tonight_meal,omitempty"`
	Balance     *WidgetBalance `json:"balance,omitempty"`
}

// WidgetMeal is what the household plans to eat today: dinner when planned,
// otherwise the last planned slot of the day. "Today" is the server's UTC
// date.
type WidgetMeal struct {
	Title    string    `json:"title"`
	Slot     string    `json:"slot"`
	RecipeID uuid.UUID `json:"recipe_id"`
}

// WidgetBalance is the caller's position in the household's base currency.
// NetCents > 0: the others owe the caller; < 0: the caller owes. The settle
// fields name the largest suggested settlement involving the caller and are
// omitted when there is none.
type WidgetBalance struct {
	Currency       string `json:"currency"`
	NetCents       int64  `json:"net_cents"`
	SettleWithName string `json:"settle_with_name,omitempty"`
	SettleCents    int64  `json:"settle_cents,omitempty"`
}

type WidgetList struct {
	ID        uuid.UUID        `json:"id"`
	Name      string           `json:"name"`
	Type      string           `json:"type"`
	OpenCount int              `json:"open_count"`
	Items     []WidgetListItem `json:"items"`
}

type WidgetListItem struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Quantity    float64   `json:"quantity,omitempty"`
	Unit        string    `json:"unit,omitempty"`
	AddedByName string    `json:"added_by_name,omitempty"`
}

// WidgetChore is a chore whose turn is open now or soon. DueAt is the
// instant; widgets decide "today" in the device's own time zone.
type WidgetChore struct {
	ID               uuid.UUID  `json:"id"`
	Title            string     `json:"title"`
	DueAt            *time.Time `json:"due_at,omitempty"`
	DueStatus        string     `json:"due_status"`
	IsMine           bool       `json:"is_mine"`
	AssigneeName     string     `json:"assignee_name,omitempty"`
	NextAssigneeName string     `json:"next_assignee_name,omitempty"`
}

type widgetGroupReader interface {
	ListGroups(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Group, error)
	ListMemberProfiles(ctx context.Context, userID, groupID uuid.UUID, includeFormer bool) ([]models.GroupMemberProfile, error)
}

type widgetListReader interface {
	ListLists(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.List, error)
	ListItems(ctx context.Context, user *models.User, listID uuid.UUID, limit, offset int) ([]models.ListItem, error)
}

type widgetChoreReader interface {
	ListCurrentChores(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset, dueSoonDays int) ([]models.CurrentChore, error)
}

type widgetMealReader interface {
	ListMealPlans(ctx context.Context, user *models.User, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error)
}

// widgetRecipeTitles resolves the titles of recipes the household planned;
// the meal plans were already read through a membership check.
type widgetRecipeTitles interface {
	GetRecipesByIDs(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.Recipe, error)
}

type widgetFinanceReader interface {
	GetFinanceSummary(ctx context.Context, userID, groupID uuid.UUID) (*models.FinanceSummary, error)
}

// WidgetService builds the widget snapshot from the feature services, so
// their membership and account checks apply unchanged.
type WidgetService struct {
	groups  widgetGroupReader
	lists   widgetListReader
	chores  widgetChoreReader
	meals   widgetMealReader
	recipes widgetRecipeTitles
	finance widgetFinanceReader
	now     func() time.Time
}

func NewWidgetService(groups widgetGroupReader, lists widgetListReader, chores widgetChoreReader) *WidgetService {
	return &WidgetService{groups: groups, lists: lists, chores: chores, now: time.Now}
}

// WithHouseholdToday adds tonight's meal and the caller's balance to every
// household, for the household-today and balance widgets. Without it those
// optional fields are left out.
func (s *WidgetService) WithHouseholdToday(meals widgetMealReader, recipes widgetRecipeTitles, finance widgetFinanceReader) *WidgetService {
	s.meals, s.recipes, s.finance = meals, recipes, finance
	return s
}

// GetSnapshot returns the snapshot for user. allowedGroups, when non-nil,
// limits it to those households (a credential's scope); nil means every
// household the user belongs to.
func (s *WidgetService) GetSnapshot(ctx context.Context, user *models.User, allowedGroups []uuid.UUID) (*WidgetSnapshot, error) {
	groups, err := s.groups.ListGroups(ctx, user.ID, widgetMaxHouseholds, 0)
	if err != nil {
		return nil, err
	}
	if allowedGroups != nil {
		allowed := make(map[uuid.UUID]struct{}, len(allowedGroups))
		for _, id := range allowedGroups {
			allowed[id] = struct{}{}
		}
		kept := groups[:0]
		for _, g := range groups {
			if _, ok := allowed[g.ID]; ok {
				kept = append(kept, g)
			}
		}
		groups = kept
	}

	snapshot := &WidgetSnapshot{
		Version:     WidgetSnapshotVersion,
		GeneratedAt: widgetTime(s.now()),
		Source:      "server",
		UserID:      user.ID,
		Households:  make([]WidgetHousehold, 0, len(groups)),
	}
	for _, group := range groups {
		household, err := s.household(ctx, user, group)
		if err != nil {
			return nil, err
		}
		snapshot.Households = append(snapshot.Households, *household)
	}
	snapshot.Defaults = widgetDefaults(snapshot.Households)
	return snapshot, nil
}

func (s *WidgetService) household(ctx context.Context, user *models.User, group models.Group) (*WidgetHousehold, error) {
	// Former members stay in the roster so "added by" keeps resolving.
	profiles, err := s.groups.ListMemberProfiles(ctx, user.ID, group.ID, true)
	if err != nil {
		return nil, err
	}
	names := make(map[uuid.UUID]string, len(profiles))
	for _, p := range profiles {
		names[p.UserID] = p.DisplayName
	}

	lists, err := s.lists.ListLists(ctx, user, group.ID, widgetMaxLists, 0)
	if err != nil {
		return nil, err
	}
	household := &WidgetHousehold{
		ID: group.ID, Name: group.Name,
		Lists:  make([]WidgetList, 0, len(lists)),
		Chores: []WidgetChore{},
	}
	for _, list := range lists {
		items, err := s.lists.ListItems(ctx, user, list.ID, widgetItemFetchLimit, 0)
		if err != nil {
			return nil, err
		}
		household.Lists = append(household.Lists, widgetList(list, items, names))
	}

	current, err := s.chores.ListCurrentChores(ctx, user, group.ID, widgetChoreFetchLimit, 0, 1)
	if err != nil {
		return nil, err
	}
	household.Chores = widgetChores(current, names)

	if s.meals != nil {
		meal, err := s.tonightMeal(ctx, user, group.ID)
		if err != nil {
			return nil, err
		}
		household.TonightMeal = meal
	}
	if s.finance != nil {
		summary, err := s.finance.GetFinanceSummary(ctx, user.ID, group.ID)
		if err != nil {
			return nil, err
		}
		household.Balance = widgetBalance(summary, user.ID, group.Currency, names)
	}
	return household, nil
}

func (s *WidgetService) tonightMeal(ctx context.Context, user *models.User, groupID uuid.UUID) (*WidgetMeal, error) {
	now := s.now().UTC()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	plans, err := s.meals.ListMealPlans(ctx, user, groupID, today, today)
	if err != nil || len(plans) == 0 {
		return nil, err
	}
	chosen := plans[len(plans)-1]
	for _, p := range plans {
		if p.Slot == "dinner" {
			chosen = p
			break
		}
	}
	meal := &WidgetMeal{Slot: chosen.Slot, RecipeID: chosen.RecipeID}
	if s.recipes != nil {
		recipes, err := s.recipes.GetRecipesByIDs(ctx, []uuid.UUID{chosen.RecipeID})
		if err != nil {
			return nil, err
		}
		if recipe := recipes[chosen.RecipeID]; recipe != nil {
			meal.Title = recipe.Title
		}
	}
	if meal.Title == "" {
		// A plan whose recipe is gone has nothing worth showing.
		return nil, nil
	}
	return meal, nil
}

// widgetBalance reads the caller's net position and largest suggested
// settlement from the household's finance summary. Nil when the household
// has no money activity at all.
func widgetBalance(summary *models.FinanceSummary, userID uuid.UUID, currency string, names map[uuid.UUID]string) *WidgetBalance {
	if summary == nil || len(summary.Balances) == 0 {
		return nil
	}
	balance := &WidgetBalance{Currency: currency}
	for _, entry := range summary.Balances {
		if entry.UserID == userID {
			balance.NetCents = entry.Total
		}
	}
	for _, r := range summary.Reimbursements {
		var other uuid.UUID
		var otherName string
		switch userID {
		case r.FromUserID:
			other, otherName = r.ToUserID, r.ToDisplayName
		case r.ToUserID:
			other, otherName = r.FromUserID, r.FromDisplayName
		default:
			continue
		}
		if r.Amount <= balance.SettleCents {
			continue
		}
		if name := names[other]; name != "" {
			otherName = name
		}
		balance.SettleWithName, balance.SettleCents = otherName, r.Amount
	}
	return balance
}

// widgetList keeps the open items in list order. OpenCount counts every open
// item fetched, not only the ones that fit in the widget.
func widgetList(list models.List, items []models.ListItem, names map[uuid.UUID]string) WidgetList {
	out := WidgetList{ID: list.ID, Name: list.Name, Type: list.Type, Items: []WidgetListItem{}}
	for _, item := range items {
		if item.Checked {
			continue
		}
		out.OpenCount++
		if len(out.Items) >= widgetMaxItemsPerList {
			continue
		}
		entry := WidgetListItem{ID: item.ID, Name: item.Name, Quantity: item.Quantity, Unit: item.Unit}
		if item.AddedBy != nil {
			entry.AddedByName = names[*item.AddedBy]
		}
		out.Items = append(out.Items, entry)
	}
	return out
}

// widgetChores keeps overdue chores and those due within about a day, mine
// first, then by due time.
func widgetChores(current []models.CurrentChore, names map[uuid.UUID]string) []WidgetChore {
	out := make([]WidgetChore, 0, len(current))
	for _, c := range current {
		switch c.DueStatus {
		case "overdue", "due_today", "due_soon":
		default:
			continue
		}
		chore := WidgetChore{ID: c.Chore.ID, Title: c.Chore.Name, DueStatus: c.DueStatus, IsMine: c.AssignedToMe}
		if c.PendingAssignment != nil {
			if c.PendingAssignment.DueDate != nil {
				due := widgetTime(*c.PendingAssignment.DueDate)
				chore.DueAt = &due
			}
			chore.AssigneeName = names[c.PendingAssignment.UserID]
		}
		if c.NextAssigneeUserID != nil {
			chore.NextAssigneeName = names[*c.NextAssigneeUserID]
		}
		out = append(out, chore)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].IsMine != out[j].IsMine {
			return out[i].IsMine
		}
		a, b := out[i].DueAt, out[j].DueAt
		if a == nil || b == nil {
			return a != nil
		}
		return a.Before(*b)
	})
	if len(out) > widgetMaxChores {
		out = out[:widgetMaxChores]
	}
	return out
}

// widgetTime is how the snapshot writes instants: UTC, whole seconds
// ("2026-10-02T09:00:00Z"), which every widget platform's ISO 8601 parser
// reads. The database hands back microseconds in the server's zone.
func widgetTime(t time.Time) time.Time {
	return t.UTC().Truncate(time.Second)
}

// widgetDefaults points an unconfigured widget at the first household and
// its first shopping list, or its first list when it has no shopping list.
func widgetDefaults(households []WidgetHousehold) WidgetDefaults {
	if len(households) == 0 {
		return WidgetDefaults{}
	}
	household := households[0]
	defaults := WidgetDefaults{HouseholdID: &household.ID}
	for i := range household.Lists {
		if household.Lists[i].Type == "shopping" {
			defaults.ListID = &household.Lists[i].ID
			return defaults
		}
	}
	if len(household.Lists) > 0 {
		defaults.ListID = &household.Lists[0].ID
	}
	return defaults
}
