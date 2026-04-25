package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

// TemplateRepository handles list and chore template persistence.
type TemplateRepository struct {
	pool DBTX
}

// NewTemplateRepository creates a new TemplateRepository.
func NewTemplateRepository(pool DBTX) *TemplateRepository {
	return &TemplateRepository{pool: pool}
}

// CreateTemplate inserts a new list template.
func (r *TemplateRepository) CreateTemplate(ctx context.Context, template *models.Template) error {
	template.ID = uuid.New()
	query := `
		INSERT INTO templates (id, group_id, name, created_at, updated_at)
		VALUES ($1, $2, $3, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query, template.ID, template.GroupID, template.Name).Scan(&template.CreatedAt, &template.UpdatedAt)
}

// GetTemplateByID retrieves a list template by ID.
func (r *TemplateRepository) GetTemplateByID(ctx context.Context, id uuid.UUID) (*models.Template, error) {
	query := `
		SELECT id, group_id, name, created_at, updated_at
		FROM templates
		WHERE id = $1
	`
	var t models.Template
	err := r.pool.QueryRow(ctx, query, id).Scan(&t.ID, &t.GroupID, &t.Name, &t.CreatedAt, &t.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("template not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get template: %w", err)
	}
	return &t, nil
}

// ListTemplates retrieves templates for a group with pagination.
func (r *TemplateRepository) ListTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Template, error) {
	query := `
		SELECT id, group_id, name, created_at, updated_at
		FROM templates
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	limit = clampLimit(limit)
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list templates: %w", err)
	}
	defer rows.Close()

	var templates []models.Template
	for rows.Next() {
		var t models.Template
		if err := rows.Scan(&t.ID, &t.GroupID, &t.Name, &t.CreatedAt, &t.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan template: %w", err)
		}
		templates = append(templates, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("template rows error: %w", err)
	}
	return templates, nil
}

// UpdateTemplate updates a list template.
func (r *TemplateRepository) UpdateTemplate(ctx context.Context, template *models.Template) error {
	query := `
		UPDATE templates
		SET name = $1, updated_at = NOW()
		WHERE id = $2
		RETURNING updated_at
	`
	err := r.pool.QueryRow(ctx, query, template.Name, template.ID).Scan(&template.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("template not found: %w", err)
		}
		return fmt.Errorf("failed to update template: %w", err)
	}
	return nil
}

// DeleteTemplate deletes a list template by ID.
func (r *TemplateRepository) DeleteTemplate(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM templates WHERE id = $1`
	tag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete template: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("template not found")
	}
	return nil
}

// CreateTemplateItem inserts a new item into a list template.
func (r *TemplateRepository) CreateTemplateItem(ctx context.Context, item *models.TemplateItem) error {
	item.ID = uuid.New()
	query := `
		INSERT INTO template_items (id, template_id, name, quantity, unit)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.pool.Exec(ctx, query, item.ID, item.TemplateID, item.Name, item.Quantity, item.Unit)
	if err != nil {
		return fmt.Errorf("failed to create template item: %w", err)
	}
	return nil
}

// ListTemplateItems retrieves all items for a list template.
func (r *TemplateRepository) ListTemplateItems(ctx context.Context, templateID uuid.UUID) ([]models.TemplateItem, error) {
	query := `
		SELECT id, template_id, name, quantity, unit
		FROM template_items
		WHERE template_id = $1
		ORDER BY name
	`
	rows, err := r.pool.Query(ctx, query, templateID)
	if err != nil {
		return nil, fmt.Errorf("failed to list template items: %w", err)
	}
	defer rows.Close()

	var items []models.TemplateItem
	for rows.Next() {
		var i models.TemplateItem
		if err := rows.Scan(&i.ID, &i.TemplateID, &i.Name, &i.Quantity, &i.Unit); err != nil {
			return nil, fmt.Errorf("failed to scan template item: %w", err)
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("template item rows error: %w", err)
	}
	return items, nil
}

// UpdateTemplateItem updates a list template item.
func (r *TemplateRepository) UpdateTemplateItem(ctx context.Context, item *models.TemplateItem) error {
	query := `
		UPDATE template_items
		SET name = $1, quantity = $2, unit = $3
		WHERE id = $4
	`
	tag, err := r.pool.Exec(ctx, query, item.Name, item.Quantity, item.Unit, item.ID)
	if err != nil {
		return fmt.Errorf("failed to update template item: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("template item not found")
	}
	return nil
}

// DeleteTemplateItem deletes a list template item by ID.
func (r *TemplateRepository) DeleteTemplateItem(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM template_items WHERE id = $1`
	tag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete template item: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("template item not found")
	}
	return nil
}

// CreateChoreTemplate inserts a new chore template.
func (r *TemplateRepository) CreateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error {
	ct.ID = uuid.New()
	query := `
		INSERT INTO chore_templates (id, group_id, name, rotation_type, frequency, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		RETURNING created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query, ct.ID, ct.GroupID, ct.Name, ct.RotationType, ct.Frequency).Scan(&ct.CreatedAt, &ct.UpdatedAt)
}

// GetChoreTemplateByID retrieves a chore template by ID.
func (r *TemplateRepository) GetChoreTemplateByID(ctx context.Context, id uuid.UUID) (*models.ChoreTemplate, error) {
	query := `
		SELECT id, group_id, name, rotation_type, frequency, created_at, updated_at
		FROM chore_templates
		WHERE id = $1
	`
	var ct models.ChoreTemplate
	err := r.pool.QueryRow(ctx, query, id).Scan(&ct.ID, &ct.GroupID, &ct.Name, &ct.RotationType, &ct.Frequency, &ct.CreatedAt, &ct.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, fmt.Errorf("chore template not found: %w", err)
		}
		return nil, fmt.Errorf("failed to get chore template: %w", err)
	}
	return &ct, nil
}

// ListChoreTemplates retrieves chore templates for a group with pagination.
func (r *TemplateRepository) ListChoreTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ChoreTemplate, error) {
	query := `
		SELECT id, group_id, name, rotation_type, frequency, created_at, updated_at
		FROM chore_templates
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	limit = clampLimit(limit)
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to list chore templates: %w", err)
	}
	defer rows.Close()

	var templates []models.ChoreTemplate
	for rows.Next() {
		var ct models.ChoreTemplate
		if err := rows.Scan(&ct.ID, &ct.GroupID, &ct.Name, &ct.RotationType, &ct.Frequency, &ct.CreatedAt, &ct.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed to scan chore template: %w", err)
		}
		templates = append(templates, ct)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("chore template rows error: %w", err)
	}
	return templates, nil
}

// UpdateChoreTemplate updates a chore template.
func (r *TemplateRepository) UpdateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error {
	query := `
		UPDATE chore_templates
		SET name = $1, rotation_type = $2, frequency = $3, updated_at = NOW()
		WHERE id = $4
		RETURNING updated_at
	`
	err := r.pool.QueryRow(ctx, query, ct.Name, ct.RotationType, ct.Frequency, ct.ID).Scan(&ct.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return fmt.Errorf("chore template not found: %w", err)
		}
		return fmt.Errorf("failed to update chore template: %w", err)
	}
	return nil
}

// DeleteChoreTemplate deletes a chore template by ID.
func (r *TemplateRepository) DeleteChoreTemplate(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM chore_templates WHERE id = $1`
	tag, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete chore template: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("chore template not found")
	}
	return nil
}
