package models

import (
	"time"

	"github.com/google/uuid"
)

// Recipe visibility values. A recipe is always readable by its owner; these
// say who else can see it. There is deliberately no server-wide "public" —
// see migration 000058.
const (
	// RecipeVisibilityPrivate is owner-only, plus anyone in recipe_shares.
	RecipeVisibilityPrivate = "private"
	// RecipeVisibilityHousehold is readable by every member of GroupID.
	RecipeVisibilityHousehold = "household"
)

// Recipe represents a user's recipe.
type Recipe struct {
	ID     uuid.UUID `json:"id"`
	UserID uuid.UUID `json:"user_id"`
	// GroupID is the household this recipe is shared with. Nil when the
	// recipe is private, or when the household it belonged to was deleted —
	// in which case Visibility may still read "household" but nobody but the
	// owner can see it. Readers must check both fields, never Visibility alone.
	GroupID          *uuid.UUID `json:"group_id,omitempty"`
	Visibility       string     `json:"visibility"`
	Title            string     `json:"title"`
	Description      string     `json:"description"`
	DescriptionShort string     `json:"description_short"`
	Author           string     `json:"author"`
	RatingValue      float64    `json:"rating_value"`
	RatingCount      int        `json:"rating_count"`
	NutritionJSON    string     `json:"nutrition_json"`
	VideoURL         string     `json:"video_url"`
	EquipmentJSON    string     `json:"equipment_json"`
	SourceURL        string     `json:"source_url"`
	ImageURL         string     `json:"image_url"`
	ImageOptions     []string   `json:"image_options"`
	Tags             []string   `json:"tags"`
	PrepTime         int        `json:"prep_time"`
	CookTime         int        `json:"cook_time"`
	Servings         int        `json:"servings"`
	CreatedAt        time.Time  `json:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// SharedWithHousehold reports whether this recipe is readable by members of a
// household. It is false for a household recipe whose group has been deleted,
// so callers cannot accidentally treat an orphan as shared.
func (r *Recipe) SharedWithHousehold() bool {
	return r.Visibility == RecipeVisibilityHousehold && r.GroupID != nil
}

// RecipeTagCount is one entry in the tag filter bar: a tag and how many of the
// recipes in scope carry it.
type RecipeTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// RecipeIngredient is an ingredient in a recipe.
type RecipeIngredient struct {
	ID       uuid.UUID `json:"id"`
	RecipeID uuid.UUID `json:"recipe_id"`
	Name     string    `json:"name"`
	Quantity string    `json:"quantity"`
	Unit     string    `json:"unit"`
	RawText  string    `json:"raw_text"`
	Position int       `json:"position"`
}

// RecipeStep is a step in a recipe.
type RecipeStep struct {
	ID          uuid.UUID `json:"id"`
	RecipeID    uuid.UUID `json:"recipe_id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Position    int       `json:"position"`
}

// RecipeShare represents a recipe shared with another user.
type RecipeShare struct {
	ID               uuid.UUID `json:"id"`
	RecipeID         uuid.UUID `json:"recipe_id"`
	SharedWithUserID uuid.UUID `json:"shared_with_user_id"`
	Permission       string    `json:"permission"`
	CreatedAt        time.Time `json:"created_at"`
}

// Collection is a recipe collection — a "cookbook" in the UI.
type Collection struct {
	ID     uuid.UUID `json:"id"`
	UserID uuid.UUID `json:"user_id"`
	// GroupID is nil for a personal cookbook, or the household every member
	// can read and add to.
	GroupID *uuid.UUID `json:"group_id,omitempty"`
	Name    string     `json:"name"`
	// RecipeCount is derived, not stored. The client has always parsed it;
	// until 000058 the server never sent it, so every cookbook read "No recipes".
	RecipeCount int       `json:"recipe_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// CollectionRecipe links a recipe to a collection.
type CollectionRecipe struct {
	ID           uuid.UUID `json:"id"`
	CollectionID uuid.UUID `json:"collection_id"`
	RecipeID     uuid.UUID `json:"recipe_id"`
	AddedAt      time.Time `json:"added_at"`
}

// MealPlan represents a planned meal for a specific date and slot.
type MealPlan struct {
	ID         uuid.UUID  `json:"id"`
	GroupID    uuid.UUID  `json:"group_id"`
	Date       time.Time  `json:"date"`
	Slot       string     `json:"slot"`
	RecipeID   uuid.UUID  `json:"recipe_id"`
	Servings   int        `json:"servings"`
	CookUserID *uuid.UUID `json:"cook_user_id,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}
