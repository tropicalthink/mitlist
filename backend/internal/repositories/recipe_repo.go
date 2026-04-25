package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

// RecipeRepo handles raw SQL operations for recipe domain entities.
type RecipeRepo struct {
	pool DBTX
}

// NewRecipeRepo creates a new RecipeRepo.
func NewRecipeRepo(pool DBTX) *RecipeRepo {
	return &RecipeRepo{pool: pool}
}

// ------------------------------------------------------------------
// Recipes
// ------------------------------------------------------------------

// CreateRecipe inserts a new recipe.
func (r *RecipeRepo) CreateRecipe(ctx context.Context, rec *models.Recipe) error {
	if rec.ID == uuid.Nil {
		rec.ID = uuid.New()
	}
	now := time.Now().UTC()
	rec.CreatedAt = now
	rec.UpdatedAt = now

	_, err := r.pool.Exec(ctx, `
		INSERT INTO recipes (id, user_id, title, description, prep_time, cook_time, servings, image_url, is_public, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`, rec.ID, rec.UserID, rec.Title, rec.Description, rec.PrepTime, rec.CookTime, rec.Servings, rec.ImageURL, rec.IsPublic, rec.CreatedAt, rec.UpdatedAt)
	return err
}

// GetRecipeByID retrieves a recipe by its ID.
func (r *RecipeRepo) GetRecipeByID(ctx context.Context, id uuid.UUID) (*models.Recipe, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, user_id, title, description, prep_time, cook_time, servings, image_url, is_public, created_at, updated_at
		FROM recipes
		WHERE id = $1
	`, id)

	var rec models.Recipe
	err := row.Scan(&rec.ID, &rec.UserID, &rec.Title, &rec.Description, &rec.PrepTime, &rec.CookTime, &rec.Servings, &rec.ImageURL, &rec.IsPublic, &rec.CreatedAt, &rec.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("recipe not found")
		}
		return nil, err
	}
	return &rec, nil
}

// ListRecipesByUser returns paginated recipes for a user.
func (r *RecipeRepo) ListRecipesByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, title, description, prep_time, cook_time, servings, image_url, is_public, created_at, updated_at
		FROM recipes
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Recipe])
}

// UpdateRecipe updates an existing recipe.
func (r *RecipeRepo) UpdateRecipe(ctx context.Context, rec *models.Recipe) error {
	rec.UpdatedAt = time.Now().UTC()

	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipes
		SET title = $1, description = $2, prep_time = $3, cook_time = $4, servings = $5, image_url = $6, is_public = $7, updated_at = $8
		WHERE id = $9
	`, rec.Title, rec.Description, rec.PrepTime, rec.CookTime, rec.Servings, rec.ImageURL, rec.IsPublic, rec.UpdatedAt, rec.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("recipe not found")
	}
	return nil
}

// DeleteRecipe removes a recipe and its dependent ingredients and steps.
func (r *RecipeRepo) DeleteRecipe(ctx context.Context, id uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM recipe_ingredients WHERE recipe_id = $1`, id)
	if err != nil {
		return err
	}

	_, err = tx.Exec(ctx, `DELETE FROM recipe_steps WHERE recipe_id = $1`, id)
	if err != nil {
		return err
	}

	cmd, err := tx.Exec(ctx, `DELETE FROM recipes WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("recipe not found")
	}

	return tx.Commit(ctx)
}

// ------------------------------------------------------------------
// Ingredients
// ------------------------------------------------------------------

// CreateIngredient inserts a new recipe ingredient.
func (r *RecipeRepo) CreateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	if ing.ID == uuid.Nil {
		ing.ID = uuid.New()
	}

	_, err := r.pool.Exec(ctx, `
		INSERT INTO recipe_ingredients (id, recipe_id, name, quantity, unit, position)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, ing.ID, ing.RecipeID, ing.Name, ing.Quantity, ing.Unit, ing.Position)
	return err
}

// ListIngredients returns all ingredients for a recipe ordered by position.
func (r *RecipeRepo) ListIngredients(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeIngredient, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, recipe_id, name, quantity, unit, position
		FROM recipe_ingredients
		WHERE recipe_id = $1
		ORDER BY position ASC, id ASC
	`, recipeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.RecipeIngredient])
}

// UpdateIngredient updates an existing ingredient.
func (r *RecipeRepo) UpdateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipe_ingredients
		SET name = $1, quantity = $2, unit = $3, position = $4
		WHERE id = $5
	`, ing.Name, ing.Quantity, ing.Unit, ing.Position, ing.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("ingredient not found")
	}
	return nil
}

// DeleteIngredient removes an ingredient by ID.
func (r *RecipeRepo) DeleteIngredient(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM recipe_ingredients WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("ingredient not found")
	}
	return nil
}

// ------------------------------------------------------------------
// Steps
// ------------------------------------------------------------------

// CreateStep inserts a new recipe step.
func (r *RecipeRepo) CreateStep(ctx context.Context, step *models.RecipeStep) error {
	if step.ID == uuid.Nil {
		step.ID = uuid.New()
	}

	_, err := r.pool.Exec(ctx, `
		INSERT INTO recipe_steps (id, recipe_id, description, position)
		VALUES ($1, $2, $3, $4)
	`, step.ID, step.RecipeID, step.Description, step.Position)
	return err
}

// ListSteps returns all steps for a recipe ordered by position.
func (r *RecipeRepo) ListSteps(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeStep, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, recipe_id, description, position
		FROM recipe_steps
		WHERE recipe_id = $1
		ORDER BY position ASC, id ASC
	`, recipeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.RecipeStep])
}

