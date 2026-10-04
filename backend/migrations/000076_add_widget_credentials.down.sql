DROP INDEX IF EXISTS idx_integration_credentials_widget_device;
DELETE FROM integration_credentials WHERE kind = 'widget';
ALTER TABLE integration_credentials DROP CONSTRAINT IF EXISTS integration_credentials_widget_device;
ALTER TABLE integration_credentials DROP COLUMN IF EXISTS expires_at;
ALTER TABLE integration_credentials DROP COLUMN IF EXISTS device_id;
ALTER TABLE integration_credentials DROP COLUMN IF EXISTS kind;
