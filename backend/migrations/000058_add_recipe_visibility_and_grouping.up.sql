-- Recipes and cookbooks gain household scoping.
--
-- `is_public` meant "readable by every authenticated user on this server",
-- while the UI switch that set it promised "everyone in this household can
-- find and use this recipe". Replace the boolean with an explicit visibility
-- plus an owning group so the two finally agree.
--
-- NOTE: `group_id` is ON DELETE SET NULL, so a deleted household leaves
-- `visibility = 'household'` with no group. That row is readable by its owner
-- alone -- the service treats a household recipe with no group as private
-- rather than as public. Fail closed, same as requireGroupMember.

ALTER TABLE recipes
    ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE SET NULL,
    ADD COLUMN visibility TEXT NOT NULL DEFAULT 'private';

ALTER TABLE recipes
    ADD CONSTRAINT recipes_visibility_check
    CHECK (visibility IN ('private', 'household'));

-- Backfill 1: a recipe already planned into a household's meals is a household
-- recipe in practice. Adopt that group so existing meal plans keep resolving.
UPDATE recipes r
SET group_id = mp.group_id,
    visibility = 'household'
FROM (
    SELECT DISTINCT ON (recipe_id) recipe_id, group_id
    FROM meal_plans
    ORDER BY recipe_id, created_at
) mp
WHERE r.id = mp.recipe_id;

-- Backfill 2: previously-public recipes whose owner belongs to exactly one
-- household become household-visible there. Owners in several households are
-- left private rather than guessing which one the switch meant.
UPDATE recipes r
SET group_id = m.group_id,
    visibility = 'household'
FROM (
    SELECT user_id, MIN(group_id::text)::uuid AS group_id
    FROM group_memberships
    GROUP BY user_id
    HAVING COUNT(*) = 1
) m
WHERE r.is_public
  AND r.group_id IS NULL
  AND r.user_id = m.user_id;

-- Everything else becomes private. This migration only ever narrows access:
-- `is_public` was readable server-wide by anyone holding the UUID, and
-- 'household' is not.
ALTER TABLE recipes DROP COLUMN is_public;

-- Cookbooks: NULL group_id = personal, set = shared with that household.
-- CASCADE because a shared cookbook is meaningless once its household is gone,
-- and the recipes inside it are owned separately.
ALTER TABLE collections
    ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE CASCADE;

-- Tag filtering does `tags @> $n`, which needs GIN to stay cheap as libraries
-- grow. jsonb_path_ops is the smaller index and supports @> specifically.
CREATE INDEX idx_recipes_tags ON recipes USING GIN (tags jsonb_path_ops);

-- Household listing reads (group_id, visibility) on every kitchen open.
CREATE INDEX idx_recipes_group_visibility
    ON recipes(group_id, visibility)
    WHERE visibility = 'household';

CREATE INDEX idx_collections_group
    ON collections(group_id)
    WHERE group_id IS NOT NULL;
