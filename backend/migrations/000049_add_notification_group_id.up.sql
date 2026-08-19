ALTER TABLE notifications
    ADD COLUMN group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

UPDATE notifications AS notification
SET group_id = household.id
FROM groups AS household
WHERE notification.data->>'group_id' = household.id::text;

CREATE INDEX idx_notifications_user_group_created
    ON notifications(user_id, group_id, created_at DESC);

CREATE INDEX idx_notifications_user_created
    ON notifications(user_id, created_at DESC, id DESC);