// UpdateStep updates an existing step.
func (r *RecipeRepo) UpdateStep(ctx context.Context, step *models.RecipeStep) error {
	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipe_steps
		SET description = $1, position = $2
		WHERE id = $3
	`, step.Description, step.Position, step.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("step not found")
	}
	return nil
}

// DeleteStep removes a step by ID.
func (r *RecipeRepo) DeleteStep(ctx context.Context, id uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `DELETE FROM recipe_steps WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("step not found")
	}
	return nil
}

// ------------------------------------------------------------------
// Collections
// ------------------------------------------------------------------

// CreateCollection inserts a new collection.
func (r *RecipeRepo) CreateCollection(ctx context.Context, c *models.Collection) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	now := time.Now().UTC()
	c.CreatedAt = now
	c.UpdatedAt = now

	_, err := r.pool.Exec(ctx, `
		INSERT INTO collections (id, user_id, name, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`, c.ID, c.UserID, c.Name, c.CreatedAt, c.UpdatedAt)
	return err
}

// GetCollectionByID retrieves a collection by its ID.
func (r *RecipeRepo) GetCollectionByID(ctx context.Context, id uuid.UUID) (*models.Collection, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, user_id, name, created_at, updated_at
		FROM collections
		WHERE id = $1
	`, id)

	var c models.Collection
	err := row.Scan(&c.ID, &c.UserID, &c.Name, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("collection not found")
		}
		return nil, err
	}
	return &c, nil
}

// ListCollections returns paginated collections for a user.
func (r *RecipeRepo) ListCollections(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Collection, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT id, user_id, name, created_at, updated_at
		FROM collections
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return pgx.CollectRows(rows, pgx.RowToStructByName[models.Collection])
}

// UpdateCollection updates an existing collection.
func (r *RecipeRepo) UpdateCollection(ctx context.Context, c *models.Collection) error {
	c.UpdatedAt = time.Now().UTC()

	cmd, err := r.pool.Exec(ctx, `
		UPDATE collections
		SET name = $1, updated_at = $2
		WHERE id = $3
	`, c.Name, c.UpdatedAt, c.ID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("collection not found")
	}
	return nil
}

// DeleteCollection removes a collection and its recipe associations by ID.
func (r *RecipeRepo) DeleteCollection(ctx context.Context, id uuid.UUID) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM collection_recipes WHERE collection_id = $1`, id)
	if err != nil {
		return err
	}

	cmd, err := tx.Exec(ctx, `DELETE FROM collections WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("collection not found")
	}

	return tx.Commit(ctx)
}

// CreateRecipeShare inserts a new recipe share.
func (r *RecipeRepo) CreateRecipeShare(ctx context.Context, share *models.RecipeShare) error {
	if share.ID == uuid.Nil {
		share.ID = uuid.New()
	}
	share.CreatedAt = time.Now().UTC()
	_, err := r.pool.Exec(ctx, `
		INSERT INTO recipe_shares (id, recipe_id, shared_with_user_id, permission, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`, share.ID, share.RecipeID, share.SharedWithUserID, share.Permission, share.CreatedAt)
	return err
}

// GetRecipeShareByUser retrieves a share for a specific recipe and user.
func (r *RecipeRepo) GetRecipeShareByUser(ctx context.Context, recipeID, userID uuid.UUID) (*models.RecipeShare, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id, recipe_id, shared_with_user_id, permission, created_at
		FROM recipe_shares
		WHERE recipe_id = $1 AND shared_with_user_id = $2
	`, recipeID, userID)
	var s models.RecipeShare
	err := row.Scan(&s.ID, &s.RecipeID, &s.SharedWithUserID, &s.Permission, &s.CreatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("recipe share not found")
		}
		return nil, err
	}
	return &s, nil
}

// CreateCollectionRecipe inserts a recipe into a collection.
func (r *RecipeRepo) CreateCollectionRecipe(ctx context.Context, cr *models.CollectionRecipe) error {
	if cr.ID == uuid.Nil {
		cr.ID = uuid.New()
	}
	cr.AddedAt = time.Now().UTC()
	_, err := r.pool.Exec(ctx, `
		INSERT INTO collection_recipes (id, collection_id, recipe_id, added_at)
		VALUES ($1, $2, $3, $4)
	`, cr.ID, cr.CollectionID, cr.RecipeID, cr.AddedAt)
	return err
}

// DeleteCollectionRecipe removes a recipe from a collection.
func (r *RecipeRepo) DeleteCollectionRecipe(ctx context.Context, collectionID, recipeID uuid.UUID) error {
	cmd, err := r.pool.Exec(ctx, `
		DELETE FROM collection_recipes WHERE collection_id = $1 AND recipe_id = $2
	`, collectionID, recipeID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("collection recipe not found")
	}
	return nil
}
