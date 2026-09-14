package repositories

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

func normalizeJSONText(s string, fallback string) string {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return fallback
	}
	if json.Valid([]byte(trimmed)) {
		return trimmed
	}
	return fallback
}

func mustJSONArrayText(v []string) string {
	if v == nil {
		return "[]"
	}
	b, err := json.Marshal(v)
	if err != nil {
		return "[]"
	}
	return string(b)
}

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

// RecipeFilter narrows a recipe listing. The zero value returns everything the
// caller's scope allows, newest first.
type RecipeFilter struct {
	// GroupID, when set, widens the listing beyond the user's own recipes to
	// include the ones shared with that household. The service is responsible
	// for proving membership before setting it.
	GroupID *uuid.UUID
	// Tags matches recipes carrying ALL of these (jsonb @>, GIN-indexed).
	Tags []string
	// Search matches title or description, case-insensitively.
	Search string
	Limit  int
	Offset int
}

// recipeColumns is the SELECT list every recipe query shares. `alias` is the
// table alias to qualify each column with, or "" for an unaliased query.
func recipeColumns(alias string) string {
	if alias != "" {
		alias += "."
	}
	return fmt.Sprintf(`%[1]sid, %[1]suser_id, %[1]sgroup_id, %[1]svisibility, %[1]stitle, %[1]sdescription,
	       %[1]sdescription_short, %[1]sauthor, %[1]srating_value, %[1]srating_count,
	       COALESCE(%[1]snutrition_json, '{}'::jsonb)::text,
	       %[1]svideo_url,
	       COALESCE(%[1]sequipment_json, '{}'::jsonb)::text,
	       %[1]ssource_url,
	       %[1]simage_url,
	       COALESCE(%[1]simage_options, '[]'::jsonb)::text,
	       COALESCE(%[1]stags, '[]'::jsonb)::text,
	       %[1]sprep_time, %[1]scook_time, %[1]sservings,
	       %[1]sshare_token, %[1]sshare_token_created_at,
	       %[1]screated_at, %[1]supdated_at`, alias)
}

// recipeRowScanner is satisfied by both pgx.Row and pgx.Rows, so single-row and
// multi-row callers share one scan.
type recipeRowScanner interface {
	Scan(dest ...any) error
}

// scanRecipe reads one row shaped by recipeColumns.
func scanRecipe(s recipeRowScanner) (models.Recipe, error) {
	var rec models.Recipe
	var imageOptionsJSON, tagsJSON string
	err := s.Scan(
		&rec.ID,
		&rec.UserID,
		&rec.GroupID,
		&rec.Visibility,
		&rec.Title,
		&rec.Description,
		&rec.DescriptionShort,
		&rec.Author,
		&rec.RatingValue,
		&rec.RatingCount,
		&rec.NutritionJSON,
		&rec.VideoURL,
		&rec.EquipmentJSON,
		&rec.SourceURL,
		&rec.ImageURL,
		&imageOptionsJSON,
		&tagsJSON,
		&rec.PrepTime,
		&rec.CookTime,
		&rec.Servings,
		&rec.ShareToken,
		&rec.ShareTokenCreatedAt,
		&rec.CreatedAt,
		&rec.UpdatedAt,
	)
	if err != nil {
		return rec, err
	}
	_ = json.Unmarshal([]byte(imageOptionsJSON), &rec.ImageOptions)
	_ = json.Unmarshal([]byte(tagsJSON), &rec.Tags)
	return rec, nil
}

