package services

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services/ical"
	"github.com/mitlist-app/mitlist/internal/sse"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Limits and timings of shared household calendars (see the contract).
const (
	maxCalendarConnections   = 10
	maxCalendarsPerConn      = 50
	maxEventsPerConn         = 5000
	maxSharesPerCalendar     = 50
	maxExternalTitleRunes    = 200
	maxConnectionNameRunes   = 100
	maxCalendarNameRunes     = 200
	maxExternalIDLength      = 512
	maxExternalUIDLength     = 1024
	maxDeviceIDLength        = 200
	maxColorLength           = 32
	externalWindowBefore     = 24 * time.Hour
	externalWindowAfter      = 90 * 24 * time.Hour
	manualSyncMinGap         = 60 * time.Second
	icsRefreshInterval       = 25 * time.Minute
	icsMaxBackoff            = 24 * time.Hour
	icsRefreshBatch          = 500
	icsRefreshConcurrency    = 4
	icsRefreshPerConnTimeout = 45 * time.Second
	// EventCalendarExternalChanged tells a household to refetch what it
	// sees of a member's calendar.
	EventCalendarExternalChanged = "calendar:external_changed"
)

// ErrSyncTooSoon refuses a manual sync less than a minute after the last
// attempt.
var ErrSyncTooSoon = errors.New("calendar synced less than a minute ago")

// ExternalCalendarService owns members' synced calendars: connections, the
// ICS poller, device uploads, household shares, per-event overrides and
// what each household may see.
type ExternalCalendarService struct {
	repo    repositories.ExternalCalendarRepo
	groups  GroupMembershipChecker
	sealer  *icsURLSealer
	fetcher ICSFetcher
	hub     *sse.Hub
	log     *logger.Logger
	now     func() time.Time
}

// NewExternalCalendarService builds the service; secretKey is the server's
// SECRET_KEY, from which the ICS URL encryption key is derived.
func NewExternalCalendarService(repo repositories.ExternalCalendarRepo, groups GroupMembershipChecker, secretKey string) (*ExternalCalendarService, error) {
	sealer, err := newICSURLSealer(secretKey)
	if err != nil {
		return nil, err
	}
	return &ExternalCalendarService{
		repo:    repo,
		groups:  groups,
		sealer:  sealer,
		fetcher: NewICSFetcher(),
		now:     time.Now,
	}, nil
}

// SetHub injects the SSE hub for calendar:external_changed events.
func (s *ExternalCalendarService) SetHub(h *sse.Hub) { s.hub = h }

// SetFetcher replaces the ICS fetcher (tests).
func (s *ExternalCalendarService) SetFetcher(f ICSFetcher) { s.fetcher = f }

// SetLogger injects the logger used by the refresh job.
func (s *ExternalCalendarService) SetLogger(l *logger.Logger) { s.log = l }

// SetClock replaces the clock (tests).
func (s *ExternalCalendarService) SetClock(now func() time.Time) { s.now = now }

func (s *ExternalCalendarService) window() (time.Time, time.Time) {
	now := s.now().UTC()
	return now.Add(-externalWindowBefore), now.Add(externalWindowAfter)
}

func notFoundIfNoRows(err error, resource string) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return &api.NotFoundError{Resource: resource}
	}
	return err
}

func cleanName(raw, field string, maxRunes int, required bool) (string, error) {
	name := strings.Join(strings.Fields(strings.ToValidUTF8(raw, "")), " ")
	if name == "" && required {
		return "", &api.ValidationError{Field: field, Message: field + " is required"}
	}
	if utf8.RuneCountInString(name) > maxRunes {
		return "", &api.ValidationError{Field: field, Message: fmt.Sprintf("%s must be at most %d characters", field, maxRunes)}
	}
	return name, nil
}

func cutTitle(t *string) *string {
	if t == nil {
		return nil
	}
	v := strings.Join(strings.Fields(strings.ToValidUTF8(*t, "")), " ")
	if v == "" {
		return nil
	}
	if utf8.RuneCountInString(v) > maxExternalTitleRunes {
		v = strings.TrimSpace(string([]rune(v)[:maxExternalTitleRunes]))
	}
	return &v
}

