package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ListRepository provides data access for lists and list items.
type ListRepository struct {
	pool DBTX
}

var _ ListRepo = &ListRepository{}

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

	query := `INSERT INTO lists (id, group_id, name, type, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6)`
	_, err := r.pool.Exec(ctx, query, list.ID, list.GroupID, list.Name, list.Type, list.CreatedAt, list.UpdatedAt)
	return err
}

// GetListByID retrieves a list by ID.
func (r *ListRepository) GetListByID(ctx context.Context, id uuid.UUID) (*models.List, error) {
	query := `SELECT id, group_id, name, type, archived_at, created_at, updated_at FROM lists WHERE id = $1`
	row := r.pool.QueryRow(ctx, query, id)

	var l models.List
	err := row.Scan(&l.ID, &l.GroupID, &l.Name, &l.Type, &l.ArchivedAt, &l.CreatedAt, &l.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &l, nil
}

// GetListsByIDs returns lists for the given IDs.
func (r *ListRepository) GetListsByIDs(ctx context.Context, ids []uuid.UUID) ([]models.List, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, group_id, name, type, archived_at, created_at, updated_at
		FROM lists
		WHERE id = ANY($1)
	`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lists []models.List
	for rows.Next() {
		var l models.List
		if err := rows.Scan(&l.ID, &l.GroupID, &l.Name, &l.Type, &l.ArchivedAt, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, err
		}
		lists = append(lists, l)
	}
	return lists, rows.Err()
}

// ListListsByGroup returns all lists belonging to a group.
func (r *ListRepository) ListListsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.List, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `SELECT id, group_id, name, type, archived_at, created_at, updated_at FROM lists WHERE group_id = $1 AND archived_at IS NULL ORDER BY created_at DESC, id DESC LIMIT $2 OFFSET $3`
	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var lists []models.List
	for rows.Next() {
		var l models.List
		if err := rows.Scan(&l.ID, &l.GroupID, &l.Name, &l.Type, &l.ArchivedAt, &l.CreatedAt, &l.UpdatedAt); err != nil {
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
	// build placeholders
	placeholders := ""
	for i := range listIDs {
		if i > 0 {
			placeholders += ","
		}
		placeholders += "$" + fmt.Sprintf("%d", i+2)
	}
	query := fmt.Sprintf(`
		WITH ranked AS (
			SELECT list_id, name,
			       ROW_NUMBER() OVER (PARTITION BY list_id ORDER BY position ASC, id ASC) AS rn
			FROM list_items
			WHERE list_id IN (%s) AND deleted_at IS NULL
		)
		SELECT list_id, name FROM ranked WHERE rn <= $1
	`, placeholders)

	args := []any{perList}
	for _, id := range listIDs {
		args = append(args, id)
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("preview lines: %w", err)
	}
	defer rows.Close()

	collected := make(map[uuid.UUID][]string)
	for rows.Next() {
		var listID uuid.UUID
		var name string
		if err := rows.Scan(&listID, &name); err != nil {
			return nil, fmt.Errorf("scan preview: %w", err)
		}
		collected[listID] = append(collected[listID], name)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("preview rows: %w", err)
	}

	for _, id := range listIDs {
		items := collected[id]
		out[id] = items
	}
	return out, nil
}

// UpdateList updates a list.
func (r *ListRepository) UpdateList(ctx context.Context, list *models.List) error {
	query := `UPDATE lists SET name = $1, type = $2, updated_at = NOW() WHERE id = $3`
	_, err := r.pool.Exec(ctx, query, list.Name, list.Type, list.ID)
	return err
}

// HardDeleteList permanently deletes a list by ID.
func (r *ListRepository) HardDeleteList(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM lists WHERE id = $1`, id)
	return err
}

