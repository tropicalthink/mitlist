package repositories

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// DeviceSyncEvent is one uploaded event of a device connection, naming its
// calendar by the device's own calendar id.
type DeviceSyncEvent struct {
	CalendarExternalID string
	Event              models.ExternalEvent
}

// ICSSyncRecord is the outcome of one ICS fetch, written to the connection.
type ICSSyncRecord struct {
	AttemptAt     time.Time
	Succeeded     bool
	ErrorCode     *string
	ETag          *string
	LastModified  *string
	FailureCount  int
	NextAttemptAt time.Time
}

// ExternalCalendarRepository stores members' synced calendars (plans: shared
// household calendars, migration 000082).
type ExternalCalendarRepository struct{ db DBTX }

func NewExternalCalendarRepository(db DBTX) *ExternalCalendarRepository {
	return &ExternalCalendarRepository{db: db}
}

const connectionColumns = `id, user_id, kind, name, device_id, ics_url_encrypted, last_synced_at, last_error,
	http_etag, http_last_modified, last_attempt_at, failure_count, next_attempt_at, content_hash, created_at, updated_at`

func scanConnection(row pgx.Row) (*models.CalendarConnection, error) {
	var c models.CalendarConnection
	if err := row.Scan(&c.ID, &c.UserID, &c.Kind, &c.Name, &c.DeviceID, &c.ICSURLEncrypted, &c.LastSyncedAt, &c.LastError,
		&c.HTTPETag, &c.HTTPLastModified, &c.LastAttemptAt, &c.FailureCount, &c.NextAttemptAt, &c.ContentHash,
		&c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	c.Calendars = []models.ExternalCalendar{}
	return &c, nil
}

func (r *ExternalCalendarRepository) CountConnections(ctx context.Context, userID uuid.UUID) (int, error) {
	var n int
	err := r.db.QueryRow(ctx, `SELECT count(*) FROM calendar_connections WHERE user_id = $1`, userID).Scan(&n)
	return n, err
}

// GetConnection returns the user's connection id (pgx.ErrNoRows when it is
// someone else's or gone), with its calendars and shares.
func (r *ExternalCalendarRepository) GetConnection(ctx context.Context, id, userID uuid.UUID) (*models.CalendarConnection, error) {
	c, err := scanConnection(r.db.QueryRow(ctx,
		`SELECT `+connectionColumns+` FROM calendar_connections WHERE id = $1 AND user_id = $2`, id, userID))
	if err != nil {
		return nil, err
	}
	cals, err := r.listCalendars(ctx, userID, &id)
	if err != nil {
		return nil, err
	}
	c.Calendars = cals
	return c, nil
}

// GetDeviceConnection returns the user's connection for deviceID, or
// pgx.ErrNoRows.
func (r *ExternalCalendarRepository) GetDeviceConnection(ctx context.Context, userID uuid.UUID, deviceID string) (*models.CalendarConnection, error) {
	c, err := scanConnection(r.db.QueryRow(ctx,
		`SELECT `+connectionColumns+` FROM calendar_connections WHERE user_id = $1 AND kind = 'device' AND device_id = $2`,
		userID, deviceID))
	if err != nil {
		return nil, err
	}
	return r.GetConnection(ctx, c.ID, userID)
}

// ListConnections returns all of the user's connections with calendars and
// shares, oldest first.
func (r *ExternalCalendarRepository) ListConnections(ctx context.Context, userID uuid.UUID) ([]models.CalendarConnection, error) {
	rows, err := r.db.Query(ctx,
		`SELECT `+connectionColumns+` FROM calendar_connections WHERE user_id = $1 ORDER BY created_at, id`, userID)
	if err != nil {
		return nil, err
	}
	var out []models.CalendarConnection
	index := map[uuid.UUID]int{}
	for rows.Next() {
		c, err := scanConnection(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		index[c.ID] = len(out)
		out = append(out, *c)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	cals, err := r.listCalendars(ctx, userID, nil)
	if err != nil {
		return nil, err
	}
	for _, cal := range cals {
		if i, ok := index[cal.ConnectionID]; ok {
			out[i].Calendars = append(out[i].Calendars, cal)
		}
	}
	if out == nil {
		out = []models.CalendarConnection{}
	}
	return out, nil
}

// listCalendars returns the user's calendars (of one connection when
// connID is set) with their shares. Shares with households the user no
// longer belongs to are left out: they show nothing.
func (r *ExternalCalendarRepository) listCalendars(ctx context.Context, userID uuid.UUID, connID *uuid.UUID) ([]models.ExternalCalendar, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, connection_id, user_id, external_id, name, color
		FROM external_calendars
		WHERE user_id = $1 AND ($2::uuid IS NULL OR connection_id = $2)
		ORDER BY name, id`, userID, connID)
	if err != nil {
		return nil, err
	}
	var cals []models.ExternalCalendar
	index := map[uuid.UUID]int{}
	for rows.Next() {
		var c models.ExternalCalendar
		if err := rows.Scan(&c.ID, &c.ConnectionID, &c.UserID, &c.ExternalID, &c.Name, &c.Color); err != nil {
			rows.Close()
			return nil, err
		}
		c.Shares = []models.CalendarShare{}
		index[c.ID] = len(cals)
		cals = append(cals, c)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(cals) == 0 {
		return cals, nil
	}
	ids := make([]uuid.UUID, 0, len(cals))
	for _, c := range cals {
		ids = append(ids, c.ID)
	}
	srows, err := r.db.Query(ctx, `
		SELECT s.calendar_id, s.group_id, s.visibility
		FROM external_calendar_shares s
		JOIN group_memberships gm ON gm.group_id = s.group_id AND gm.user_id = $2
		     AND gm.left_at IS NULL AND gm.role IN ('admin', 'member')
		WHERE s.calendar_id = ANY($1)
		ORDER BY s.created_at, s.group_id`, ids, userID)
	if err != nil {
		return nil, err
	}
	defer srows.Close()
	for srows.Next() {
		var calID uuid.UUID
		var s models.CalendarShare
		if err := srows.Scan(&calID, &s.GroupID, &s.Visibility); err != nil {
			return nil, err
		}
		if i, ok := index[calID]; ok {
			cals[i].Shares = append(cals[i].Shares, s)
		}
	}
	return cals, srows.Err()
}

// CreateICSConnection inserts an ICS connection with its one calendar and
// first events.
func (r *ExternalCalendarRepository) CreateICSConnection(ctx context.Context, c *models.CalendarConnection, cal *models.ExternalCalendar, events []models.ExternalEvent) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `
		INSERT INTO calendar_connections (id, user_id, kind, name, ics_url_encrypted, last_synced_at, http_etag,
			http_last_modified, last_attempt_at, next_attempt_at, content_hash)
		VALUES ($1, $2, 'ics', $3, $4, $5, $6, $7, $8, $9, $10)`,
		c.ID, c.UserID, c.Name, c.ICSURLEncrypted, c.LastSyncedAt, c.HTTPETag, c.HTTPLastModified,
		c.LastAttemptAt, c.NextAttemptAt, c.ContentHash); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO external_calendars (id, connection_id, user_id, external_id, name, color)
		VALUES ($1, $2, $3, $4, $5, $6)`, cal.ID, c.ID, c.UserID, cal.ExternalID, cal.Name, cal.Color); err != nil {
		return err
	}
	if err := copyEvents(ctx, tx, events); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// CreateDeviceConnection inserts a device connection. A concurrent insert
// for the same device surfaces as a unique violation.
func (r *ExternalCalendarRepository) CreateDeviceConnection(ctx context.Context, c *models.CalendarConnection) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO calendar_connections (id, user_id, kind, name, device_id)
		VALUES ($1, $2, 'device', $3, $4)`, c.ID, c.UserID, c.Name, c.DeviceID)
	return err
}

func (r *ExternalCalendarRepository) UpdateConnectionName(ctx context.Context, id, userID uuid.UUID, name string) (bool, error) {
	tag, err := r.db.Exec(ctx, `
		UPDATE calendar_connections SET name = $3, updated_at = now() WHERE id = $1 AND user_id = $2`, id, userID, name)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// DeleteConnection removes a connection; calendars, shares, events and
// overrides go with it (FK cascade).
func (r *ExternalCalendarRepository) DeleteConnection(ctx context.Context, id, userID uuid.UUID) (bool, error) {
	tag, err := r.db.Exec(ctx, `DELETE FROM calendar_connections WHERE id = $1 AND user_id = $2`, id, userID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// GetCalendar returns the user's calendar id with its shares, or
// pgx.ErrNoRows.
func (r *ExternalCalendarRepository) GetCalendar(ctx context.Context, id, userID uuid.UUID) (*models.ExternalCalendar, error) {
	var connID uuid.UUID
	if err := r.db.QueryRow(ctx, `SELECT connection_id FROM external_calendars WHERE id = $1 AND user_id = $2`, id, userID).Scan(&connID); err != nil {
		return nil, err
	}
	cals, err := r.listCalendars(ctx, userID, &connID)
	if err != nil {
		return nil, err
	}
	for i := range cals {
		if cals[i].ID == id {
			return &cals[i], nil
		}
	}
	return nil, pgx.ErrNoRows
}

// ListShareGroupsForConnection returns the households any calendar of the
// connection is shared with.
func (r *ExternalCalendarRepository) ListShareGroupsForConnection(ctx context.Context, connID uuid.UUID) ([]uuid.UUID, error) {
	return r.listUUIDs(ctx, `
		SELECT DISTINCT s.group_id FROM external_calendar_shares s
		JOIN external_calendars c ON c.id = s.calendar_id
		WHERE c.connection_id = $1`, connID)
}

// ListShareGroupsForCalendar returns the households a calendar is shared with.
func (r *ExternalCalendarRepository) ListShareGroupsForCalendar(ctx context.Context, calendarID uuid.UUID) ([]uuid.UUID, error) {
	return r.listUUIDs(ctx, `SELECT group_id FROM external_calendar_shares WHERE calendar_id = $1`, calendarID)
}

func (r *ExternalCalendarRepository) listUUIDs(ctx context.Context, query string, args ...any) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// ReplaceShares makes shares the calendar's complete share list.
func (r *ExternalCalendarRepository) ReplaceShares(ctx context.Context, calendarID uuid.UUID, shares []models.CalendarShare) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `DELETE FROM external_calendar_shares WHERE calendar_id = $1`, calendarID); err != nil {
		return err
	}
	for _, s := range shares {
		if _, err := tx.Exec(ctx, `
			INSERT INTO external_calendar_shares (calendar_id, group_id, visibility) VALUES ($1, $2, $3)`,
			calendarID, s.GroupID, s.Visibility); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// SetOverride sets (or, with a nil visibility, clears) an event override.
func (r *ExternalCalendarRepository) SetOverride(ctx context.Context, userID, calendarID uuid.UUID, externalUID string, visibility *string) error {
	if visibility == nil {
		_, err := r.db.Exec(ctx, `
			DELETE FROM external_event_overrides WHERE calendar_id = $1 AND external_uid = $2 AND user_id = $3`,
			calendarID, externalUID, userID)
		return err
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO external_event_overrides (user_id, calendar_id, external_uid, visibility)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (calendar_id, external_uid) DO UPDATE SET visibility = EXCLUDED.visibility, updated_at = now()`,
		userID, calendarID, externalUID, *visibility)
	return err
}

// ListOverrides returns all of the user's event overrides, on calendars
// the user owns.
func (r *ExternalCalendarRepository) ListOverrides(ctx context.Context, userID uuid.UUID) ([]models.EventOverride, error) {
	rows, err := r.db.Query(ctx, `
		SELECT o.calendar_id, o.external_uid, o.visibility
		FROM external_event_overrides o
		JOIN external_calendars c ON c.id = o.calendar_id AND c.user_id = $1
		WHERE o.user_id = $1
		ORDER BY o.calendar_id, o.external_uid`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.EventOverride{}
	for rows.Next() {
		var o models.EventOverride
		if err := rows.Scan(&o.CalendarID, &o.ExternalUID, &o.Visibility); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// ReplaceCalendarEvents replaces every event of calendarID and records the
// connection's new content hash (nil clears it).
func (r *ExternalCalendarRepository) ReplaceCalendarEvents(ctx context.Context, connID, calendarID uuid.UUID, events []models.ExternalEvent, hash *string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, `DELETE FROM external_events WHERE calendar_id = $1`, calendarID); err != nil {
		return err
	}
	if err := copyEvents(ctx, tx, events); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE calendar_connections SET content_hash = $2, updated_at = now() WHERE id = $1`, connID, hash); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// DeviceSync applies a device upload as a full replace: the listed
// calendars are upserted by external id (keeping their ids, shares and
// overrides), unlisted ones are deleted, and the connection's events are
// replaced.
func (r *ExternalCalendarRepository) DeviceSync(ctx context.Context, connID, userID uuid.UUID, calendars []models.ExternalCalendar, events []DeviceSyncEvent, hash string, syncedAt time.Time) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	ids := make(map[string]uuid.UUID, len(calendars))
	keep := make([]string, 0, len(calendars))
	for _, c := range calendars {
		var id uuid.UUID
		if err := tx.QueryRow(ctx, `
			INSERT INTO external_calendars (id, connection_id, user_id, external_id, name, color)
			VALUES ($1, $2, $3, $4, $5, $6)
			ON CONFLICT (connection_id, external_id)
			DO UPDATE SET name = EXCLUDED.name, color = EXCLUDED.color, updated_at = now()
			RETURNING id`, uuid.New(), connID, userID, c.ExternalID, c.Name, c.Color).Scan(&id); err != nil {
			return err
		}
		ids[c.ExternalID] = id
		keep = append(keep, c.ExternalID)
	}
	if _, err := tx.Exec(ctx, `
		DELETE FROM external_calendars WHERE connection_id = $1 AND NOT (external_id = ANY($2))`, connID, keep); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		DELETE FROM external_events WHERE calendar_id IN (SELECT id FROM external_calendars WHERE connection_id = $1)`, connID); err != nil {
		return err
	}
	rows := make([]models.ExternalEvent, 0, len(events))
	for _, e := range events {
		id, ok := ids[e.CalendarExternalID]
		if !ok {
			continue
		}
		ev := e.Event
		ev.CalendarID = id
		ev.UserID = userID
		rows = append(rows, ev)
	}
	if err := copyEvents(ctx, tx, rows); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE calendar_connections SET content_hash = $2, last_synced_at = $3, last_error = NULL, updated_at = now()
		WHERE id = $1`, connID, hash, syncedAt); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func copyEvents(ctx context.Context, tx pgx.Tx, events []models.ExternalEvent) error {
	if len(events) == 0 {
		return nil
	}
	_, err := tx.CopyFrom(ctx, pgx.Identifier{"external_events"},
		[]string{"id", "calendar_id", "user_id", "external_uid", "starts_at", "ends_at", "all_day", "title", "source_private", "free"},
		pgx.CopyFromSlice(len(events), func(i int) ([]any, error) {
			e := events[i]
			id := e.ID
			if id == uuid.Nil {
				id = uuid.New()
			}
			return []any{id, e.CalendarID, e.UserID, e.ExternalUID, e.StartsAt, e.EndsAt, e.AllDay, e.Title, e.SourcePrivate, e.Free}, nil
		}))
	return err
}

// RecordSyncResult writes an ICS fetch outcome. On success the error clears
// and last_synced_at moves; on failure the stored events stay.
func (r *ExternalCalendarRepository) RecordSyncResult(ctx context.Context, id uuid.UUID, rec ICSSyncRecord) error {
	if rec.Succeeded {
		_, err := r.db.Exec(ctx, `
			UPDATE calendar_connections
			SET last_attempt_at = $2, last_synced_at = $2, last_error = NULL, failure_count = 0,
			    next_attempt_at = $3, http_etag = $4, http_last_modified = $5, updated_at = now()
			WHERE id = $1`, id, rec.AttemptAt, rec.NextAttemptAt, rec.ETag, rec.LastModified)
		return err
	}
	_, err := r.db.Exec(ctx, `
		UPDATE calendar_connections
		SET last_attempt_at = $2, last_error = $3, failure_count = $4, next_attempt_at = $5, updated_at = now()
		WHERE id = $1`, id, rec.AttemptAt, rec.ErrorCode, rec.FailureCount, rec.NextAttemptAt)
	return err
}

// ClaimAttempt stamps last_attempt_at when the previous attempt is at
// least minGap old, so two manual syncs cannot run back to back. It reports
// whether the claim succeeded.
func (r *ExternalCalendarRepository) ClaimAttempt(ctx context.Context, id uuid.UUID, now time.Time, minGap time.Duration) (bool, error) {
	tag, err := r.db.Exec(ctx, `
		UPDATE calendar_connections SET last_attempt_at = $2
		WHERE id = $1 AND (last_attempt_at IS NULL OR last_attempt_at <= $3)`, id, now, now.Add(-minGap))
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// ListDueICSConnections returns ICS connections whose next attempt is due.
func (r *ExternalCalendarRepository) ListDueICSConnections(ctx context.Context, now time.Time, limit int) ([]models.CalendarConnection, error) {
	rows, err := r.db.Query(ctx, `SELECT `+connectionColumns+` FROM calendar_connections
		WHERE kind = 'ics' AND (next_attempt_at IS NULL OR next_attempt_at <= $1)
		ORDER BY next_attempt_at NULLS FIRST LIMIT $2`, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.CalendarConnection
	for rows.Next() {
		c, err := scanConnection(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

// ListCalendarIDs returns the calendar ids of a connection.
func (r *ExternalCalendarRepository) ListCalendarIDs(ctx context.Context, connID uuid.UUID) ([]uuid.UUID, error) {
	return r.listUUIDs(ctx, `SELECT id FROM external_calendars WHERE connection_id = $1`, connID)
}

// ListOwnEvents returns the user's stored events overlapping [from, to),
// with titles and overrides: the owner's own view.
func (r *ExternalCalendarRepository) ListOwnEvents(ctx context.Context, userID uuid.UUID, from, to time.Time) ([]models.OwnEvent, error) {
	rows, err := r.db.Query(ctx, `
		SELECT e.calendar_id, e.external_uid, e.starts_at, e.ends_at, e.all_day, e.title, e.source_private, e.free, o.visibility
		FROM external_events e
		JOIN external_calendars c ON c.id = e.calendar_id AND c.user_id = $1
		LEFT JOIN external_event_overrides o ON o.calendar_id = e.calendar_id AND o.external_uid = e.external_uid
		WHERE e.user_id = $1 AND e.starts_at < $3 AND (e.ends_at > $2 OR (e.ends_at = e.starts_at AND e.starts_at >= $2))
		ORDER BY e.starts_at, e.external_uid
		LIMIT 20000`, userID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.OwnEvent{}
	for rows.Next() {
		var e models.OwnEvent
		if err := rows.Scan(&e.CalendarID, &e.ExternalUID, &e.StartsAt, &e.EndsAt, &e.AllDay, &e.Title, &e.SourcePrivate, &e.Free, &e.Override); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// ListHouseholdEvents returns the events of calendars shared with groupID
// overlapping [from, to), with the share, the override and whether the
// owner is a current member of groupID (an active account with an admin or
// member role). The visibility rule is applied by the caller.
func (r *ExternalCalendarRepository) ListHouseholdEvents(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.HouseholdExternalEvent, error) {
	rows, err := r.db.Query(ctx, `
		SELECT e.id, e.calendar_id, c.user_id, e.external_uid, e.starts_at, e.ends_at, e.all_day, e.title,
		       e.source_private, e.free, s.visibility, o.visibility,
		       (gm.id IS NOT NULL AND u.deleted_at IS NULL) AS owner_is_member
		FROM external_calendar_shares s
		JOIN external_calendars c ON c.id = s.calendar_id
		JOIN external_events e ON e.calendar_id = c.id
		JOIN users u ON u.id = c.user_id
		LEFT JOIN group_memberships gm ON gm.group_id = s.group_id AND gm.user_id = c.user_id
		     AND gm.left_at IS NULL AND gm.role IN ('admin', 'member')
		LEFT JOIN external_event_overrides o ON o.calendar_id = e.calendar_id AND o.external_uid = e.external_uid
		WHERE s.group_id = $1 AND e.starts_at < $3 AND (e.ends_at > $2 OR (e.ends_at = e.starts_at AND e.starts_at >= $2))
		ORDER BY e.starts_at, e.id
		LIMIT 20000`, groupID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.HouseholdExternalEvent
	for rows.Next() {
		var h models.HouseholdExternalEvent
		e := &h.Event
		if err := rows.Scan(&e.ID, &e.CalendarID, &e.UserID, &e.ExternalUID, &e.StartsAt, &e.EndsAt, &e.AllDay, &e.Title,
			&e.SourcePrivate, &e.Free, &h.ShareVisibility, &h.Override, &h.OwnerIsMember); err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// TrimEvents deletes events that ended before before or start after after.
func (r *ExternalCalendarRepository) TrimEvents(ctx context.Context, before, after time.Time) (int64, error) {
	tag, err := r.db.Exec(ctx, `DELETE FROM external_events WHERE ends_at < $1 OR starts_at > $2`, before, after)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
