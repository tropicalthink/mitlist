-- Home screen widgets authenticate with a device-bound integration credential
-- instead of the app's rotating session: a widget process refreshing at the
-- same time as the app would replay a refresh token and revoke the session.
-- The app issues one per install (kind = 'widget'), renews it while it is in
-- the foreground, and such a credential expires on its own. It is also void
-- once users.auth_valid_after moves past its created_at (password change or
-- reset, account deletion, guest conversion), which the lookup enforces.
ALTER TABLE integration_credentials
    ADD COLUMN kind TEXT NOT NULL DEFAULT 'integration'
        CHECK (kind IN ('integration', 'widget')),
    ADD COLUMN device_id TEXT,
    ADD COLUMN expires_at TIMESTAMPTZ,
    ADD CONSTRAINT integration_credentials_widget_device
        CHECK (kind <> 'widget' OR (device_id IS NOT NULL AND expires_at IS NOT NULL));

-- One live widget credential per install. Re-issuing revokes the old row
-- first, inside the same transaction.
CREATE UNIQUE INDEX idx_integration_credentials_widget_device
    ON integration_credentials(user_id, device_id)
    WHERE kind = 'widget' AND revoked_at IS NULL;