func (s *ExternalCalendarService) publish(userID uuid.UUID, groups ...[]uuid.UUID) {
	seen := map[uuid.UUID]bool{}
	for _, list := range groups {
		for _, g := range list {
			if seen[g] {
				continue
			}
			seen[g] = true
			publishDomainEvent(s.hub, EventCalendarExternalChanged, g, map[string]string{"user_id": userID.String()})
		}
	}
}

// ---------------------------------------------------------------------------
// Connections
// ---------------------------------------------------------------------------

// ListConnections returns the caller's connections.
func (s *ExternalCalendarService) ListConnections(ctx context.Context, userID uuid.UUID) ([]models.CalendarConnection, error) {
	return s.repo.ListConnections(ctx, userID)
}

func (s *ExternalCalendarService) getConnection(ctx context.Context, userID, id uuid.UUID) (*models.CalendarConnection, error) {
	c, err := s.repo.GetConnection(ctx, id, userID)
	if err != nil {
		return nil, notFoundIfNoRows(err, "calendar connection")
	}
	return c, nil
}

func (s *ExternalCalendarService) checkConnectionLimit(ctx context.Context, userID uuid.UUID) error {
	n, err := s.repo.CountConnections(ctx, userID)
	if err != nil {
		return err
	}
	if n >= maxCalendarConnections {
		return &api.ValidationError{Message: fmt.Sprintf("at most %d calendar connections", maxCalendarConnections)}
	}
	return nil
}

// CreateICSConnection subscribes to an ICS link: it fetches and parses the
// feed first (a *CalendarSyncError when that fails, and nothing is
// stored), then stores the connection with its encrypted URL and events.
func (s *ExternalCalendarService) CreateICSConnection(ctx context.Context, userID uuid.UUID, name, rawURL string) (*models.CalendarConnection, error) {
	link, err := normalizeICSURL(rawURL)
	if err != nil {
		return nil, err
	}
	name, err = cleanName(name, "name", maxConnectionNameRunes, false)
	if err != nil {
		return nil, err
	}
	if err := s.checkConnectionLimit(ctx, userID); err != nil {
		return nil, err
	}
	res, err := s.fetcher.Fetch(ctx, link, "", "")
	if err != nil {
		return nil, asSyncError(err)
	}
	if res.NotModified {
		return nil, syncErr(models.CalendarErrFetchFailed)
	}
	connID, calID := uuid.New(), uuid.New()
	parsed, events, hash, err := s.parseFeed(res.Body, calID, userID)
	if err != nil {
		return nil, err
	}
	if name == "" {
		name, _ = cleanName(parsed.Name, "name", maxConnectionNameRunes, false)
		if name == "" {
			name = "Calendar"
		}
	}
	sealed, err := s.sealer.seal(connID, link)
	if err != nil {
		return nil, err
	}
	now := s.now().UTC()
	next := now.Add(icsRefreshInterval)
	conn := &models.CalendarConnection{
		ID: connID, UserID: userID, Kind: models.CalendarConnectionICS, Name: name,
		ICSURLEncrypted: sealed, LastSyncedAt: &now, LastAttemptAt: &now, NextAttemptAt: &next, ContentHash: &hash,
		HTTPETag: nonEmpty(res.ETag), HTTPLastModified: nonEmpty(res.LastModified),
	}
	cal := &models.ExternalCalendar{ID: calID, ConnectionID: connID, UserID: userID, ExternalID: "ics", Name: name}
	if parsed.Color != "" {
		color := parsed.Color
		cal.Color = &color
	}
	if err := s.repo.CreateICSConnection(ctx, conn, cal, events); err != nil {
		return nil, err
	}
	return s.getConnection(ctx, userID, connID)
}

func nonEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// parseFeed reads an ICS body into the stored rows of calendarID and their
// content hash.
func (s *ExternalCalendarService) parseFeed(body []byte, calendarID, userID uuid.UUID) (*ical.Calendar, []models.ExternalEvent, string, error) {
	from, to := s.window()
	parsed, err := ical.Parse(body, from, to, ical.Limits{MaxEvents: maxEventsPerConn, MaxTitleRunes: maxExternalTitleRunes})
	if err != nil {
		return nil, nil, "", syncErr(models.CalendarErrNotCalendar)
	}
	events := make([]models.ExternalEvent, 0, len(parsed.Events))
	for _, o := range parsed.Events {
		var title *string
		if o.Title != "" {
			t := o.Title
			title = &t
		}
		events = append(events, models.ExternalEvent{
			ID: uuid.New(), CalendarID: calendarID, UserID: userID, ExternalUID: o.UID,
			StartsAt: o.Start, EndsAt: o.End, AllDay: o.AllDay, Title: title,
			SourcePrivate: o.Private, Free: o.Free,
		})
	}
	return parsed, events, eventsHash(nil, events), nil
}

