DROP TRIGGER IF EXISTS sse_events_notify ON sse_events;
DROP FUNCTION IF EXISTS notify_sse_event();
DROP TABLE IF EXISTS sse_event_retention;
DROP TABLE IF EXISTS sse_events;
DROP SEQUENCE IF EXISTS sse_event_ids_seq;
