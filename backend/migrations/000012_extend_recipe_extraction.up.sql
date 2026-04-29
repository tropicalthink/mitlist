-- Add extended recipe fields for better content extraction
ALTER TABLE recipes
    ADD COLUMN IF NOT EXISTS description_short TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS author TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS rating_value NUMERIC(3,2),
    ADD COLUMN IF NOT EXISTS rating_count INTEGER,
    ADD COLUMN IF NOT EXISTS nutrition_json JSONB,
    ADD COLUMN IF NOT EXISTS video_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS equipment_json JSONB,
    ADD COLUMN IF NOT EXISTS source_url TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS image_options JSONB,
    ADD COLUMN IF NOT EXISTS tags JSONB;

-- Add raw_text to recipe_ingredients for preserving original scraped text
ALTER TABLE recipe_ingredients
    ADD COLUMN IF NOT EXISTS raw_text TEXT NOT NULL DEFAULT '';

-- Add name/title to recipe_steps for structured step display
ALTER TABLE recipe_steps
    ADD COLUMN IF NOT EXISTS name TEXT NOT NULL DEFAULT '';