// eventsHash fingerprints what a sync stored, to tell whether it changed.
func eventsHash(calendars []models.ExternalCalendar, events []models.ExternalEvent) string {
	lines := make([]string, 0, len(calendars)+len(events))
	for _, c := range calendars {
		color := ""
		if c.Color != nil {
			color = *c.Color
		}
		lines = append(lines, "c\x00"+c.ExternalID+"\x00"+c.Name+"\x00"+color)
	}
	for _, e := range events {
		title := "\x01"
		if e.Title != nil {
			title = *e.Title
		}
		lines = append(lines, fmt.Sprintf("e\x00%s\x00%s\x00%d\x00%d\x00%t\x00%s\x00%t\x00%t",
			e.CalendarID, e.ExternalUID, e.StartsAt.Unix(), e.EndsAt.Unix(), e.AllDay, title, e.SourcePrivate, e.Free))
	}
	sort.Strings(lines)
	h := sha256.New()
	for _, l := range lines {
		h.Write([]byte(l))
		h.Write([]byte{'\n'})
	}
	return hex.EncodeToString(h.Sum(nil))
}

// UpsertDeviceConnection returns the caller's connection for deviceID,
// creating it (created = true) or renaming it.
func (s *ExternalCalendarService) UpsertDeviceConnection(ctx context.Context, userID uuid.UUID, name, deviceID string) (*models.CalendarConnection, bool, error) {
	deviceID = strings.TrimSpace(deviceID)
	if deviceID == "" || len(deviceID) > maxDeviceIDLength {
		return nil, false, &api.ValidationError{Field: "device_id", Message: "device_id is required"}
	}
	name, err := cleanName(name, "name", maxConnectionNameRunes, false)
	if err != nil {
		return nil, false, err
	}
	if name == "" {
		name = "This phone"
	}
	existing, err := s.repo.GetDeviceConnection(ctx, userID, deviceID)
	if err == nil {
		if existing.Name != name {
			if _, err := s.repo.UpdateConnectionName(ctx, existing.ID, userID, name); err != nil {
				return nil, false, err
			}
			existing.Name = name
		}
		return existing, false, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, false, err
	}
	if err := s.checkConnectionLimit(ctx, userID); err != nil {
		return nil, false, err
	}
	conn := &models.CalendarConnection{ID: uuid.New(), UserID: userID, Kind: models.CalendarConnectionDevice, Name: name, DeviceID: &deviceID}
	if err := s.repo.CreateDeviceConnection(ctx, conn); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
			// Raced with another upsert from the same device.
			existing, gerr := s.repo.GetDeviceConnection(ctx, userID, deviceID)
			if gerr != nil {
				return nil, false, gerr
			}
			return existing, false, nil
		}
		return nil, false, err
	}
	created, err := s.getConnection(ctx, userID, conn.ID)
	return created, true, err
}

// RenameConnection renames one of the caller's connections.
func (s *ExternalCalendarService) RenameConnection(ctx context.Context, userID, id uuid.UUID, name string) (*models.CalendarConnection, error) {
	name, err := cleanName(name, "name", maxConnectionNameRunes, true)
	if err != nil {
		return nil, err
	}
	ok, err := s.repo.UpdateConnectionName(ctx, id, userID, name)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, &api.NotFoundError{Resource: "calendar connection"}
	}
	return s.getConnection(ctx, userID, id)
}

