ALTER TABLE chores
ADD COLUMN IF NOT EXISTS period_interval INTEGER NOT NULL DEFAULT 1,
ADD COLUMN IF NOT EXISTS period_config TEXT[] NOT NULL DEFAULT '{}',
ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS track_date_only BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS rollover BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS assignment_type TEXT NOT NULL DEFAULT 'round-robin',
ADD COLUMN IF NOT EXISTS assignment_config UUID[] NOT NULL DEFAULT '{}';

UPDATE chores
SET start_date = COALESCE(start_date, created_at),
    rotation_type = CASE
        WHEN frequency = 'none' THEN 'manual'
        WHEN rotation_type IN ('', 'none', 'manual') THEN 'schedule'
        ELSE rotation_type
    END,
    assignment_type = CASE
        WHEN assignment_type = 'none' THEN 'no-assignment'
        WHEN assignment_type = 'alphabetical' THEN 'in-alphabetical-order'
        ELSE assignment_type
    END;
