DROP INDEX IF EXISTS idx_notifications_user_group_created;
DROP INDEX IF EXISTS idx_notifications_user_created;
ALTER TABLE notifications DROP COLUMN IF EXISTS group_id;