// DeleteConnection removes a connection with everything synced through it.
func (s *ExternalCalendarService) DeleteConnection(ctx context.Context, userID, id uuid.UUID) error {
	if _, err := s.getConnection(ctx, userID, id); err != nil {
		return err
	}
	groups, err := s.repo.ListShareGroupsForConnection(ctx, id)
	if err != nil {
		return err
	}
	ok, err := s.repo.DeleteConnection(ctx, id, userID)
	if err != nil {
		return err
	}
	if !ok {
		return &api.NotFoundError{Resource: "calendar connection"}
	}
	s.publish(userID, groups)
	return nil
}

// ---------------------------------------------------------------------------
// ICS sync
// ---------------------------------------------------------------------------

// SyncNow refetches one of the caller's ICS connections.
func (s *ExternalCalendarService) SyncNow(ctx context.Context, userID, id uuid.UUID) (*models.CalendarConnection, error) {
	conn, err := s.getConnection(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if conn.Kind != models.CalendarConnectionICS {
		return nil, &api.ValidationError{Message: "only ics connections sync on the server"}
	}
	claimed, err := s.repo.ClaimAttempt(ctx, id, s.now().UTC(), manualSyncMinGap)
	if err != nil {
		return nil, err
	}
	if !claimed {
		return nil, ErrSyncTooSoon
	}
	if err := s.syncICS(ctx, conn); err != nil {
		return nil, err
	}
	return s.getConnection(ctx, userID, id)
}

// icsBackoff is the wait before retrying a feed that failed n times in a
// row: 30 minutes doubling up to a day.
func icsBackoff(n int) time.Duration {
	d := 30 * time.Minute
	for i := 1; i < n && d < icsMaxBackoff; i++ {
		d *= 2
	}
	if d > icsMaxBackoff {
		d = icsMaxBackoff
	}
	return d
}

// syncICS fetches conn's feed and records the outcome. Fetch and parse
// failures are recorded on the connection, not returned; only database
// errors are.
func (s *ExternalCalendarService) syncICS(ctx context.Context, conn *models.CalendarConnection) error {
	now := s.now().UTC()
	fail := func(code string) error {
		count := conn.FailureCount + 1
		if err := s.repo.RecordSyncResult(ctx, conn.ID, repositories.ICSSyncRecord{
			AttemptAt: now, ErrorCode: &code, FailureCount: count, NextAttemptAt: now.Add(icsBackoff(count)),
		}); err != nil {
			return err
		}
		if code == models.CalendarErrUnauthorized && conn.ContentHash != nil {
			// The link was revoked: stop showing what it used to grant.
			calIDs, err := s.repo.ListCalendarIDs(ctx, conn.ID)
			if err != nil {
				return err
			}
			for _, calID := range calIDs {
				if err := s.repo.ReplaceCalendarEvents(ctx, conn.ID, calID, nil, nil); err != nil {
					return err
				}
			}
			s.publishConnection(ctx, conn)
		}
		if s.log != nil {
			s.log.Info().Str("connection_id", conn.ID.String()).Str("code", code).Int("failures", count).Msg("calendar feed sync failed")
		}
		return nil
	}

	link, err := s.sealer.open(conn.ID, conn.ICSURLEncrypted)
	if err != nil {
		return fail(models.CalendarErrFetchFailed)
	}
	etag, lastMod := "", ""
	if conn.HTTPETag != nil {
		etag = *conn.HTTPETag
	}
	if conn.HTTPLastModified != nil {
		lastMod = *conn.HTTPLastModified
	}
	res, err := s.fetcher.Fetch(ctx, link, etag, lastMod)
	if err != nil {
		return fail(asSyncError(err).Code)
	}
	record := repositories.ICSSyncRecord{
		AttemptAt: now, Succeeded: true, NextAttemptAt: now.Add(icsRefreshInterval),
		ETag: conn.HTTPETag, LastModified: conn.HTTPLastModified,
	}
	if !res.NotModified {
		calIDs, err := s.repo.ListCalendarIDs(ctx, conn.ID)
		if err != nil {
			return err
		}
		if len(calIDs) == 0 {
			return fail(models.CalendarErrFetchFailed)
		}
		_, events, hash, err := s.parseFeed(res.Body, calIDs[0], conn.UserID)
		if err != nil {
			return fail(asSyncError(err).Code)
		}
		if conn.ContentHash == nil || *conn.ContentHash != hash {
			if err := s.repo.ReplaceCalendarEvents(ctx, conn.ID, calIDs[0], events, &hash); err != nil {
				return err
			}
			defer s.publishConnection(ctx, conn)
		}
		record.ETag, record.LastModified = nonEmpty(res.ETag), nonEmpty(res.LastModified)
	}
	return s.repo.RecordSyncResult(ctx, conn.ID, record)
}

func (s *ExternalCalendarService) publishConnection(ctx context.Context, conn *models.CalendarConnection) {
	groups, err := s.repo.ListShareGroupsForConnection(ctx, conn.ID)
	if err != nil {
		return
	}
	s.publish(conn.UserID, groups)
}

// RefreshDueICS syncs the ICS connections that are due, a few at a time.
// It returns how many it attempted.
func (s *ExternalCalendarService) RefreshDueICS(ctx context.Context) (int, error) {
	due, err := s.repo.ListDueICSConnections(ctx, s.now().UTC(), icsRefreshBatch)
	if err != nil {
		return 0, err
	}
	work := make(chan models.CalendarConnection)
	var wg sync.WaitGroup
	for i := 0; i < icsRefreshConcurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for conn := range work {
				cctx, cancel := context.WithTimeout(ctx, icsRefreshPerConnTimeout)
				if err := s.syncICS(cctx, &conn); err != nil && s.log != nil {
					s.log.Error().Err(err).Str("connection_id", conn.ID.String()).Msg("calendar feed sync could not be recorded")
				}
				cancel()
			}
		}()
	}
	for _, c := range due {
		if ctx.Err() != nil {
			break
		}
		work <- c
	}
	close(work)
	wg.Wait()
	return len(due), nil
}

