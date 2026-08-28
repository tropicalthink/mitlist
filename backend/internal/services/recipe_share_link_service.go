package services

import (
	"context"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
)

// shareTokenLen is the length of a recipe share token drawn from
// inviteAlphabet (31 chars, ~4.954 bits each). 26 chars ≈ 128 bits — far past
// guessing range, which matters because the token IS the access check.
//
// Unlike an invite code nobody reads this aloud; it only ever travels inside a
// URL, so length costs nothing.
const shareTokenLen = 26

// CreateShareLink returns the recipe's share token, minting one on first use.
//
// Idempotent by design: tapping Share twice hands out the same link rather than
// leaving a trail of independently-live capabilities behind. Rotating is what
// RevokeShareLink is for.
func (s *RecipeService) CreateShareLink(ctx context.Context, userID, recipeID uuid.UUID) (string, error) {
	recipe, err := s.recipeRepo.GetRecipeByID(ctx, recipeID)
	if err != nil {
		if err.Error() == "recipe not found" {
			return "", api.ErrNotFound
		}
		return "", err
	}
	if err := s.requireOwner(recipe, userID); err != nil {
		return "", err
	}
	if recipe.ShareToken != nil && *recipe.ShareToken != "" {
		return *recipe.ShareToken, nil
	}

	token, err := randToken(shareTokenLen)
	if err != nil {
		return "", err
	}
	if err := s.recipeRepo.SetShareToken(ctx, recipeID, &token); err != nil {
		return "", err
	}
	return token, nil
}

// RevokeShareLink clears the token. Every link already handed out stops
// resolving — that is the point.
func (s *RecipeService) RevokeShareLink(ctx context.Context, userID, recipeID uuid.UUID) error {
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
	return s.recipeRepo.SetShareToken(ctx, recipeID, nil)
}

// SharedRecipe is the read-only view behind a share link: enough to cook from,
// with nothing identifying the owner.
type SharedRecipe struct {
	Recipe      *models.Recipe            `json:"recipe"`
	Ingredients []models.RecipeIngredient `json:"ingredients"`
	Steps       []models.RecipeStep       `json:"steps"`
}

// GetSharedRecipe resolves a share link. There is no authentication here on
// purpose: the token is the credential, and the endpoint has to work for a
// recipient who does not have the app and is not signed in.
func (s *RecipeService) GetSharedRecipe(ctx context.Context, token string) (*SharedRecipe, error) {
	if token == "" {
		return nil, api.ErrNotFound
	}
	recipe, err := s.recipeRepo.GetRecipeByShareToken(ctx, token)
	if err != nil {
		if err.Error() == "recipe not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}

	ingredients, err := s.recipeRepo.ListIngredients(ctx, recipe.ID)
	if err != nil {
		return nil, err
	}
	steps, err := s.recipeRepo.ListSteps(ctx, recipe.ID)
	if err != nil {
		return nil, err
	}

	// The viewer is anonymous, so strip everything about where this recipe
	// lives. They get the cooking content, not the owner's filing.
	view := *recipe
	view.UserID = uuid.Nil
	view.GroupID = nil
	view.Visibility = ""
	view.ShareToken = nil
	view.ShareTokenCreatedAt = nil

	return &SharedRecipe{Recipe: &view, Ingredients: ingredients, Steps: steps}, nil
}

// SaveSharedRecipe copies a shared recipe into the caller's own library.
//
// A copy, not a reference: the recipient owns their version outright and can
// edit it, and it survives the sharer revoking the link or deleting the
// original. visibility and groupID choose between "save to my recipes" and
// "save to our household", validated exactly like a fresh create.
func (s *RecipeService) SaveSharedRecipe(ctx context.Context, userID uuid.UUID, token, visibility string, groupID *uuid.UUID) (*models.Recipe, error) {
	shared, err := s.GetSharedRecipe(ctx, token)
	if err != nil {
		return nil, err
	}

	src := shared.Recipe
	copied := &models.Recipe{
		Title:            src.Title,
		Description:      src.Description,
		DescriptionShort: src.DescriptionShort,
		Author:           src.Author,
		RatingValue:      src.RatingValue,
		RatingCount:      src.RatingCount,
		NutritionJSON:    src.NutritionJSON,
		VideoURL:         src.VideoURL,
		EquipmentJSON:    src.EquipmentJSON,
		SourceURL:        src.SourceURL,
		ImageURL:         src.ImageURL,
		ImageOptions:     src.ImageOptions,
		Tags:             src.Tags,
		PrepTime:         src.PrepTime,
		CookTime:         src.CookTime,
		Servings:         src.Servings,
		Visibility:       visibility,
		GroupID:          groupID,
	}

	// CreateRecipe applies applyVisibility, so saving into a household the
	// caller does not belong to is rejected here just as it would be on create.
	if err := s.CreateRecipe(ctx, userID, copied); err != nil {
		return nil, err
	}

	for i, ing := range shared.Ingredients {
		if err := s.recipeRepo.CreateIngredient(ctx, &models.RecipeIngredient{
			RecipeID: copied.ID,
			Name:     ing.Name,
			Quantity: ing.Quantity,
			Unit:     ing.Unit,
			RawText:  ing.RawText,
			Position: i,
		}); err != nil {
			return nil, err
		}
	}
	for i, step := range shared.Steps {
		if err := s.recipeRepo.CreateStep(ctx, &models.RecipeStep{
			RecipeID:    copied.ID,
			Name:        step.Name,
			Description: step.Description,
			Position:    i,
		}); err != nil {
			return nil, err
		}
	}

	return copied, nil
}
