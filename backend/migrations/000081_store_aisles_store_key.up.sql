-- Shipped store layouts are identified by a slug ("rewe"), which cannot live in
-- the store_id foreign key. Feedback for them was stored with a NULL store_id,
-- and because NULLs never conflict in a UNIQUE constraint every upload added a
-- new row. store_key carries the slug; the replacement unique index treats a
-- missing store as one value so feedback updates in place.
ALTER TABLE store_aisles ADD COLUMN store_key TEXT;

DELETE FROM store_aisles a
USING store_aisles b
WHERE a.group_id = b.group_id
  AND a.canonical_item_id = b.canonical_item_id
  AND COALESCE(a.store_id::text, a.store_key, '') = COALESCE(b.store_id::text, b.store_key, '')
  AND (a.updated_at, a.id) < (b.updated_at, b.id);

ALTER TABLE store_aisles
    DROP CONSTRAINT IF EXISTS store_aisles_group_id_store_id_canonical_item_id_key;

CREATE UNIQUE INDEX store_aisles_household_store_item
    ON store_aisles (group_id, (COALESCE(store_id::text, store_key, '')), canonical_item_id);
