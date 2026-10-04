DROP TABLE IF EXISTS reengagement_email_sends;
DROP INDEX IF EXISTS idx_users_last_active_at;
ALTER TABLE users DROP COLUMN IF EXISTS last_active_at;
ALTER TABLE users DROP COLUMN IF EXISTS language;
