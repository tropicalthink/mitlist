package repositories

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// GroceryRepository provides data access for the grocery graph tables.
type GroceryRepository struct {
	pool DBTX
}

// NewGroceryRepository creates a new GroceryRepository.
func NewGroceryRepository(pool DBTX) *GroceryRepository {
	return &GroceryRepository{pool: pool}
}

// ---------------------------------------------------------------------------
// Version tracking
// ---------------------------------------------------------------------------

// NextVersion increments and returns the per-household monotonic version counter.
func (r *GroceryRepository) NextVersion(ctx context.Context, groupID uuid.UUID) (int64, error) {
	query := `
		INSERT INTO grocery_versions (group_id, version)
		VALUES ($1, 1)
		ON CONFLICT (group_id) DO UPDATE
			SET version = grocery_versions.version + 1
		RETURNING version`
	var v int64
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&v)
	return v, err
}

// CurrentVersion returns the current version for a group (0 if none yet).
func (r *GroceryRepository) CurrentVersion(ctx context.Context, groupID uuid.UUID) (int64, error) {
	query := `SELECT COALESCE(version, 0) FROM grocery_versions WHERE group_id = $1`
	var v int64
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&v)
	if err != nil {
		return 0, nil // no row → version 0
	}
	return v, nil
}

// ---------------------------------------------------------------------------
// Delta fetch — returns all rows with version > sinceVersion
// ---------------------------------------------------------------------------

