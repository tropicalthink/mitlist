-- Coalesces bursts of interactive activity by one person (meal plan edits,
-- expenses added in a row) into a single notification per household, the same
-- way list_notification_batches already does for list items. One row per
-- (group, actor, notification type, scope); every new event extends the row and
-- pushes delivery out, a cap on first_at guarantees delivery.
CREATE TABLE activity_notification_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    n_type TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    actor_name TEXT NOT NULL,
    last_item_name TEXT NOT NULL DEFAULT '',
    item_names TEXT[] NOT NULL DEFAULT '{}',
    item_count INTEGER NOT NULL DEFAULT 1 CHECK (item_count > 0),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    first_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deliver_after TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '3 minutes'),
    claimed_at TIMESTAMPTZ,
    UNIQUE (group_id, actor_id, n_type, scope_key)
);

CREATE INDEX idx_activity_notification_batches_due
    ON activity_notification_batches (deliver_after)
    WHERE claimed_at IS NULL;