// SetListArchived sets or clears the archived_at timestamp for a list.
func (r *ListRepository) SetListArchived(ctx context.Context, id uuid.UUID, archived bool) error {
	var query string
	if archived {
		query = `UPDATE lists SET archived_at = NOW(), updated_at = NOW() WHERE id = $1`
	} else {
		query = `UPDATE lists SET archived_at = NULL, updated_at = NOW() WHERE id = $1`
	}
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// CreateItem inserts a new list item.
func (r *ListRepository) CreateItem(ctx context.Context, item *models.ListItem) error {
	if item.ID == uuid.Nil {
		item.ID = uuid.New()
	}
	now := time.Now().UTC()
	item.CreatedAt = now
	item.UpdatedAt = now

	query := `INSERT INTO list_items (id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, canonical_item_id, added_by, checked, position, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`
	_, err := r.pool.Exec(ctx, query,
		item.ID, item.ListID, item.Name, item.Quantity, item.Unit, item.Note, item.PriceCents, item.ProductID, item.StoreID, item.CanonicalItemID, item.AddedBy, item.Checked, item.Position, item.CreatedAt, item.UpdatedAt,
	)
	return err
}

// CreateItems inserts multiple list items in one statement.
func (r *ListRepository) CreateItems(ctx context.Context, items []models.ListItem) error {
	if len(items) == 0 {
		return nil
	}
	now := time.Now().UTC()
	ids := make([]uuid.UUID, len(items))
	listIDs := make([]uuid.UUID, len(items))
	names := make([]string, len(items))
	quantities := make([]float64, len(items))
	units := make([]string, len(items))
	notes := make([]string, len(items))
	priceCents := make([]*int, len(items))
	productIDs := make([]*uuid.UUID, len(items))
	storeIDs := make([]*uuid.UUID, len(items))
	addedBy := make([]*uuid.UUID, len(items))
	checked := make([]bool, len(items))
	positions := make([]int32, len(items))
	for i := range items {
		if items[i].ID == uuid.Nil {
			items[i].ID = uuid.New()
		}
		items[i].CreatedAt = now
		items[i].UpdatedAt = now
		ids[i] = items[i].ID
		listIDs[i] = items[i].ListID
		names[i] = items[i].Name
		quantities[i] = items[i].Quantity
		units[i] = items[i].Unit
		notes[i] = items[i].Note
		priceCents[i] = items[i].PriceCents
		productIDs[i] = items[i].ProductID
		storeIDs[i] = items[i].StoreID
		addedBy[i] = items[i].AddedBy
		checked[i] = items[i].Checked
		positions[i] = int32(items[i].Position)
	}
	_, err := r.pool.Exec(ctx, `
		INSERT INTO list_items (id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position, created_at, updated_at)
		SELECT id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position, $1, $1
		FROM unnest($2::uuid[], $3::uuid[], $4::text[], $5::float8[], $6::text[], $7::text[], $8::int[], $9::uuid[], $10::uuid[], $11::uuid[], $12::bool[], $13::int[]) AS t(
			id, list_id, name, quantity, unit, note, price_cents, product_id, store_id, added_by, checked, position
		)
	`, now, ids, listIDs, names, quantities, units, notes, priceCents, productIDs, storeIDs, addedBy, checked, positions)
	return err
}

// BulkMarkItemsChecked marks items checked when the user is a member of the list's group.
func (r *ListRepository) BulkMarkItemsChecked(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int64, error) {
	if len(itemIDs) == 0 {
		return 0, nil
	}
	res, err := r.pool.Exec(ctx, `
		UPDATE list_items li
		SET checked = true, updated_at = NOW()
		FROM lists l
		JOIN group_memberships gm ON gm.group_id = l.group_id AND gm.user_id = $1
		WHERE li.id = ANY($2) AND li.list_id = l.id AND li.deleted_at IS NULL
	`, userID, itemIDs)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected(), nil
}

// GetItemByID retrieves a list item by its ID.
func (r *ListRepository) GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error) {
	query := `SELECT id, list_id, name, quantity, unit, COALESCE(note,''), price_cents, product_id, store_id, added_by, claimed_by, checked, position, created_at, updated_at FROM list_items WHERE id = $1 AND deleted_at IS NULL`
	row := r.pool.QueryRow(ctx, query, id)

	var i models.ListItem
	err := row.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.PriceCents, &i.ProductID, &i.StoreID, &i.AddedBy, &i.ClaimedBy, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &i, nil
}

// GetItemByListNameUnit retrieves an existing item by its list, name, and unit.
func (r *ListRepository) GetItemByListNameUnit(ctx context.Context, listID uuid.UUID, name, unit string) (*models.ListItem, error) {
	query := `SELECT id, list_id, name, quantity, unit, COALESCE(note,''), price_cents, product_id, store_id, added_by, claimed_by, checked, position, created_at, updated_at FROM list_items WHERE list_id = $1 AND name = $2 AND (unit = $3 OR ($3 = '' AND unit IS NULL)) AND deleted_at IS NULL ORDER BY position ASC LIMIT 1`
	row := r.pool.QueryRow(ctx, query, listID, name, unit)

	var i models.ListItem
	err := row.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.PriceCents, &i.ProductID, &i.StoreID, &i.AddedBy, &i.ClaimedBy, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &i, nil
}

