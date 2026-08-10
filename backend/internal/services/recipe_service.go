package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

// RecipeService implements business logic for recipes and collections with
// ownership enforcement.
type RecipeService struct {
	recipeRepo repositories.RecipeRepoIface
}

// NewRecipeService creates a new RecipeService.
func NewRecipeService(recipeRepo repositories.RecipeRepoIface) *RecipeService {
	return &RecipeService{recipeRepo: recipeRepo}
}

func (s *RecipeService) requireOwner(recipe *models.Recipe, userID uuid.UUID) error {
	if recipe.UserID != userID {
		return &api.PermissionDeniedError{Action: "modify recipe"}
	}
	return nil
}

func (s *RecipeService) requireCollectionOwner(collection *models.Collection, userID uuid.UUID) error {
	if collection.UserID != userID {
		return &api.PermissionDeniedError{Action: "modify collection"}
	}
	return nil
}

// ------------------------------------------------------------------
// Recipes
// ------------------------------------------------------------------

// CreateRecipe creates a new recipe owned by the user.
func (s *RecipeService) CreateRecipe(ctx context.Context, userID uuid.UUID, recipe *models.Recipe) error {
	recipe.UserID = userID
	if recipe.Title == "" {
		return api.ErrValidation
	}
	return s.recipeRepo.CreateRecipe(ctx, recipe)
}

// GetRecipe returns a recipe if the user owns it, it's public, or shared.
func (s *RecipeService) GetRecipe(ctx context.Context, userID, recipeID uuid.UUID) (*models.Recipe, error) {
	recipe, err := s.recipeRepo.GetRecipeByID(ctx, recipeID)
	if err != nil {
		if err.Error() == "recipe not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if recipe.UserID == userID {
		return recipe, nil
	}
	if recipe.IsPublic {
		return recipe, nil
	}
	_, err = s.recipeRepo.GetRecipeShareByUser(ctx, recipeID, userID)
	if err == nil {
		return recipe, nil
	}
	if err.Error() == "recipe share not found" {
		return nil, &api.PermissionDeniedError{Action: "view recipe"}
	}
	return nil, err
}

// ListRecipes returns recipes owned by the user.
func (s *RecipeService) ListRecipes(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	return s.recipeRepo.ListRecipesByUser(ctx, userID, limit, offset)
}

// CreateIngredient adds an ingredient to an existing recipe.
func (s *RecipeService) CreateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	return s.recipeRepo.CreateIngredient(ctx, ing)
}

// CreateStep adds a step to an existing recipe.
func (s *RecipeService) CreateStep(ctx context.Context, step *models.RecipeStep) error {
	return s.recipeRepo.CreateStep(ctx, step)
}

func (s *RecipeService) ListIngredientsForRecipe(ctx context.Context, userID, recipeID uuid.UUID) ([]models.RecipeIngredient, error) {
	if _, err := s.GetRecipe(ctx, userID, recipeID); err != nil {
		return nil, err
	}
	return s.recipeRepo.ListIngredients(ctx, recipeID)
}

func (s *RecipeService) ListStepsForRecipe(ctx context.Context, userID, recipeID uuid.UUID) ([]models.RecipeStep, error) {
	if _, err := s.GetRecipe(ctx, userID, recipeID); err != nil {
		return nil, err
	}
	return s.recipeRepo.ListSteps(ctx, recipeID)
}

// UpdateRecipe updates a recipe (owner only).
func (s *RecipeService) UpdateRecipe(ctx context.Context, userID uuid.UUID, recipe *models.Recipe) error {
	existing, err := s.recipeRepo.GetRecipeByID(ctx, recipe.ID)
	if err != nil {
		if err.Error() == "recipe not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireOwner(existing, userID); err != nil {
		return err
	}
	recipe.UserID = existing.UserID
	return s.recipeRepo.UpdateRecipe(ctx, recipe)
}