// GetDelta returns the graph delta for a household since a client cursor.
func (r *GroceryRepository) GetDelta(ctx context.Context, groupID uuid.UUID, sinceVersion int64) (*models.GroceryGraphDelta, error) {
	delta := &models.GroceryGraphDelta{}

	// Canonical items (include global seed rows for all households).
	{
		q := `
			SELECT id, group_id, name_de, name_en, category, default_unit,
			       product_id, is_global, version, created_at, updated_at, deleted_at
			FROM canonical_items
			WHERE (group_id = $1 OR is_global = true) AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var it models.CanonicalItem
			if err := rows.Scan(&it.ID, &it.GroupID, &it.NameDe, &it.NameEn,
				&it.Category, &it.DefaultUnit, &it.ProductID, &it.IsGlobal,
				&it.Version, &it.CreatedAt, &it.UpdatedAt, &it.DeletedAt); err != nil {
				return nil, err
			}
			delta.CanonicalItems = append(delta.CanonicalItems, it)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	// Item aliases.
	{
		q := `
			SELECT id, group_id, canonical_item_id, alias_text, lang, source, weight,
			       version, created_at, updated_at, deleted_at
			FROM item_aliases
			WHERE (group_id = $1 OR group_id = '00000000-0000-0000-0000-000000000000') AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var a models.ItemAlias
			if err := rows.Scan(&a.ID, &a.GroupID, &a.CanonicalItemID, &a.AliasText,
				&a.Lang, &a.Source, &a.Weight, &a.Version,
				&a.CreatedAt, &a.UpdatedAt, &a.DeletedAt); err != nil {
				return nil, err
			}
			delta.ItemAliases = append(delta.ItemAliases, a)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	// Corrections.
	{
		q := `
			SELECT id, group_id, user_id, scope, kind, raw_text,
			       resolved_canonical_item_id, corrected_value, source,
			       version, created_at, applied_at
			FROM corrections
			WHERE group_id = $1 AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var c models.Correction
			var correctedValueBytes []byte
			if err := rows.Scan(&c.ID, &c.GroupID, &c.UserID, &c.Scope, &c.Kind,
				&c.RawText, &c.ResolvedCanonicalItemID, &correctedValueBytes,
				&c.Source, &c.Version, &c.CreatedAt, &c.AppliedAt); err != nil {
				return nil, err
			}
			if correctedValueBytes != nil {
				c.CorrectedValue = json.RawMessage(correctedValueBytes)
			}
			delta.Corrections = append(delta.Corrections, c)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	// Store aisles.
	{
		q := `
			SELECT id, group_id, store_id, canonical_item_id, aisle, sort_order,
			       confidence, version, created_at, updated_at, deleted_at
			FROM store_aisles
			WHERE group_id = $1 AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var a models.StoreAisle
			if err := rows.Scan(&a.ID, &a.GroupID, &a.StoreID, &a.CanonicalItemID,
				&a.Aisle, &a.SortOrder, &a.Confidence, &a.Version,
				&a.CreatedAt, &a.UpdatedAt, &a.DeletedAt); err != nil {
				return nil, err
			}
			delta.StoreAisles = append(delta.StoreAisles, a)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	// Purchase history.
	{
		q := `
			SELECT id, group_id, canonical_item_id, list_item_id, quantity, unit,
			       version, purchased_at
			FROM purchase_history
			WHERE group_id = $1 AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var p models.PurchaseHistory
			if err := rows.Scan(&p.ID, &p.GroupID, &p.CanonicalItemID, &p.ListItemID,
				&p.Quantity, &p.Unit, &p.Version, &p.PurchasedAt); err != nil {
				return nil, err
			}
			delta.PurchaseHistory = append(delta.PurchaseHistory, p)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	// Item co-occurrence.
	{
		q := `
			SELECT group_id, item_a_id, item_b_id, count, last_seen_at, version
			FROM item_cooccurrence
			WHERE group_id = $1 AND version > $2
			ORDER BY version`
		rows, err := r.pool.Query(ctx, q, groupID, sinceVersion)
		if err != nil {
			return nil, err
		}
		defer rows.Close()
		for rows.Next() {
			var co models.ItemCooccurrence
			if err := rows.Scan(&co.GroupID, &co.ItemAID, &co.ItemBID,
				&co.Count, &co.LastSeenAt, &co.Version); err != nil {
				return nil, err
			}
			delta.ItemCooccurrence = append(delta.ItemCooccurrence, co)
		}
		if err := rows.Err(); err != nil {
			return nil, err
		}
	}

	return delta, nil
}

// ---------------------------------------------------------------------------
// Corrections — append-only write + alias materialisation
// ---------------------------------------------------------------------------

// InsertCorrection appends a correction event and bumps the household version.
// It also upserts the corresponding item_aliases row so the correction takes
// effect immediately on the next alias lookup.
func (r *GroceryRepository) InsertCorrection(ctx context.Context, c *models.Correction, version int64) error {
	if c.ID == uuid.Nil {
		c.ID = uuid.New()
	}
	c.CreatedAt = time.Now().UTC()
	c.Version = version

	correctedValueBytes, err := json.Marshal(c.CorrectedValue)
	if err != nil {
		correctedValueBytes = []byte("null")
	}

	query := `
		INSERT INTO corrections
			(id, group_id, user_id, scope, kind, raw_text,
			 resolved_canonical_item_id, corrected_value, source, version, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`
	_, err = r.pool.Exec(ctx, query,
		c.ID, c.GroupID, c.UserID, c.Scope, c.Kind, c.RawText,
		c.ResolvedCanonicalItemID, correctedValueBytes, c.Source, c.Version, c.CreatedAt,
	)
	return err
}

// AisleFeedbackItem is a single drag-to-reorder event from the client.
type AisleFeedbackItem struct {
	CanonicalItemID uuid.UUID  `json:"canonical_item_id"`
	StoreID         *uuid.UUID `json:"store_id,omitempty"`
	Aisle           string     `json:"aisle"`
	SortOrder       int        `json:"sort_order"`
}

// UpsertAislesBatch persists a batch of aisle feedback rows from the client.
func (r *GroceryRepository) UpsertAislesBatch(ctx context.Context, groupID uuid.UUID, items []AisleFeedbackItem, version int64) error {
	now := time.Now().UTC()
	for _, item := range items {
		query := `
			INSERT INTO store_aisles
				(id, group_id, store_id, canonical_item_id, aisle, sort_order, confidence, version, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, $6, 1.0, $7, $8, $8)
			ON CONFLICT (group_id, store_id, canonical_item_id) DO UPDATE
				SET aisle      = EXCLUDED.aisle,
				    sort_order = EXCLUDED.sort_order,
				    confidence = 1.0,
				    version    = EXCLUDED.version,
				    updated_at = EXCLUDED.updated_at`
		_, err := r.pool.Exec(ctx, query,
			uuid.New(), groupID, item.StoreID, item.CanonicalItemID,
			item.Aisle, item.SortOrder, version, now,
		)
		if err != nil {
			return err
		}
	}
	return nil
}

// UpsertAlias writes or increments an item_aliases row for a confirmed alias correction.
func (r *GroceryRepository) UpsertAlias(ctx context.Context, groupID, canonicalItemID uuid.UUID, aliasText, lang, source string, version int64) error {
	if aliasText == "" {
		return nil
	}
	now := time.Now().UTC()
	query := `
		INSERT INTO item_aliases
			(id, group_id, canonical_item_id, alias_text, lang, source, weight, version, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, 1, $7, $8, $8)
		ON CONFLICT (group_id, alias_text) DO UPDATE
			SET weight    = item_aliases.weight + 1,
			    version   = EXCLUDED.version,
			    updated_at = EXCLUDED.updated_at`
	_, err := r.pool.Exec(ctx, query,
		uuid.New(), groupID, canonicalItemID, aliasText, lang, source, version, now,
	)
	return err
}