// collectRecipes drains rows shaped by recipeColumns. It closes rows.
func collectRecipes(rows pgx.Rows) ([]models.Recipe, error) {
	defer rows.Close()
	out := make([]models.Recipe, 0)
	for rows.Next() {
		rec, err := scanRecipe(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, rec)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

// CreateRecipe inserts a new recipe.
func (r *RecipeRepo) CreateRecipe(ctx context.Context, rec *models.Recipe) error {
	if rec.ID == uuid.Nil {
		rec.ID = uuid.New()
	}
	if rec.Visibility == "" {
		rec.Visibility = models.RecipeVisibilityPrivate
	}
	now := time.Now().UTC()
	rec.CreatedAt = now
	rec.UpdatedAt = now

	nutrition := normalizeJSONText(rec.NutritionJSON, "{}")
	equipment := normalizeJSONText(rec.EquipmentJSON, "{}")
	imageOptions := mustJSONArrayText(rec.ImageOptions)
	tags := mustJSONArrayText(rec.Tags)

	_, err := r.pool.Exec(ctx, `
		INSERT INTO recipes (id, user_id, group_id, visibility, title, description, description_short, author, rating_value, rating_count, nutrition_json, video_url, equipment_json, source_url, image_url, image_options, tags, prep_time, cook_time, servings, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12, $13::jsonb, $14, $15, $16::jsonb, $17::jsonb, $18, $19, $20, $21, $22)
	`, rec.ID, rec.UserID, rec.GroupID, rec.Visibility, rec.Title, rec.Description, rec.DescriptionShort, rec.Author, rec.RatingValue, rec.RatingCount, nutrition, rec.VideoURL, equipment, rec.SourceURL, rec.ImageURL, imageOptions, tags, rec.PrepTime, rec.CookTime, rec.Servings, rec.CreatedAt, rec.UpdatedAt)
	return err
}

// GetRecipesByIDs returns recipes keyed by ID (id, title, servings only).
func (r *RecipeRepo) GetRecipesByIDs(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.Recipe, error) {
	out := make(map[uuid.UUID]*models.Recipe)
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, title, servings
		FROM recipes
		WHERE id = ANY($1)
	`, ids)
	if err != nil {
		return nil, fmt.Errorf("get recipes by ids: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var rec models.Recipe
		if err := rows.Scan(&rec.ID, &rec.Title, &rec.Servings); err != nil {
			return nil, fmt.Errorf("scan recipe: %w", err)
		}
		recCopy := rec
		out[rec.ID] = &recCopy
	}
	return out, rows.Err()
}

// GetRecipeByID retrieves a recipe by its ID. It applies no access control —
// RecipeService.GetRecipe decides who may see the result.
func (r *RecipeRepo) GetRecipeByID(ctx context.Context, id uuid.UUID) (*models.Recipe, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+recipeColumns("")+`
		FROM recipes
		WHERE id = $1
	`, id)

	rec, err := scanRecipe(row)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("recipe not found")
		}
		return nil, err
	}
	return &rec, nil
}

// GetRecipeByShareToken resolves a share link. The token is the credential, so
// this deliberately applies no ownership check — the caller is anonymous.
func (r *RecipeRepo) GetRecipeByShareToken(ctx context.Context, token string) (*models.Recipe, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+recipeColumns("")+`
		FROM recipes
		WHERE share_token = $1
	`, token)

	rec, err := scanRecipe(row)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("recipe not found")
		}
		return nil, err
	}
	return &rec, nil
}

// SetShareToken issues or revokes (token == nil) a recipe's share link.
func (r *RecipeRepo) SetShareToken(ctx context.Context, recipeID uuid.UUID, token *string) error {
	var createdAt *time.Time
	if token != nil {
		now := time.Now().UTC()
		createdAt = &now
	}
	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipes
		SET share_token = $1, share_token_created_at = $2, updated_at = $3
		WHERE id = $4
	`, token, createdAt, time.Now().UTC(), recipeID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("recipe not found")
	}
	return nil
}

// ListRecipes returns the recipes owned by userID, plus — when filter.GroupID
// is set — the ones shared with that household, newest first.
//
// Callers must prove membership of filter.GroupID before setting it; this
// query trusts it.
func (r *RecipeRepo) ListRecipes(ctx context.Context, userID uuid.UUID, filter RecipeFilter) ([]models.Recipe, error) {
	args := []any{userID}
	scope := "user_id = $1"
	if filter.GroupID != nil {
		args = append(args, *filter.GroupID)
		scope = fmt.Sprintf("(user_id = $1 OR (group_id = $%d AND visibility = '%s'))",
			len(args), models.RecipeVisibilityHousehold)
	}

	where := []string{scope}

	if len(filter.Tags) > 0 {
		// @> asks "contains all of these", which is what the GIN index serves.
		args = append(args, mustJSONArrayText(filter.Tags))
		where = append(where, fmt.Sprintf("tags @> $%d::jsonb", len(args)))
	}

	if search := strings.TrimSpace(filter.Search); search != "" {
		args = append(args, "%"+search+"%")
		where = append(where, fmt.Sprintf("(title ILIKE $%d OR description ILIKE $%d)", len(args), len(args)))
	}

	args = append(args, clampLimit(filter.Limit))
	limitIdx := len(args)
	args = append(args, filter.Offset)

	rows, err := r.pool.Query(ctx, fmt.Sprintf(`
		SELECT %s
		FROM recipes
		WHERE %s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, recipeColumns(""), strings.Join(where, " AND "), limitIdx, limitIdx+1), args...)
	if err != nil {
		return nil, err
	}
	return collectRecipes(rows)
}

// ListDistinctTags returns the tags in use across the recipes userID can see,
// most-used first, so the client can offer a real filter bar instead of
// guessing from the current page.
func (r *RecipeRepo) ListDistinctTags(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit int) ([]models.RecipeTagCount, error) {
	args := []any{userID}
	scope := "user_id = $1"
	if groupID != nil {
		args = append(args, *groupID)
		scope = fmt.Sprintf("(user_id = $1 OR (group_id = $%d AND visibility = '%s'))",
			len(args), models.RecipeVisibilityHousehold)
	}
	args = append(args, clampLimit(limit))

	rows, err := r.pool.Query(ctx, fmt.Sprintf(`
		SELECT tag, COUNT(*) AS uses
		FROM recipes, LATERAL jsonb_array_elements_text(COALESCE(tags, '[]'::jsonb)) AS tag
		WHERE %s
		GROUP BY tag
		ORDER BY uses DESC, tag ASC
		LIMIT $%d
	`, scope, len(args)), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]models.RecipeTagCount, 0)
	for rows.Next() {
		var t models.RecipeTagCount
		if err := rows.Scan(&t.Tag, &t.Count); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// ListRecipesByCollection returns the recipes belonging to a collection,
// most-recently-added first.
func (r *RecipeRepo) ListRecipesByCollection(ctx context.Context, collectionID uuid.UUID, limit, offset int) ([]models.Recipe, error) {
	limit = clampLimit(limit)

	rows, err := r.pool.Query(ctx, `
		SELECT `+recipeColumns("rec")+`
		FROM recipes rec
		JOIN collection_recipes cr ON cr.recipe_id = rec.id
		WHERE cr.collection_id = $1
		ORDER BY cr.added_at DESC
		LIMIT $2 OFFSET $3
	`, collectionID, limit, offset)
	if err != nil {
		return nil, err
	}
	return collectRecipes(rows)
}

// UpdateRecipe updates an existing recipe.
func (r *RecipeRepo) UpdateRecipe(ctx context.Context, rec *models.Recipe) error {
	rec.UpdatedAt = time.Now().UTC()

	nutrition := normalizeJSONText(rec.NutritionJSON, "{}")
	equipment := normalizeJSONText(rec.EquipmentJSON, "{}")
	imageOptions := mustJSONArrayText(rec.ImageOptions)
	tags := mustJSONArrayText(rec.Tags)

	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipes
		SET title = $1, description = $2, description_short = $3, author = $4, rating_value = $5, rating_count = $6, nutrition_json = $7::jsonb, video_url = $8, equipment_json = $9::jsonb, source_url = $10, image_url = $11, image_options = $12::jsonb, tags = $13::jsonb, prep_time = $14, cook_time = $15, servings = $16, group_id = $17, visibility = $18, updated_at = $19
		WHERE id = $20
	`, rec.Title, rec.Description, rec.DescriptionShort, rec.Author, rec.RatingValue, rec.RatingCount, nutrition, rec.VideoURL, equipment, rec.SourceURL, rec.ImageURL, imageOptions, tags, rec.PrepTime, rec.CookTime, rec.Servings, rec.GroupID, rec.Visibility, rec.UpdatedAt, rec.ID)
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
		INSERT INTO recipe_ingredients (id, recipe_id, name, quantity, unit, raw_text, position)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, ing.ID, ing.RecipeID, ing.Name, ing.Quantity, ing.Unit, ing.RawText, ing.Position)
	return err
}

// ListIngredients returns all ingredients for a recipe ordered by position.
func (r *RecipeRepo) ListIngredients(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeIngredient, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, recipe_id, name, quantity, unit, raw_text, position
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

// ListIngredientsByRecipeIDs returns ingredients grouped by recipe_id.
func (r *RecipeRepo) ListIngredientsByRecipeIDs(ctx context.Context, recipeIDs []uuid.UUID) (map[uuid.UUID][]models.RecipeIngredient, error) {
	out := make(map[uuid.UUID][]models.RecipeIngredient)
	if len(recipeIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, recipe_id, name, quantity, unit, raw_text, position
		FROM recipe_ingredients
		WHERE recipe_id = ANY($1)
		ORDER BY recipe_id ASC, position ASC, id ASC
	`, recipeIDs)
	if err != nil {
		return nil, fmt.Errorf("list ingredients by recipe ids: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var ing models.RecipeIngredient
		if err := rows.Scan(&ing.ID, &ing.RecipeID, &ing.Name, &ing.Quantity, &ing.Unit, &ing.RawText, &ing.Position); err != nil {
			return nil, fmt.Errorf("scan ingredient: %w", err)
		}
		out[ing.RecipeID] = append(out[ing.RecipeID], ing)
	}
	return out, rows.Err()
}

// UpdateIngredient updates an existing ingredient.
func (r *RecipeRepo) UpdateIngredient(ctx context.Context, ing *models.RecipeIngredient) error {
	cmd, err := r.pool.Exec(ctx, `
		UPDATE recipe_ingredients
		SET name = $1, quantity = $2, unit = $3, raw_text = $4, position = $5
		WHERE id = $6
	`, ing.Name, ing.Quantity, ing.Unit, ing.RawText, ing.Position, ing.ID)
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
		INSERT INTO recipe_steps (id, recipe_id, name, description, position)
		VALUES ($1, $2, $3, $4, $5)
	`, step.ID, step.RecipeID, step.Name, step.Description, step.Position)
	return err
}

// ListSteps returns all steps for a recipe ordered by position.
func (r *RecipeRepo) ListSteps(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeStep, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, recipe_id, name, description, position
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
		SET name = $1, description = $2, position = $3
		WHERE id = $4
	`, step.Name, step.Description, step.Position, step.ID)
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
		INSERT INTO collections (id, user_id, group_id, name, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, c.ID, c.UserID, c.GroupID, c.Name, c.CreatedAt, c.UpdatedAt)
	return err
}

// collectionColumns is the SELECT list shared by the collection reads.
// recipe_count is derived per row rather than stored, so a cookbook can never
// report a stale total.
const collectionColumns = `c.id, c.user_id, c.group_id, c.name,
	       (SELECT COUNT(*) FROM collection_recipes cr WHERE cr.collection_id = c.id),
	       c.created_at, c.updated_at`

func scanCollection(s recipeRowScanner) (models.Collection, error) {
	var c models.Collection
	err := s.Scan(&c.ID, &c.UserID, &c.GroupID, &c.Name, &c.RecipeCount, &c.CreatedAt, &c.UpdatedAt)
	return c, err
}

// GetCollectionByID retrieves a collection by its ID. Access control lives in
// RecipeService.
func (r *RecipeRepo) GetCollectionByID(ctx context.Context, id uuid.UUID) (*models.Collection, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT `+collectionColumns+`
		FROM collections c
		WHERE c.id = $1
	`, id)

	c, err := scanCollection(row)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("collection not found")
		}
		return nil, err
	}
	return &c, nil
}

