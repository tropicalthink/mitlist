DROP INDEX IF EXISTS store_aisles_household_store_item;

ALTER TABLE store_aisles
    ADD CONSTRAINT store_aisles_group_id_store_id_canonical_item_id_key
    UNIQUE (group_id, store_id, canonical_item_id);

ALTER TABLE store_aisles DROP COLUMN IF EXISTS store_key;