// ListItemsByList returns items belonging to a list.
func (r *ListRepository) ListItemsByList(ctx context.Context, listID uuid.UUID, limit, offset int) ([]models.ListItem, error) {
	if limit <= 0 {
		limit = 200
	}
	query := `SELECT id, list_id, name, quantity, unit, COALESCE(note,''), price_cents, product_id, store_id, added_by, claimed_by, checked, position, created_at, updated_at FROM list_items WHERE list_id = $1 AND deleted_at IS NULL ORDER BY position ASC, id ASC LIMIT $2 OFFSET $3`
	rows, err := r.pool.Query(ctx, query, listID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []models.ListItem
	for rows.Next() {
		var i models.ListItem
		if err := rows.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.PriceCents, &i.ProductID, &i.StoreID, &i.AddedBy, &i.ClaimedBy, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt); err != nil {
			return nil, err
		}
		items = append(items, i)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

// ListItemsByListIDs returns items grouped by list_id.
func (r *ListRepository) ListItemsByListIDs(ctx context.Context, listIDs []uuid.UUID) (map[uuid.UUID][]models.ListItem, error) {
	out := make(map[uuid.UUID][]models.ListItem)
	if len(listIDs) == 0 {
		return out, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id, list_id, name, quantity, unit, COALESCE(note,''), price_cents, product_id, store_id, added_by, claimed_by, checked, position, created_at, updated_at
		FROM list_items
		WHERE list_id = ANY($1) AND deleted_at IS NULL
		ORDER BY list_id ASC, position ASC, id ASC
	`, listIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var i models.ListItem
		if err := rows.Scan(&i.ID, &i.ListID, &i.Name, &i.Quantity, &i.Unit, &i.Note, &i.PriceCents, &i.ProductID, &i.StoreID, &i.AddedBy, &i.ClaimedBy, &i.Checked, &i.Position, &i.CreatedAt, &i.UpdatedAt); err != nil {
			return nil, err
		}
		out[i.ListID] = append(out[i.ListID], i)
	}
	return out, rows.Err()
}

// UpdateItem updates a list item.
func (r *ListRepository) UpdateItem(ctx context.Context, item *models.ListItem) error {
	query := `UPDATE list_items SET name = $1, quantity = $2, unit = $3, note = $4, price_cents = $5, checked = $6, position = $7, product_id = $8, store_id = $9, updated_at = NOW() WHERE id = $10 AND deleted_at IS NULL`
	_, err := r.pool.Exec(ctx, query, item.Name, item.Quantity, item.Unit, item.Note, item.PriceCents, item.Checked, item.Position, item.ProductID, item.StoreID, item.ID)
	return err
}

// HardDeleteItem permanently removes a list item.
func (r *ListRepository) HardDeleteItem(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM list_items WHERE id = $1`, id)
	return err
}

// SoftDeleteItem marks a list item as deleted.
func (r *ListRepository) SoftDeleteItem(ctx context.Context, id uuid.UUID) error {
	return r.SoftDeleteItemsByID(ctx, []uuid.UUID{id})
}

func (r *ListRepository) SoftDeleteItemsByID(ctx context.Context, ids []uuid.UUID) error {
	if len(ids) == 0 {
		return nil
	}
	now := time.Now().UTC()
	placeholders := ""
	for i := range ids {
		if i > 0 {
			placeholders += ","
		}
		placeholders += fmt.Sprintf("$%d", i+2)
	}
	query := fmt.Sprintf(`UPDATE list_items SET deleted_at = $1, updated_at = $2 WHERE id IN (%s) AND deleted_at IS NULL`, placeholders)
	args := []any{now, now}
	for _, id := range ids {
		args = append(args, id)
	}
	_, err := r.pool.Exec(ctx, query, args...)
	return err
}

// SoftDeleteItemsByList marks all or checked items in a list as deleted.
func (r *ListRepository) SoftDeleteItemsByList(ctx context.Context, listID uuid.UUID, onlyChecked bool) (int64, error) {
	now := time.Now().UTC()
	query := `UPDATE list_items SET deleted_at = $1, updated_at = $2 WHERE list_id = $3 AND deleted_at IS NULL AND ($4 = false OR checked = true)`
	res, err := r.pool.Exec(ctx, query, now, now, listID, onlyChecked)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected(), nil
}

func (r *ListRepository) BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error {
	if len(items) == 0 {
		return nil
	}
	ids := make([]uuid.UUID, len(items))
	positions := make([]int32, len(items))
	for i, item := range items {
		ids[i] = item.ID
		positions[i] = int32(item.Position)
	}
	_, err := r.pool.Exec(ctx, `
		UPDATE list_items AS li
		SET position = v.pos, updated_at = NOW()
		FROM (
			SELECT unnest($1::uuid[]) AS id, unnest($2::int[]) AS pos
		) AS v
		WHERE li.id = v.id
	`, ids, positions)
	return err
}

// ClaimItem sets the claimed_by user on an unchecked list item.
func (r *ListRepository) ClaimItem(ctx context.Context, id uuid.UUID, userID uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `UPDATE list_items SET claimed_by = $1, claimed_at = NOW(), updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL AND checked = false`, userID, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("item not found or already checked")
	}
	return nil
}

// UnclaimItem clears the claimed_by on a list item.
func (r *ListRepository) UnclaimItem(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `UPDATE list_items SET claimed_by = NULL, claimed_at = NULL, updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL`, id)
	return err
}