// TrimEvents deletes stored events that left the window.
func (s *ExternalCalendarService) TrimEvents(ctx context.Context) (int64, error) {
	from, to := s.window()
	return s.repo.TrimEvents(ctx, from, to)
}

// ---------------------------------------------------------------------------
// Device sync
// ---------------------------------------------------------------------------

// DeviceCalendarInput is one calendar of a device upload.
type DeviceCalendarInput struct {
	ExternalID string  `json:"external_id"`
	Name       string  `json:"name"`
	Color      *string `json:"color,omitempty"`
}

// DeviceEventInput is one event of a device upload.
type DeviceEventInput struct {
	CalendarExternalID string    `json:"calendar_external_id"`
	ExternalUID        string    `json:"external_uid"`
	StartsAt           time.Time `json:"starts_at"`
	EndsAt             time.Time `json:"ends_at"`
	AllDay             bool      `json:"all_day"`
	Title              *string   `json:"title,omitempty"`
	SourcePrivate      bool      `json:"source_private"`
	Free               bool      `json:"free"`
}

// DeviceSyncInput is a full device upload.
type DeviceSyncInput struct {
	Calendars []DeviceCalendarInput `json:"calendars"`
	Events    []DeviceEventInput    `json:"events"`
}

func utcDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// DeviceSync replaces what a device connection holds with an upload.
func (s *ExternalCalendarService) DeviceSync(ctx context.Context, userID, id uuid.UUID, in DeviceSyncInput) (*models.CalendarConnection, error) {
	conn, err := s.getConnection(ctx, userID, id)
	if err != nil {
		return nil, err
	}
	if conn.Kind != models.CalendarConnectionDevice {
		return nil, &api.ValidationError{Message: "device-sync is for device connections"}
	}
	if len(in.Calendars) > maxCalendarsPerConn {
		return nil, &api.ValidationError{Field: "calendars", Message: fmt.Sprintf("at most %d calendars", maxCalendarsPerConn)}
	}
	if len(in.Events) > maxEventsPerConn {
		return nil, &api.ValidationError{Field: "events", Message: fmt.Sprintf("at most %d events", maxEventsPerConn)}
	}
	calendars := make([]models.ExternalCalendar, 0, len(in.Calendars))
	known := map[string]bool{}
	for _, c := range in.Calendars {
		extID := strings.TrimSpace(c.ExternalID)
		if extID == "" || len(extID) > maxExternalIDLength {
			return nil, &api.ValidationError{Field: "calendars.external_id", Message: "external_id is required"}
		}
		if known[extID] {
			return nil, &api.ValidationError{Field: "calendars.external_id", Message: "external_id is listed twice"}
		}
		known[extID] = true
		name, _ := cleanName(c.Name, "name", 100000, false)
		if utf8.RuneCountInString(name) > maxCalendarNameRunes {
			name = string([]rune(name)[:maxCalendarNameRunes])
		}
		if name == "" {
			name = "Calendar"
		}
		var color *string
		if c.Color != nil {
			if v := strings.TrimSpace(*c.Color); v != "" && len(v) <= maxColorLength {
				color = &v
			}
		}
		calendars = append(calendars, models.ExternalCalendar{ExternalID: extID, Name: name, Color: color})
	}

	from, to := s.window()
	events := make([]repositories.DeviceSyncEvent, 0, len(in.Events))
	seen := map[string]bool{}
	for _, e := range in.Events {
		calExt := strings.TrimSpace(e.CalendarExternalID)
		if !known[calExt] {
			return nil, &api.ValidationError{Field: "events.calendar_external_id", Message: "event names a calendar that is not listed"}
		}
		uid := strings.TrimSpace(e.ExternalUID)
		if uid == "" || len(uid) > maxExternalUIDLength {
			return nil, &api.ValidationError{Field: "events.external_uid", Message: "external_uid is required"}
		}
		if e.StartsAt.IsZero() || e.EndsAt.IsZero() {
			return nil, &api.ValidationError{Field: "events.starts_at", Message: "starts_at and ends_at are required"}
		}
		start, end := e.StartsAt.UTC(), e.EndsAt.UTC()
		if e.AllDay {
			// The dates as written (a local midnight's own date), as UTC
			// midnights, end exclusive.
			start, end = utcDate(e.StartsAt), utcDate(e.EndsAt)
			if !end.After(start) {
				end = start.AddDate(0, 0, 1)
			}
		}
		if end.Before(start) {
			return nil, &api.ValidationError{Field: "events.ends_at", Message: "ends_at is before starts_at"}
		}
		if !start.Before(to) || end.Before(from) {
			continue
		}
		key := calExt + "\x00" + uid + "\x00" + start.Format(time.RFC3339)
		if seen[key] {
			continue
		}
		seen[key] = true
		events = append(events, repositories.DeviceSyncEvent{
			CalendarExternalID: calExt,
			Event: models.ExternalEvent{
				ID: uuid.New(), UserID: userID, ExternalUID: uid, StartsAt: start, EndsAt: end, AllDay: e.AllDay,
				Title: cutTitle(e.Title), SourcePrivate: e.SourcePrivate, Free: e.Free,
			},
		})
	}

	// The hash keys events by their device calendar, which survives the
	// upsert, rather than by row id.
	hashEvents := make([]models.ExternalEvent, 0, len(events))
	for _, e := range events {
		ev := e.Event
		ev.CalendarID = uuid.NewSHA1(uuid.NameSpaceOID, []byte(e.CalendarExternalID))
		hashEvents = append(hashEvents, ev)
	}
	hash := eventsHash(calendars, hashEvents)

	before, err := s.repo.ListShareGroupsForConnection(ctx, id)
	if err != nil {
		return nil, err
	}
	if err := s.repo.DeviceSync(ctx, id, userID, calendars, events, hash, s.now().UTC()); err != nil {
		return nil, err
	}
	if conn.ContentHash == nil || *conn.ContentHash != hash {
		after, err := s.repo.ListShareGroupsForConnection(ctx, id)
		if err != nil {
			return nil, err
		}
		s.publish(userID, before, after)
	}
	return s.getConnection(ctx, userID, id)
}

