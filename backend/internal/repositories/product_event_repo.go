package repositories

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ProductEventRepository stores first-party product events (plans/048
// stage 8).
type ProductEventRepository struct{ db DBTX }

func NewProductEventRepository(db DBTX) *ProductEventRepository {
	return &ProductEventRepository{db: db}
}

// InsertEvents stores a batch in one statement. The service has already
// validated names, props and identities.
func (r *ProductEventRepository) InsertEvents(ctx context.Context, events []models.ProductEvent) error {
	if len(events) == 0 {
		return nil
	}
	query := `INSERT INTO product_events (occurred_at, name, user_id, install_id, group_id, role, props) VALUES `
	args := make([]any, 0, len(events)*7)
	for i, e := range events {
		props, err := json.Marshal(e.Props)
		if err != nil {
			return fmt.Errorf("encode event props: %w", err)
		}
		if e.Props == nil {
			props = []byte("{}")
		}
		var role *string
		if e.Role != "" {
			role = &e.Role
		}
		if i > 0 {
			query += ", "
		}
		n := i * 7
		query += fmt.Sprintf("($%d, $%d, $%d, $%d, $%d, $%d, $%d)", n+1, n+2, n+3, n+4, n+5, n+6, n+7)
		args = append(args, e.OccurredAt, e.Name, e.UserID, e.InstallID, e.GroupID, role, props)
	}
	if _, err := r.db.Exec(ctx, query, args...); err != nil {
		return fmt.Errorf("insert product events: %w", err)
	}
	return nil
}
