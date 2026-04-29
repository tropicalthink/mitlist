package models

import (
	"time"

	"github.com/google/uuid"
)

// Recipe represents a user's recipe.
type Recipe struct {
	ID               uuid.UUID `json:"id"`
	UserID           uuid.UUID `json:"user_id"`
	Title            string    `json:"title"`
	Description      string    `json:"description"`
	DescriptionShort string    `json:"description_short"`
	Author           string    `json:"author"`
	RatingValue      float64   `json:"rating_value"`
	RatingCount      int       `json:"rating_count"`
	NutritionJSON    string    `json:"nutrition_json"`
	VideoURL         string    `json:"video_url"`
	EquipmentJSON    string    `json:"equipment_json"`
	SourceURL        string    `json:"source_url"`
	ImageURL         string    `json:"image_url"`
	ImageOptions     []string  `json:"image_options"`
	Tags             []string  `json:"tags"`
	PrepTime         int       `json:"prep_time"`
	CookTime         int       `json:"cook_time"`
	Servings         int       `json:"servings"`
	IsPublic         bool      `json:"is_public"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
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

// Collection is a recipe collection.
type Collection struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
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
