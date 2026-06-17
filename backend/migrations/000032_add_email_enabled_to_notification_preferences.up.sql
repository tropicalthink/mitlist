ALTER TABLE notification_preferences
    ADD COLUMN email_enabled boolean NOT NULL DEFAULT false;