// ---------------------------------------------------------------------------
// Shares and overrides
// ---------------------------------------------------------------------------

// ReplaceShares makes shares the complete share list of one of the
// caller's calendars. Every household must be one the caller belongs to.
func (s *ExternalCalendarService) ReplaceShares(ctx context.Context, userID, calendarID uuid.UUID, shares []models.CalendarShare) (*models.ExternalCalendar, error) {
	if _, err := s.repo.GetCalendar(ctx, calendarID, userID); err != nil {
		return nil, notFoundIfNoRows(err, "calendar")
	}
	if len(shares) > maxSharesPerCalendar {
		return nil, &api.ValidationError{Field: "shares", Message: "too many shares"}
	}
	seen := map[uuid.UUID]bool{}
	for _, sh := range shares {
		if sh.GroupID == uuid.Nil {
			return nil, &api.ValidationError{Field: "shares.group_id", Message: "group_id is required"}
		}
		if sh.Visibility != models.ShareVisibilityBusy && sh.Visibility != models.ShareVisibilityDetails {
			return nil, &api.ValidationError{Field: "shares.visibility", Message: "visibility must be busy or details"}
		}
		if seen[sh.GroupID] {
			return nil, &api.ValidationError{Field: "shares.group_id", Message: "group_id is listed twice"}
		}
		seen[sh.GroupID] = true
	}
	for _, sh := range shares {
		if err := requireGroupMember(ctx, s.groups, sh.GroupID, userID); err != nil {
			return nil, err
		}
	}
	before, err := s.repo.ListShareGroupsForCalendar(ctx, calendarID)
	if err != nil {
		return nil, err
	}
	if err := s.repo.ReplaceShares(ctx, calendarID, shares); err != nil {
		return nil, err
	}
	after := make([]uuid.UUID, 0, len(shares))
	for _, sh := range shares {
		after = append(after, sh.GroupID)
	}
	s.publish(userID, before, after)
	cal, err := s.repo.GetCalendar(ctx, calendarID, userID)
	if err != nil {
		return nil, notFoundIfNoRows(err, "calendar")
	}
	return cal, nil
}

