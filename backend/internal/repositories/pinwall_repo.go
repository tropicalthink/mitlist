package repositories

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/internal/models"
)

type PinwallRepository struct {
	db *pgxpool.Pool
}

func NewPinwallRepository(db *pgxpool.Pool) *PinwallRepository {
	return &PinwallRepository{db: db}
}

func (r *PinwallRepository) CreatePost(ctx context.Context, p *models.PinwallPost) error {
	const q = `
		INSERT INTO pinwall_posts (group_id, user_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at
	`
	if err := r.db.QueryRow(ctx, q, p.GroupID, p.UserID, p.Content).Scan(&p.ID, &p.CreatedAt); err != nil {
		return fmt.Errorf("create pinwall post: %w", err)
	}
	return nil
}

func (r *PinwallRepository) ListPostsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error) {
	const q = `
		SELECT id, group_id, user_id, content, created_at
		FROM pinwall_posts
		WHERE group_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, q, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list pinwall posts: %w", err)
	}
	defer rows.Close()

	var out []models.PinwallPost
	for rows.Next() {
		var p models.PinwallPost
		if err := rows.Scan(&p.ID, &p.GroupID, &p.UserID, &p.Content, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan pinwall post: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r *PinwallRepository) GetPostByID(ctx context.Context, id uuid.UUID) (*models.PinwallPost, error) {
	const q = `
		SELECT id, group_id, user_id, content, created_at
		FROM pinwall_posts
		WHERE id = $1
	`
	var p models.PinwallPost
	if err := r.db.QueryRow(ctx, q, id).Scan(&p.ID, &p.GroupID, &p.UserID, &p.Content, &p.CreatedAt); err != nil {
		if err == pgx.ErrNoRows {
			return nil, err
		}
		return nil, fmt.Errorf("get pinwall post: %w", err)
	}
	return &p, nil
}

func (r *PinwallRepository) DeletePost(ctx context.Context, id uuid.UUID) error {
	const q = `DELETE FROM pinwall_posts WHERE id = $1`
	ct, err := r.db.Exec(ctx, q, id)
	if err != nil {
		return fmt.Errorf("delete pinwall post: %w", err)
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

