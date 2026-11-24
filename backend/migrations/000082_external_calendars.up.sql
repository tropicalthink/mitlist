-- Shared household calendars: members connect their own calendars (an ICS
-- subscription the server polls, or the phone's calendars uploaded by the
-- app) and share each one with their households, as busy blocks or with
-- titles. Nothing is shared until a share row exists.
CREATE TABLE calendar_connections (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind               TEXT NOT NULL CHECK (kind IN ('ics', 'device')),
    name               TEXT NOT NULL,
    device_id          TEXT,
    -- AES-GCM ciphertext of the subscription URL (it grants read access to
    -- the whole calendar); the key is derived from SECRET_KEY.
    ics_url_encrypted  BYTEA,
    last_synced_at     TIMESTAMPTZ,
    last_error         TEXT CHECK (last_error IN ('fetch_failed', 'not_calendar', 'too_large', 'unauthorized')),
    http_etag          TEXT,
    http_last_modified TEXT,
    last_attempt_at    TIMESTAMPTZ,
    failure_count      INT NOT NULL DEFAULT 0,
    next_attempt_at    TIMESTAMPTZ,
    content_hash       TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT calendar_connections_kind_fields CHECK (
        (kind = 'ics' AND ics_url_encrypted IS NOT NULL AND device_id IS NULL)
        OR (kind = 'device' AND device_id IS NOT NULL AND ics_url_encrypted IS NULL)
    )
);
CREATE INDEX idx_calendar_connections_user ON calendar_connections(user_id);
CREATE UNIQUE INDEX idx_calendar_connections_device
    ON calendar_connections(user_id, device_id) WHERE kind = 'device';
CREATE INDEX idx_calendar_connections_ics_due
    ON calendar_connections(next_attempt_at) WHERE kind = 'ics';

CREATE TABLE external_calendars (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_id UUID NOT NULL REFERENCES calendar_connections(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_id   TEXT NOT NULL,
    name          TEXT NOT NULL,
    color         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (connection_id, external_id)
);
CREATE INDEX idx_external_calendars_user ON external_calendars(user_id);

CREATE TABLE external_calendar_shares (
    calendar_id UUID NOT NULL REFERENCES external_calendars(id) ON DELETE CASCADE,
    group_id    UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    visibility  TEXT NOT NULL CHECK (visibility IN ('busy', 'details')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (calendar_id, group_id)
);
CREATE INDEX idx_external_calendar_shares_group ON external_calendar_shares(group_id);

CREATE TABLE external_events (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    calendar_id    UUID NOT NULL REFERENCES external_calendars(id) ON DELETE CASCADE,
    user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    external_uid   TEXT NOT NULL,
    starts_at      TIMESTAMPTZ NOT NULL,
    ends_at        TIMESTAMPTZ NOT NULL,
    all_day        BOOLEAN NOT NULL DEFAULT FALSE,
    title          TEXT CHECK (char_length(title) <= 200),
    source_private BOOLEAN NOT NULL DEFAULT FALSE,
    free           BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (ends_at >= starts_at),
    UNIQUE (calendar_id, external_uid, starts_at)
);
CREATE INDEX idx_external_events_calendar_starts ON external_events(calendar_id, starts_at);
CREATE INDEX idx_external_events_ends ON external_events(ends_at);
CREATE INDEX idx_external_events_user ON external_events(user_id);

CREATE TABLE external_event_overrides (
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    calendar_id  UUID NOT NULL REFERENCES external_calendars(id) ON DELETE CASCADE,
    external_uid TEXT NOT NULL,
    visibility   TEXT NOT NULL CHECK (visibility IN ('hidden', 'busy', 'details')),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (calendar_id, external_uid)
);
CREATE INDEX idx_external_event_overrides_user ON external_event_overrides(user_id);