// CreateShoppingLocation inserts a new shopping location.
func (r *ListRepository) CreateShoppingLocation(ctx context.Context, location *models.ShoppingLocation) error {
	if location.ID == uuid.Nil {
		location.ID = uuid.New()
	}
	now := time.Now().UTC()
	location.CreatedAt = now
	query := `INSERT INTO shopping_locations (id, group_id, name, sort_order, created_at) VALUES ($1, $2, $3, $4, $5)`
	_, err := r.pool.Exec(ctx, query, location.ID, location.GroupID, location.Name, location.SortOrder, location.CreatedAt)
	return err
}

// ListShoppingLocationsByGroup returns all shopping locations for a group.
func (r *ListRepository) ListShoppingLocationsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.ShoppingLocation, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, group_id, name, sort_order, created_at FROM shopping_locations WHERE group_id = $1 ORDER BY sort_order ASC`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var locations []models.ShoppingLocation
	for rows.Next() {
		var l models.ShoppingLocation
		if err := rows.Scan(&l.ID, &l.GroupID, &l.Name, &l.SortOrder, &l.CreatedAt); err != nil {
			return nil, err
		}
		locations = append(locations, l)
	}
	return locations, rows.Err()
}

// CreateProduct inserts a new product.
func (r *ListRepository) CreateProduct(ctx context.Context, product *models.Product) error {
	if product.ID == uuid.Nil {
		product.ID = uuid.New()
	}
	now := time.Now().UTC()
	product.CreatedAt = now
	query := `INSERT INTO products (id, group_id, name, barcode, min_stock, in_stock, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)`
	_, err := r.pool.Exec(ctx, query, product.ID, product.GroupID, product.Name, product.Barcode, product.MinStock, product.InStock, product.CreatedAt)
	return err
}

// ListProductsByGroup returns all products for a group.
func (r *ListRepository) ListProductsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Product, error) {
	rows, err := r.pool.Query(ctx, `SELECT id, group_id, name, barcode, min_stock, in_stock, created_at FROM products WHERE group_id = $1 ORDER BY name ASC`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var p models.Product
		if err := rows.Scan(&p.ID, &p.GroupID, &p.Name, &p.Barcode, &p.MinStock, &p.InStock, &p.CreatedAt); err != nil {
			return nil, err
		}
		products = append(products, p)
	}
	return products, rows.Err()
}

// SearchProducts searches for products by name within a group.
func (r *ListRepository) SearchProducts(ctx context.Context, groupID uuid.UUID, query string, limit int) ([]models.Product, error) {
	if limit <= 0 {
		limit = 10
	}
	rows, err := r.pool.Query(ctx, `SELECT id, group_id, name, barcode, min_stock, in_stock, created_at FROM products WHERE group_id = $1 AND name ILIKE $2 ORDER BY name ASC LIMIT $3`, groupID, "%"+query+"%", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var products []models.Product
	for rows.Next() {
		var p models.Product
		if err := rows.Scan(&p.ID, &p.GroupID, &p.Name, &p.Barcode, &p.MinStock, &p.InStock, &p.CreatedAt); err != nil {
			return nil, err
		}
		products = append(products, p)
	}
	return products, rows.Err()
}

// CostSummary returns cost breakdown for a list.
func (r *ListRepository) CostSummary(ctx context.Context, listID uuid.UUID) (totalCents int, equalShareCents int, userContributions map[uuid.UUID]int, err error) {
	userContributions = make(map[uuid.UUID]int)
	query := `SELECT COALESCE(SUM(price_cents), 0), COUNT(DISTINCT added_by) FROM list_items WHERE list_id = $1 AND deleted_at IS NULL AND price_cents IS NOT NULL`
	if err := r.pool.QueryRow(ctx, query, listID).Scan(&totalCents, &equalShareCents); err != nil {
		return 0, 0, nil, err
	}
	if totalCents == 0 || equalShareCents == 0 {
		return 0, 0, userContributions, nil
	}

	userRows, err := r.pool.Query(ctx, `SELECT COALESCE(added_by, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(SUM(price_cents), 0) FROM list_items WHERE list_id = $1 AND deleted_at IS NULL AND price_cents IS NOT NULL GROUP BY added_by`, listID)
	if err != nil {
		return 0, 0, nil, err
	}
	defer userRows.Close()

	for userRows.Next() {
		var userID uuid.UUID
		var total int
		if err := userRows.Scan(&userID, &total); err != nil {
			return 0, 0, nil, err
		}
		userContributions[userID] = total
	}
	if err := userRows.Err(); err != nil {
		return 0, 0, nil, err
	}

	return totalCents, totalCents / equalShareCents, userContributions, nil
}
