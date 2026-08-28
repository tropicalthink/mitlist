-- Revert recipe share links. Every link already handed out stops resolving.

DROP INDEX IF EXISTS idx_recipes_share_token;

ALTER TABLE recipes
    DROP COLUMN IF EXISTS share_token,
    DROP COLUMN IF EXISTS share_token_created_at;
