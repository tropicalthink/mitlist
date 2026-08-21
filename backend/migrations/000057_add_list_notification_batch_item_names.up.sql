ALTER TABLE list_notification_batches
    ADD COLUMN item_names TEXT[] NOT NULL DEFAULT '{}';
