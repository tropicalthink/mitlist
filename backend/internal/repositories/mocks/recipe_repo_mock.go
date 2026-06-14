package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/stretchr/testify/mock"
	"github.com/mitlist-app/mitlist/internal/models"
)

// MockRecipeRepo is a mock implementation of repositories.RecipeRepoIface.
type MockRecipeRepo struct {
	mock.Mock
}

func (m *MockRecipeRepo) CreateRecipe(ctx context.Context, rec *models.Recipe) error {
	args := m.Called(ctx, rec)
	return args.Error(0)
}

func (m *MockRecipeRepo) GetRecipeByID(ctx context.Context, id uuid.UUID) (*models.Recipe, error) {
	args := m.Called(ctx, id)
	if r := args.Get(0); r != nil {
		return r.(*models.Recipe), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) GetRecipesByIDs(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
	args := m.Called(ctx, ids)
	if r := args.Get(0); r != nil {
		return r.(map[uuid.UUID]*models.Recipe), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) ListRecipesByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	args := m.Called(ctx, userID, limit, offset)
	if r := args.Get(0); r != nil {
		return r.([]models.Recipe), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) UpdateRecipe(ctx context.Context, rec *models.Recipe) error {
	args := m.Called(ctx, rec)
	return args.Error(0)
}

func (m *MockRecipeRepo) DeleteRecipe(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockRecipeRepo) CreateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	args := m.Called(ctx, ing)
	return args.Error(0)
}

func (m *MockRecipeRepo) ListIngredients(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeIngredient, error) {
	args := m.Called(ctx, recipeID)
	if i := args.Get(0); i != nil {
		return i.([]models.RecipeIngredient), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) ListIngredientsByRecipeIDs(ctx context.Context, recipeIDs []uuid.UUID) (map[uuid.UUID][]models.RecipeIngredient, error) {
	args := m.Called(ctx, recipeIDs)
	if i := args.Get(0); i != nil {
		return i.(map[uuid.UUID][]models.RecipeIngredient), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) UpdateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	args := m.Called(ctx, ing)
	return args.Error(0)
}

func (m *MockRecipeRepo) DeleteIngredient(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockRecipeRepo) CreateStep(ctx context.Context, step *models.RecipeStep) error {
	args := m.Called(ctx, step)
	return args.Error(0)
}

func (m *MockRecipeRepo) ListSteps(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeStep, error) {
	args := m.Called(ctx, recipeID)
	if s := args.Get(0); s != nil {
		return s.([]models.RecipeStep), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) UpdateStep(ctx context.Context, step *models.RecipeStep) error {
	args := m.Called(ctx, step)
	return args.Error(0)
}

func (m *MockRecipeRepo) DeleteStep(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockRecipeRepo) CreateCollection(ctx context.Context, c *models.Collection) error {
	args := m.Called(ctx, c)
	return args.Error(0)
}

func (m *MockRecipeRepo) GetCollectionByID(ctx context.Context, id uuid.UUID) (*models.Collection, error) {
	args := m.Called(ctx, id)
	if c := args.Get(0); c != nil {
		return c.(*models.Collection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) ListCollections(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Collection, error) {
	args := m.Called(ctx, userID, limit, offset)
	if c := args.Get(0); c != nil {
		return c.([]models.Collection), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) UpdateCollection(ctx context.Context, c *models.Collection) error {
	args := m.Called(ctx, c)
	return args.Error(0)
}

func (m *MockRecipeRepo) DeleteCollection(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockRecipeRepo) CreateRecipeShare(ctx context.Context, share *models.RecipeShare) error {
	args := m.Called(ctx, share)
	return args.Error(0)
}

func (m *MockRecipeRepo) GetRecipeShareByUser(ctx context.Context, recipeID, userID uuid.UUID) (*models.RecipeShare, error) {
	args := m.Called(ctx, recipeID, userID)
	if s := args.Get(0); s != nil {
		return s.(*models.RecipeShare), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockRecipeRepo) CreateCollectionRecipe(ctx context.Context, cr *models.CollectionRecipe) error {
	args := m.Called(ctx, cr)
	return args.Error(0)
}

func (m *MockRecipeRepo) DeleteCollectionRecipe(ctx context.Context, collectionID, recipeID uuid.UUID) error {
	args := m.Called(ctx, collectionID, recipeID)
	return args.Error(0)
}
