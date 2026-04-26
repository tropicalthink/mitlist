WITH ranked_pending_assignments AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY chore_id
            ORDER BY assigned_at DESC, id DESC
        ) AS row_number
    FROM chore_assignments
    WHERE status = 'pending'
)
DELETE FROM chore_assignments
WHERE id IN (
    SELECT id
    FROM ranked_pending_assignments
    WHERE row_number > 1
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_chore_assignments_one_pending_per_chore
ON chore_assignments(chore_id)
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_chore_assignments_due_pending
ON chore_assignments(due_date)
WHERE status = 'pending';
