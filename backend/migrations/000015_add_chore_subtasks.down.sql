DROP TABLE IF EXISTS chore_subtasks;

ALTER TABLE chore_assignments DROP COLUMN IF EXISTS skip_reason;

ALTER TABLE chores DROP COLUMN IF EXISTS supplies;
