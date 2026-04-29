-- Revert extended recipe fields
ALTER TABLE recipes
    DROP COLUMN IF EXISTS description_short,
    DROP COLUMN IF EXISTS author,
    DROP COLUMN IF EXISTS rating_value,
    DROP COLUMN IF EXISTS rating_count,
    DROP COLUMN IF EXISTS nutrition_json,
    DROP COLUMN IF EXISTS video_url,
    DROP COLUMN IF EXISTS equipment_json,
    DROP COLUMN IF EXISTS source_url,
    DROP COLUMN IF EXISTS image_options,
    DROP COLUMN IF EXISTS tags;

ALTER TABLE recipe_ingredients
    DROP COLUMN IF EXISTS raw_text;

ALTER TABLE recipe_steps
    DROP COLUMN IF EXISTS name;
