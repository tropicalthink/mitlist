package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

// ListRepository provides data access for lists and list items.
type ListRepository struct {
	pool DBTX
}

// NewListRepository creates a new ListRepository.
func NewListRepository(pool DBTX) *ListRepository {
	return &ListRepository{pool: pool}
}

// CreateList inserts a new list.
func (r *ListRepository) CreateList(ctx context.Context, list *models.List) error {
	if list.ID == uuid.Nil {
		list.ID = uuid.New()
	}
	now := time.Now().UTC()
	list.CreatedAt = now
	list.UpdatedAt = now

	query := `
		INSERT INTO lists (id, group_id, name, type, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, query,
		list.ID, list.GroupID, list.Name, list.Type, list.CreatedAt, list.UpdatedAt,
	)
	return err
}

// GetListByID retrieves a list by its ID.
func (r *ListRepository) GetListByID(ctx context.Context, id uuid.UUID) (*models.List, error) {
	query := `
		SELECT id, group_id, name, type, created_at, updated_at
		FROM lists
		WHERE id = $1
	`
	row := r.pool.QueryRow(ctx, query, id)

	var l models.List
	err := row.Scan(&l.ID, &l.GroupID, &l.Name, &l.Type, &l.CreatedAt, &l.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}

// ListListsByGroup returns all lists belonging to a group.
func (r *ListRepository) ListListsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.List, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT id, group_id, name, type, created_at, updated_at
		FROM lists
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lists []models.List
	for rows.Next() {
		var l models.List
		if err := rows.Scan(&l.ID, &l.GroupID, &l.Name, &l.Type, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, err
		}
		lists = append(lists, l)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return lists, nil
}

// ListItemPreviewLinesByListIDs returns the first perList item names per list_id (non-deleted, list order).
func (r *ListRepository) ListItemPreviewLinesByListIDs(ctx context.Context, listIDs []uuid.UUID, perList int) (map[uuid.UUID][]string, error) {
	out := make(map[uuid.UUID][]string)
	if len(listIDs) == 0 {
		return out, nil
	}
	if perList <= 0 {
		perList = 4
	}
	query := `
		SELECT list_id, COALESCE(array_agg(name ORDER BY rk), '{}') AS preview
		FROM (
			SELECT list_id, name,
				row_number() OVER (PARTITION BY list_id ORDER BY position ASC, created_at ASC) AS rk
			FROM list_items
			WHERE deleted_at IS NULL AND list_id = ANY($1::uuid[])
		) t
		WHERE rk <= $2
		GROUP BY list_id
	`
	rows, err := r.pool.Query(ctx, query, listIDs, perList)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var listID uuid.UUID
		var preview []string
		if err := rows.Scan(&listID, &preview); err != nil {
			return nil, err
		}
		out[listID] = preview
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

// UpdateList updates an existing list.
func (r *ListRepository) UpdateList(ctx context.Context, list *models.List) error {
	list.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE lists
		SET name = $1, type = $2, updated_at = $3
		WHERE id = $4
	`
	res, err := r.pool.Exec(ctx, query, list.Name, list.Type, list.UpdatedAt, list.ID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("list not found")
	}
	return nil
}

// HardDeleteList permanently deletes a list by ID.
func (r *ListRepository) HardDeleteList(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM lists WHERE id = $1`
	res, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("list not found")
	}
	return nil
}

// CreateItem inserts a new list item.
func (r *ListRepository) CreateItem(ctx context.Context, item *models.ListItem) error {
	if item.ID == uuid.Nil {
		item.ID = uuid.New()
	}
	now := time.Now().UTC()
	item.CreatedAt = now
	item.UpdatedAt = now

	query := `
		INSERT INTO list_items (id, list_id, name, quantity, unit, note, product_id, store_id, checked, position, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
	`
	_, err := r.pool.Exec(ctx, query,
		item.ID, item.ListID, item.Name, item.Quantity, item.Unit, item.Note, item.ProductID, item.StoreID, item.Checked, item.Position, item.CreatedAt, item.UpdatedAt,
	)
	return err
}

// GetItemByID retrieves a list item by its ID.
func (r *ListRepository) GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error) {
	query := `
		SELECT id, list_id, name, quantity, unit, COALESCE(note, ''), product_id, store_id, checked, position, created_at, updated_at
		FROM list_items
		WHERE id = $1 AND deleted_at IS NULL
	`
	row := r.pool.QueryRow(ctx, query, id)

	var i models.ListItem
	err := row.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.ProductID, &i.StoreID, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &i, nil
}

// GetItemByListNameUnit retrieves an active item by normalized name and unit.
func (r *ListRepository) GetItemByListNameUnit(ctx context.Context, listID uuid.UUID, name, unit string) (*models.ListItem, error) {
	query := `
		SELECT id, list_id, name, quantity, unit, COALESCE(note, ''), product_id, store_id, checked, position, created_at, updated_at
		FROM list_items
		WHERE list_id = $1
			AND lower(trim(name)) = lower(trim($2))
			AND lower(trim(unit)) = lower(trim($3))
			AND deleted_at IS NULL
		ORDER BY created_at ASC
		LIMIT 1
	`
	row := r.pool.QueryRow(ctx, query, listID, name, unit)

	var i models.ListItem
	err := row.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.ProductID, &i.StoreID, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &i, nil
}

// ListItemsByList returns all non-deleted items in a list.
func (r *ListRepository) ListItemsByList(ctx context.Context, listID uuid.UUID, limit, offset int) ([]models.ListItem, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT id, list_id, name, quantity, unit, COALESCE(note, ''), product_id, store_id, checked, position, created_at, updated_at
		FROM list_items
		WHERE list_id = $1 AND deleted_at IS NULL
		ORDER BY position ASC, created_at ASC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, listID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.ListItem
	for rows.Next() {
		var i models.ListItem
		if err := rows.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.ProductID, &i.StoreID, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

// UpdateItem updates an existing list item.
func (r *ListRepository) UpdateItem(ctx context.Context, item *models.ListItem) error {
	item.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE list_items
		SET name = $1, quantity = $2, unit = $3, note = $4, product_id = $5, store_id = $6, checked = $7, position = $8, updated_at = $9
		WHERE id = $10
	`
	_, err := r.pool.Exec(ctx, query,
		item.Name, item.Quantity, item.Unit, item.Note, item.ProductID, item.StoreID, item.Checked, item.Position, item.UpdatedAt, item.ID,
	)
	return err
}

// BatchUpdateItemPositions updates the position of multiple list items in a single batch.
func (r *ListRepository) BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error {
	if len(items) == 0 {
		return nil
	}
	now := time.Now().UTC()
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)
	for _, item := range items {
		query := `UPDATE list_items SET position = $1, updated_at = $2 WHERE id = $3`
		if _, err := tx.Exec(ctx, query, item.Position, now, item.ID); err != nil {
			return fmt.Errorf("update item %s position: %w", item.ID, err)
		}
	}
	return tx.Commit(ctx)
}

