ALTER TABLE chore_templates
DROP COLUMN IF EXISTS description,
DROP COLUMN IF EXISTS period_interval,
DROP COLUMN IF EXISTS period_config,
DROP COLUMN IF EXISTS track_date_only,
DROP COLUMN IF EXISTS rollover,
DROP COLUMN IF EXISTS assignment_type,
DROP COLUMN IF EXISTS category;