// DeleteRecipe removes a recipe (owner only).
func (s *RecipeService) DeleteRecipe(ctx context.Context, userID, recipeID uuid.UUID) error {
	existing, err := s.recipeRepo.GetRecipeByID(ctx, recipeID)
	if err != nil {
		if err.Error() == "recipe not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireOwner(existing, userID); err != nil {
		return err
	}
	return s.recipeRepo.DeleteRecipe(ctx, recipeID)
}

// ShareRecipe shares a recipe with another user (owner only).
func (s *RecipeService) ShareRecipe(ctx context.Context, userID, recipeID, sharedWithUserID uuid.UUID, permission string) error {
	recipe, err := s.recipeRepo.GetRecipeByID(ctx, recipeID)
	if err != nil {
		if err.Error() == "recipe not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireOwner(recipe, userID); err != nil {
		return err
	}
	if permission == "" {
		permission = "view"
	}
	share := &models.RecipeShare{
		RecipeID:         recipeID,
		SharedWithUserID: sharedWithUserID,
		Permission:       permission,
	}
	return s.recipeRepo.CreateRecipeShare(ctx, share)
}

// ------------------------------------------------------------------
// Collections
// ------------------------------------------------------------------

// CreateCollection creates a new collection.
func (s *RecipeService) CreateCollection(ctx context.Context, userID uuid.UUID, collection *models.Collection) error {
	collection.UserID = userID
	if collection.Name == "" {
		return api.ErrValidation
	}
	return s.recipeRepo.CreateCollection(ctx, collection)
}

// GetCollection returns a collection (owner only).
func (s *RecipeService) GetCollection(ctx context.Context, userID, collectionID uuid.UUID) (*models.Collection, error) {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireCollectionOwner(collection, userID); err != nil {
		return nil, err
	}
	return collection, nil
}

// ListCollections returns collections owned by the user.
func (s *RecipeService) ListCollections(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Collection, error) {
	return s.recipeRepo.ListCollections(ctx, userID, limit, offset)
}

// ListCollectionRecipes returns the recipes in a collection after verifying the
// caller owns it.
func (s *RecipeService) ListCollectionRecipes(ctx context.Context, userID, collectionID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireCollectionOwner(collection, userID); err != nil {
		return nil, err
	}
	return s.recipeRepo.ListRecipesByCollection(ctx, collectionID, limit, offset)
}

// UpdateCollection updates a collection (owner only).
func (s *RecipeService) UpdateCollection(ctx context.Context, userID uuid.UUID, collection *models.Collection) error {
	existing, err := s.recipeRepo.GetCollectionByID(ctx, collection.ID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionOwner(existing, userID); err != nil {
		return err
	}
	collection.UserID = existing.UserID
	return s.recipeRepo.UpdateCollection(ctx, collection)
}

// DeleteCollection removes a collection (owner only).
func (s *RecipeService) DeleteCollection(ctx context.Context, userID, collectionID uuid.UUID) error {
	existing, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionOwner(existing, userID); err != nil {
		return err
	}
	return s.recipeRepo.DeleteCollection(ctx, collectionID)
}

// AddToCollection adds a recipe to a collection (owner only).
func (s *RecipeService) AddToCollection(ctx context.Context, userID, collectionID, recipeID uuid.UUID) error {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionOwner(collection, userID); err != nil {
		return err
	}
	if _, err = s.GetRecipe(ctx, userID, recipeID); err != nil {
		return err
	}
	cr := &models.CollectionRecipe{
		CollectionID: collectionID,
		RecipeID:     recipeID,
	}
	return s.recipeRepo.CreateCollectionRecipe(ctx, cr)
}

// RemoveFromCollection removes a recipe from a collection (owner only).
func (s *RecipeService) RemoveFromCollection(ctx context.Context, userID, collectionID, recipeID uuid.UUID) error {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionOwner(collection, userID); err != nil {
		return err
	}
	return s.recipeRepo.DeleteCollectionRecipe(ctx, collectionID, recipeID)
}

// compile-time interface check helpers
var (
	_ = pgx.ErrNoRows
)
