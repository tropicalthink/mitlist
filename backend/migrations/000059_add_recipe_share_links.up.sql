-- Share links for recipes.
--
-- A recipient who taps a shared link is none of the three things
-- RecipeService.GetRecipe recognises -- not the owner, not a household member,
-- and not an existing recipe_shares row. The token is the credential: an
-- unguessable capability URL that grants read-only access to one recipe, and
-- nothing else.
--
-- One token per recipe, revocable by clearing it. Rotating it invalidates every
-- link already handed out, which is the point of revoke.

ALTER TABLE recipes
    ADD COLUMN share_token TEXT UNIQUE,
    ADD COLUMN share_token_created_at TIMESTAMPTZ;

-- The token is looked up on every open of a shared link, and only ever by
-- exact match. Partial so revoked (NULL) recipes cost nothing to index.
CREATE INDEX idx_recipes_share_token
    ON recipes(share_token)
    WHERE share_token IS NOT NULL;