// ListCollections returns the cookbooks owned by userID, plus — when groupID is
// set — the ones shared with that household.
//
// Callers must prove membership of groupID before passing it.
func (r *RecipeRepo) ListCollections(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit, offset int) ([]models.Collection, error) {
	args := []any{userID}
	scope := "c.user_id = $1"
	if groupID != nil {
		args = append(args, *groupID)
		scope = fmt.Sprintf("(c.user_id = $1 OR c.group_id = $%d)", len(args))
	}
	args = append(args, clampLimit(limit), offset)

	rows, err := r.pool.Query(ctx, fmt.Sprintf(`
		SELECT %s
		FROM collections c
		WHERE %s
		ORDER BY c.created_at DESC
		LIMIT $%d OFFSET $%d
	`, collectionColumns, scope, len(args)-1, len(args)), args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]models.Collection, 0)
	for rows.Next() {
		c, err := scanCollection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// UpdateCollection updates an existing collection.
func (r *RecipeRepo) UpdateCollection(ctx context.Context, c *models.Collection) error {
	c.UpdatedAt = time.Now().UTC()

	cmd, err := r.pool.Exec(ctx, `
		UPDATE collections
		SET name = $1, group_id = $2, updated_at = $3
		WHERE id = $4
	`, c.Name, c.GroupID, c.UpdatedAt, c.ID)
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
	// Filing a recipe that is already in the cookbook is a no-op rather than
	// a unique-violation: the client offers "add to cookbook" from several
	// places and cannot cheaply know what is already there.
	_, err := r.pool.Exec(ctx, `
		INSERT INTO collection_recipes (id, collection_id, recipe_id, added_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (collection_id, recipe_id) DO NOTHING
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