// SetOverride sets or (visibility nil) clears how one event, or a whole
// recurring series, shows in every household. The event need not be
// stored: a hidden phone event is never uploaded, so only the calendar
// has to be the caller's.
func (s *ExternalCalendarService) SetOverride(ctx context.Context, userID, calendarID uuid.UUID, externalUID string, visibility *string) error {
	externalUID = strings.TrimSpace(externalUID)
	if externalUID == "" || len(externalUID) > maxExternalUIDLength {
		return &api.ValidationError{Field: "external_uid", Message: "external_uid is required"}
	}
	if visibility != nil {
		switch *visibility {
		case models.OverrideHidden, models.OverrideBusy, models.OverrideDetails:
		default:
			return &api.ValidationError{Field: "visibility", Message: "visibility must be hidden, busy, details or null"}
		}
	}
	if _, err := s.repo.GetCalendar(ctx, calendarID, userID); err != nil {
		return notFoundIfNoRows(err, "calendar")
	}
	if err := s.repo.SetOverride(ctx, userID, calendarID, externalUID, visibility); err != nil {
		return err
	}
	groups, err := s.repo.ListShareGroupsForCalendar(ctx, calendarID)
	if err != nil {
		return err
	}
	s.publish(userID, groups)
	return nil
}

// ListOverrides returns all of the caller's event overrides, including
// those for events the server does not store.
func (s *ExternalCalendarService) ListOverrides(ctx context.Context, userID uuid.UUID) ([]models.EventOverride, error) {
	return s.repo.ListOverrides(ctx, userID)
}

// ListOwnEvents returns the caller's own stored events in [from, to).
func (s *ExternalCalendarService) ListOwnEvents(ctx context.Context, userID uuid.UUID, from, to time.Time) ([]models.OwnEvent, error) {
	if !to.After(from) {
		return nil, &api.ValidationError{Field: "to", Message: "to must be after from"}
	}
	events, err := s.repo.ListOwnEvents(ctx, userID, from, to)
	if err != nil {
		return nil, err
	}
	for i := range events {
		events[i].StartsAt = events[i].StartsAt.UTC()
		events[i].EndsAt = events[i].EndsAt.UTC()
	}
	return events, nil
}

// HouseholdEvents returns what groupID may see of its members' synced
// calendars overlapping [from, to). The caller must already have checked
// that the viewer is a member of groupID.
func (s *ExternalCalendarService) HouseholdEvents(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.CalendarEvent, error) {
	rows, err := s.repo.ListHouseholdEvents(ctx, groupID, from, to)
	if err != nil {
		return nil, err
	}
	out := make([]models.CalendarEvent, 0, len(rows))
	for _, h := range rows {
		if ev := householdCalendarEvent(h, groupID); ev != nil {
			out = append(out, *ev)
		}
	}
	return out, nil
}
