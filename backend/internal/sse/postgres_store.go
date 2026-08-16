package sse

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const postgresNotifyChannel = "mitlist_sse_events"

// ErrCursorExpired tells the transport that a reconnect cursor predates the
// retained event log. Clients must perform a normal snapshot reconciliation
// and reconnect without Last-Event-ID.
var ErrCursorExpired = errors.New("sse cursor expired")

// PostgresStore persists the SSE log and uses PostgreSQL NOTIFY as a wake-up
// signal between API instances. NOTIFY is intentionally only a hint: Watch
// reads the complete row by ID, and reconnect replay remains the correctness
// mechanism if a notification is dropped while a process is restarting.
type PostgresStore struct {
	db      *pgxpool.Pool
	origin  string
	appends atomic.Uint64
}

// NewPostgresStore creates a durable event store. origin identifies this API
// process in diagnostics and is included in every event written by it.
func NewPostgresStore(db *pgxpool.Pool, origins ...string) *PostgresStore {
	var origin string
	if len(origins) > 0 {
		origin = origins[0]
	}
	if origin == "" {
		origin = uuid.NewString()
	}
	return &PostgresStore{db: db, origin: origin}
}

func (s *PostgresStore) Append(ctx context.Context, event Event) (Event, error) {
	if s == nil || s.db == nil {
		return event, fmt.Errorf("sse postgres store is not configured")
	}
	if event.GroupID == "" {
		return event, fmt.Errorf("sse event group_id is required")
	}
	if len(event.Payload) == 0 {
		event.Payload = []byte("null")
	}
	var id int64
	var version int
	var origin string
	var createdAt time.Time
	err := s.db.QueryRow(ctx, `
		INSERT INTO sse_events (group_id, event_type, payload, origin)
		VALUES ($1, $2, $3::jsonb, $4)
		RETURNING id, version, origin, created_at`,
		event.GroupID, event.Type, []byte(event.Payload), s.origin,
	).Scan(&id, &version, &origin, &createdAt)
	if err != nil {
		return event, err
	}
	event.ID = strconv.FormatInt(id, 10)
	event.Version = version
	event.Origin = origin
	event.Time = createdAt
	event.Transient = false
	if s.appends.Add(1)%256 == 0 {
		// Keep the append-only log bounded. A cursor older than this retention
		// window is detected by ListAfter and reported as ErrCursorExpired.
		var deletedThrough *int64
		if err := s.db.QueryRow(ctx, `
			WITH deleted AS (
				DELETE FROM sse_events
				WHERE created_at < NOW() - INTERVAL '30 days'
				RETURNING id
			)
			SELECT MAX(id) FROM deleted`).Scan(&deletedThrough); err == nil && deletedThrough != nil {
			_, _ = s.db.Exec(ctx, `
				UPDATE sse_event_retention
				SET floor_id = GREATEST(floor_id, $1)
				WHERE singleton`, *deletedThrough)
		}
	}
	// The migration trigger emits pg_notify after this INSERT commits. Do not
	// issue a second notification here: doing so would duplicate fan-out on
	// every API instance.
	return event, nil
}

func (s *PostgresStore) ListAfter(ctx context.Context, groupID, afterID string, limit int) ([]Event, error) {
	if s == nil || s.db == nil {
		return nil, fmt.Errorf("sse postgres store is not configured")
	}
	if limit <= 0 {
		limit = 1000
	}
	after, err := strconv.ParseInt(afterID, 10, 64)
	if err != nil || after < 0 {
		return nil, fmt.Errorf("invalid sse cursor %q", afterID)
	}
	if after > 0 {
		var floor int64
		if err := s.db.QueryRow(ctx, `SELECT floor_id FROM sse_event_retention WHERE singleton`).Scan(&floor); err != nil {
			return nil, err
		}
		if after < floor {
			return nil, ErrCursorExpired
		}
		var oldest *int64
		if err := s.db.QueryRow(ctx, `SELECT MIN(id) FROM sse_events`).Scan(&oldest); err != nil {
			return nil, err
		}
		if oldest != nil && after < *oldest-1 {
			return nil, ErrCursorExpired
		}
	}
	rows, err := s.db.Query(ctx, `
		SELECT id, version, origin, created_at, event_type, group_id::text, payload
		FROM sse_events
		WHERE group_id = $1 AND id > $2
		ORDER BY id ASC
		LIMIT $3`, groupID, after, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanEvents(rows)
}

func (s *PostgresStore) get(ctx context.Context, id string) (Event, error) {
	if s == nil || s.db == nil {
		return Event{}, fmt.Errorf("sse postgres store is not configured")
	}
	return getEvent(ctx, s.db, id)
}

type rowQuerier interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}

func getEvent(ctx context.Context, db rowQuerier, id string) (Event, error) {
	n, err := strconv.ParseInt(id, 10, 64)
	if err != nil || n < 0 {
		return Event{}, fmt.Errorf("invalid sse event id %q", id)
	}
	var event Event
	err = db.QueryRow(ctx, `
		SELECT id, version, origin, created_at, event_type, group_id::text, payload
		FROM sse_events WHERE id = $1`, n).Scan(
		&n, &event.Version, &event.Origin, &event.Time, &event.Type,
		&event.GroupID, &event.Payload,
	)
	if err != nil {
		return Event{}, err
	}
	event.ID = strconv.FormatInt(n, 10)
	return event, nil
}

// Watch listens for cross-instance event notifications. The listener is
// automatically re-established after a connection failure.
func (s *PostgresStore) Watch(ctx context.Context) (<-chan Event, error) {
	if s == nil || s.db == nil {
		return nil, fmt.Errorf("sse postgres store is not configured")
	}
	out := make(chan Event, 128)
	go func() {
		defer close(out)
		for ctx.Err() == nil {
			conn, err := s.db.Acquire(ctx)
			if err != nil {
				return
			}
			_, err = conn.Exec(ctx, "LISTEN "+postgresNotifyChannel)
			if err != nil {
				conn.Release()
				return
			}
			for ctx.Err() == nil {
				notification, waitErr := conn.Conn().WaitForNotification(ctx)
				if waitErr != nil {
					break
				}
				event, getErr := getEvent(ctx, conn, notification.Payload)
				if getErr != nil {
					if getErr == pgx.ErrNoRows {
						continue
					}
					break
				}
				select {
				case out <- event:
				case <-ctx.Done():
					conn.Release()
					return
				}
			}
			conn.Release()
			if ctx.Err() == nil {
				timer := time.NewTimer(time.Second)
				select {
				case <-timer.C:
				case <-ctx.Done():
					timer.Stop()
				}
			}
		}
	}()
	return out, nil
}

type rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}

func scanEvents(rows rows) ([]Event, error) {
	var events []Event
	for rows.Next() {
		var id int64
		var version int
		var event Event
		if err := rows.Scan(&id, &version, &event.Origin, &event.Time, &event.Type, &event.GroupID, &event.Payload); err != nil {
			return nil, err
		}
		event.ID = strconv.FormatInt(id, 10)
		event.Version = version
		events = append(events, event)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return events, nil
}