// HardDeleteItem permanently deletes a list item by ID.
func (r *ListRepository) HardDeleteItem(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM list_items WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// SoftDeleteItem marks a list item as deleted.
func (r *ListRepository) SoftDeleteItem(ctx context.Context, id uuid.UUID) error {
	now := time.Now().UTC()
	query := `
		UPDATE list_items
		SET deleted_at = $1, updated_at = $2
		WHERE id = $3
	`
	_, err := r.pool.Exec(ctx, query, now, now, id)
	return err
}

// SoftDeleteItemsByList marks all or checked items in a list as deleted.
func (r *ListRepository) SoftDeleteItemsByList(ctx context.Context, listID uuid.UUID, onlyChecked bool) (int64, error) {
	now := time.Now().UTC()
	query := `
		UPDATE list_items
		SET deleted_at = $1, updated_at = $2
		WHERE list_id = $3 AND deleted_at IS NULL AND ($4 = false OR checked = true)
	`
	res, err := r.pool.Exec(ctx, query, now, now, listID, onlyChecked)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected(), nil
}

func (r *ListRepository) CreateShoppingLocation(ctx context.Context, location *models.ShoppingLocation) error {
	if location.ID == uuid.Nil {
		location.ID = uuid.New()
	}
	now := time.Now().UTC()
	location.CreatedAt = now
	location.UpdatedAt = now
	_, err := r.pool.Exec(ctx, `
		INSERT INTO shopping_locations (id, group_id, name, sort_order, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`, location.ID, location.GroupID, location.Name, location.SortOrder, location.CreatedAt, location.UpdatedAt)
	return err
}

func (r *ListRepository) ListShoppingLocationsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.ShoppingLocation, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, name, sort_order, created_at, updated_at
		FROM shopping_locations
		WHERE group_id = $1
		ORDER BY sort_order ASC, name ASC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var locations []models.ShoppingLocation
	for rows.Next() {
		var location models.ShoppingLocation
		if err := rows.Scan(&location.ID, &location.GroupID, &location.Name, &location.SortOrder, &location.CreatedAt, &location.UpdatedAt); err != nil {
			return nil, err
		}
		locations = append(locations, location)
	}
	return locations, rows.Err()
}

func (r *ListRepository) CreateProduct(ctx context.Context, product *models.Product) error {
	if product.ID == uuid.Nil {
		product.ID = uuid.New()
	}
	now := time.Now().UTC()
	product.CreatedAt = now
	product.UpdatedAt = now
	_, err := r.pool.Exec(ctx, `
		INSERT INTO products (id, group_id, name, barcode, unit, store_id, min_stock, in_stock, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`, product.ID, product.GroupID, product.Name, product.Barcode, product.Unit, product.StoreID, product.MinStock, product.InStock, product.CreatedAt, product.UpdatedAt)
	return err
}

func (r *ListRepository) ListProductsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Product, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, name, barcode, unit, store_id, min_stock, in_stock, created_at, updated_at
		FROM products
		WHERE group_id = $1
		ORDER BY name ASC
	`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var product models.Product
		if err := rows.Scan(&product.ID, &product.GroupID, &product.Name, &product.Barcode, &product.Unit, &product.StoreID, &product.MinStock, &product.InStock, &product.CreatedAt, &product.UpdatedAt); err != nil {
			return nil, err
		}
		products = append(products, product)
	}
	return products, rows.Err()
}

// compile-time interface check helpers
var (
	_ = pgx.ErrNoRows
)
