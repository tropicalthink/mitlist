-- Durable, globally ordered SSE events. The global cursor allows a client to
-- reconnect with Last-Event-ID while group_id keeps replay authorization and
-- query volume bounded. The store prunes rows older than its 30-day replay
-- window; stale cursors receive an explicit reset response from the handler.
CREATE SEQUENCE sse_event_ids_seq AS BIGINT;

CREATE TABLE sse_events (
    id BIGINT PRIMARY KEY DEFAULT nextval('sse_event_ids_seq'),
    version INTEGER NOT NULL DEFAULT 1 CHECK (version > 0),
    origin TEXT NOT NULL,
    event_type TEXT NOT NULL,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sse_events_group_id_id ON sse_events(group_id, id);
CREATE INDEX idx_sse_events_created_at ON sse_events(created_at);

-- A cursor reset remains detectable even after the retention job removes the
-- final event row. This is a global floor, so a reset may be conservative for
-- a quiet group; a normal snapshot is always safe.
CREATE TABLE sse_event_retention (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    floor_id BIGINT NOT NULL DEFAULT 0
);
INSERT INTO sse_event_retention(singleton, floor_id) VALUES (TRUE, 0);

-- Wake other API instances after a committed insert. The payload is the
-- durable ID; listeners fetch the row rather than trusting notification data.
CREATE OR REPLACE FUNCTION notify_sse_event() RETURNS trigger AS $$
BEGIN
    PERFORM pg_notify('mitlist_sse_events', NEW.id::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sse_events_notify
AFTER INSERT ON sse_events
FOR EACH ROW EXECUTE FUNCTION notify_sse_event();
