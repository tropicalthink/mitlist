-- Revert household scoping for recipes and cookbooks.
--
-- Lossy by nature: `is_public` cannot express "visible to household X", so
-- every household recipe comes back as server-wide public -- which is what it
-- would have been before 000058 anyway.

DROP INDEX IF EXISTS idx_collections_group;
DROP INDEX IF EXISTS idx_recipes_group_visibility;
DROP INDEX IF EXISTS idx_recipes_tags;

ALTER TABLE collections DROP COLUMN IF EXISTS group_id;

ALTER TABLE recipes ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT false;

UPDATE recipes SET is_public = true WHERE visibility = 'household';

ALTER TABLE recipes DROP CONSTRAINT IF EXISTS recipes_visibility_check;

ALTER TABLE recipes
    DROP COLUMN IF EXISTS visibility,
    DROP COLUMN IF EXISTS group_id;
