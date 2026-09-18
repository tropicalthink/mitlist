package services

import (
	"context"
	"errors"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

// RecipeService implements business logic for recipes and cookbooks.
//
// A recipe is always owned by one user. Beyond the owner it can be read by
// members of the household it is shared with (visibility "household") and by
// anyone holding an explicit recipe_shares row. There is no server-wide public
// recipe — see migration 000058.
type RecipeService struct {
	recipeRepo repositories.RecipeRepoIface
	groupRepo  GroupMembershipChecker
	userRepo   UserLookup
}

// UserLookup is the minimal user read a service needs to confirm someone
// exists before referencing them.
type UserLookup interface {
	GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
}

// NewRecipeService creates a new RecipeService.
func NewRecipeService(recipeRepo repositories.RecipeRepoIface, groupRepo GroupMembershipChecker, userRepo UserLookup) *RecipeService {
	return &RecipeService{recipeRepo: recipeRepo, groupRepo: groupRepo, userRepo: userRepo}
}

func (s *RecipeService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
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

// requireCollectionReader allows the owner, or any member of the household the
// cookbook is shared with. Renaming, deleting and re-sharing stay owner-only
// via requireCollectionOwner.
func (s *RecipeService) requireCollectionReader(ctx context.Context, collection *models.Collection, userID uuid.UUID) error {
	if collection.UserID == userID {
		return nil
	}
	if collection.GroupID != nil {
		return s.requireMembership(ctx, userID, *collection.GroupID)
	}
	return &api.PermissionDeniedError{Action: "view collection"}
}

// applyVisibility normalises and validates the requested visibility, and proves
// the user actually belongs to any household they are sharing into. Callers
// must run it before every create and update so a recipe can never name a
// household its owner has left.
func (s *RecipeService) applyVisibility(ctx context.Context, userID uuid.UUID, recipe *models.Recipe) error {
	switch recipe.Visibility {
	case "":
		recipe.Visibility = models.RecipeVisibilityPrivate
	case models.RecipeVisibilityPrivate, models.RecipeVisibilityHousehold:
	default:
		return &api.ValidationError{Field: "visibility", Message: "must be 'private' or 'household'"}
	}

	if recipe.Visibility == models.RecipeVisibilityPrivate {
		recipe.GroupID = nil
		return nil
	}
	if recipe.GroupID == nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required to share with a household"}
	}
	return s.requireMembership(ctx, userID, *recipe.GroupID)
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
	recipe.Tags = normalizeTags(recipe.Tags)
	if err := s.applyVisibility(ctx, userID, recipe); err != nil {
		return err
	}
	return s.recipeRepo.CreateRecipe(ctx, recipe)
}

// normalizeTags folds tags to trimmed lowercase and drops empties and
// duplicates. The tag filter is an exact jsonb containment match with the
// handler lowercasing the query, and the scraper already stores this shape;
// hand-entered tags have to land the same way or they can never be filtered.
func normalizeTags(tags []string) []string {
	seen := make(map[string]struct{}, len(tags))
	out := make([]string, 0, len(tags))
	for _, t := range tags {
		t = strings.ToLower(strings.TrimSpace(t))
		if t == "" {
			continue
		}
		if _, dup := seen[t]; dup {
			continue
		}
		seen[t] = struct{}{}
		out = append(out, t)
	}
	return out
}

// GetRecipe returns a recipe if the user owns it, is a member of the household
// it is shared with, or holds an explicit share.
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

	// SharedWithHousehold is false for a household recipe whose group has been
	// deleted, so an orphan stays owner-only instead of falling through as
	// readable. A non-member falls through to the explicit-share check below;
	// any other repo error aborts rather than being swallowed.
	if recipe.SharedWithHousehold() {
		err := s.requireMembership(ctx, userID, *recipe.GroupID)
		if err == nil {
			return recipe, nil
		}
		if !errors.Is(err, api.ErrPermissionDenied) {
			return nil, err
		}
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

// getRecipesForMember batches recipe enrichment for a composite household
// read whose caller has already proved membership in groupID. The repository
// still enforces owner, household-visibility, and explicit-share rules.
func (s *RecipeService) getRecipesForMember(ctx context.Context, userID, groupID uuid.UUID, recipeIDs []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
	return s.recipeRepo.GetReadableRecipesByIDs(ctx, recipeIDs, userID, groupID)
}

// ListRecipes returns the user's own recipes and, when filter.GroupID names a
// household they belong to, everything shared with that household.
func (s *RecipeService) ListRecipes(ctx context.Context, userID uuid.UUID, filter repositories.RecipeFilter) ([]models.Recipe, error) {
	if filter.GroupID != nil {
		if err := s.requireMembership(ctx, userID, *filter.GroupID); err != nil {
			return nil, err
		}
	}
	return s.recipeRepo.ListRecipes(ctx, userID, filter)
}

// ListTags returns the tags in use across the recipes the caller can see, so
// the client can render a filter bar over the whole library rather than over
// whichever page it happens to have loaded.
func (s *RecipeService) ListTags(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit int) ([]models.RecipeTagCount, error) {
	if groupID != nil {
		if err := s.requireMembership(ctx, userID, *groupID); err != nil {
			return nil, err
		}
	}
	return s.recipeRepo.ListDistinctTags(ctx, userID, groupID, limit)
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
	recipe.Tags = normalizeTags(recipe.Tags)
	if err := s.applyVisibility(ctx, userID, recipe); err != nil {
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
	// Confirm the recipient exists. Without this the endpoint happily stored a
	// share row for any UUID posted at it.
	if _, err := s.userRepo.GetByID(ctx, sharedWithUserID); err != nil {
		return &api.ValidationError{Field: "shared_with_user_id", Message: "unknown user"}
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

// CreateCollection creates a new cookbook. A group_id shares it with that
// household, which the caller must belong to.
func (s *RecipeService) CreateCollection(ctx context.Context, userID uuid.UUID, collection *models.Collection) error {
	collection.UserID = userID
	if collection.Name == "" {
		return api.ErrValidation
	}
	if collection.GroupID != nil {
		if err := s.requireMembership(ctx, userID, *collection.GroupID); err != nil {
			return err
		}
	}
	return s.recipeRepo.CreateCollection(ctx, collection)
}

// GetCollection returns a cookbook the caller owns or shares a household with.
func (s *RecipeService) GetCollection(ctx context.Context, userID, collectionID uuid.UUID) (*models.Collection, error) {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireCollectionReader(ctx, collection, userID); err != nil {
		return nil, err
	}
	return collection, nil
}

// ListCollections returns the user's own cookbooks plus, when groupID names a
// household they belong to, the ones shared with it.
func (s *RecipeService) ListCollections(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit, offset int) ([]models.Collection, error) {
	if groupID != nil {
		if err := s.requireMembership(ctx, userID, *groupID); err != nil {
			return nil, err
		}
	}
	return s.recipeRepo.ListCollections(ctx, userID, groupID, limit, offset)
}

// ListCollectionRecipes returns the recipes in a cookbook the caller can read.
func (s *RecipeService) ListCollectionRecipes(ctx context.Context, userID, collectionID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireCollectionReader(ctx, collection, userID); err != nil {
		return nil, err
	}
	return s.recipeRepo.ListRecipesByCollection(ctx, collectionID, limit, offset)
}

// UpdateCollection renames a cookbook or changes which household it is shared
// with (owner only).
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
	if collection.GroupID != nil {
		if err := s.requireMembership(ctx, userID, *collection.GroupID); err != nil {
			return err
		}
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

// AddToCollection files a recipe into a cookbook. Any member of a shared
// cookbook's household may add to it — that is the point of sharing one.
//
// GetRecipe is what stops a caller filing a recipe that does not exist or that
// they cannot see; before 000058 this checked neither.
func (s *RecipeService) AddToCollection(ctx context.Context, userID, collectionID, recipeID uuid.UUID) error {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionReader(ctx, collection, userID); err != nil {
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

// RemoveFromCollection takes a recipe out of a cookbook. Symmetric with
// AddToCollection: whoever may file into a shared cookbook may also unfile.
func (s *RecipeService) RemoveFromCollection(ctx context.Context, userID, collectionID, recipeID uuid.UUID) error {
	collection, err := s.recipeRepo.GetCollectionByID(ctx, collectionID)
	if err != nil {
		if err.Error() == "collection not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireCollectionReader(ctx, collection, userID); err != nil {
		return err
	}
	return s.recipeRepo.DeleteCollectionRecipe(ctx, collectionID, recipeID)
}

// compile-time interface check helpers
var (
	_ = pgx.ErrNoRows
)
