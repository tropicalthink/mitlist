CREATE TABLE list_notification_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    actor_name TEXT NOT NULL,
    list_name TEXT NOT NULL,
    last_item_name TEXT NOT NULL,
    item_count INTEGER NOT NULL DEFAULT 1 CHECK (item_count > 0),
    first_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deliver_after TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '45 seconds'),
    claimed_at TIMESTAMPTZ,
    UNIQUE (group_id, actor_id, list_id)
);

CREATE INDEX idx_list_notification_batches_due
    ON list_notification_batches (deliver_after)
    WHERE claimed_at IS NULL;
