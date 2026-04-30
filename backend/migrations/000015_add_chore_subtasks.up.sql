CREATE TABLE IF NOT EXISTS chore_subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chore_id UUID NOT NULL REFERENCES chores(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chore_subtasks_chore_id ON chore_subtasks(chore_id);
CREATE INDEX IF NOT EXISTS idx_chore_subtasks_chore_position ON chore_subtasks(chore_id, position);

ALTER TABLE chore_assignments ADD COLUMN IF NOT EXISTS skip_reason TEXT;

ALTER TABLE chores ADD COLUMN IF NOT EXISTS supplies JSONB DEFAULT '[]';
