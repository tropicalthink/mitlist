package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
	"github.com/mitlist-app/mitlist/internal/sse"
)

func strp(s string) *string { return &s }

// ---------------------------------------------------------------------------
// The visibility rule
// ---------------------------------------------------------------------------

func TestResolveExternalEventView_Table(t *testing.T) {
	cases := []struct {
		name string
		in   ExternalVisibilityInput
		want ExternalEventView
	}{
		{"no share", ExternalVisibilityInput{OwnerIsMember: true, HasTitle: true}, ExternalViewNone},
		{"no share, override details", ExternalVisibilityInput{OwnerIsMember: true, Override: "details", HasTitle: true}, ExternalViewNone},
		{"owner left", ExternalVisibilityInput{ShareVisibility: "details", HasTitle: true}, ExternalViewNone},
		{"owner left, override details", ExternalVisibilityInput{ShareVisibility: "details", Override: "details", HasTitle: true}, ExternalViewNone},
		{"busy share", ExternalVisibilityInput{ShareVisibility: "busy", OwnerIsMember: true, HasTitle: true}, ExternalViewBusy},
		{"details share", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, HasTitle: true}, ExternalViewDetails},
		{"details share, no title", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true}, ExternalViewBusy},
		{"details share, private", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, SourcePrivate: true, HasTitle: true}, ExternalViewBusy},
		{"hidden", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, Override: "hidden", HasTitle: true}, ExternalViewNone},
		{"override busy on details", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, Override: "busy", HasTitle: true}, ExternalViewBusy},
		{"override details on busy", ExternalVisibilityInput{ShareVisibility: "busy", OwnerIsMember: true, Override: "details", HasTitle: true}, ExternalViewDetails},
		{"override details on private", ExternalVisibilityInput{ShareVisibility: "busy", OwnerIsMember: true, Override: "details", SourcePrivate: true, HasTitle: true}, ExternalViewDetails},
		{"override details, no title", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, Override: "details"}, ExternalViewBusy},
		{"unknown share", ExternalVisibilityInput{ShareVisibility: "public", OwnerIsMember: true, HasTitle: true}, ExternalViewNone},
		{"unknown override", ExternalVisibilityInput{ShareVisibility: "details", OwnerIsMember: true, Override: "everyone", HasTitle: true}, ExternalViewNone},
	}
	for _, c := range cases {
		assert.Equal(t, c.want, ResolveExternalEventView(c.in), c.name)
	}
}

// Every combination, checked against the contract's rules stated as
// independent properties.
func TestResolveExternalEventView_AllCombinations(t *testing.T) {
	shares := []string{"", "busy", "details", "bogus"}
	overrides := []string{"", "hidden", "busy", "details", "bogus"}
	n := 0
	for _, share := range shares {
		for _, member := range []bool{false, true} {
			for _, ov := range overrides {
				for _, private := range []bool{false, true} {
					for _, hasTitle := range []bool{false, true} {
						n++
						in := ExternalVisibilityInput{ShareVisibility: share, OwnerIsMember: member, Override: ov, SourcePrivate: private, HasTitle: hasTitle}
						got := ResolveExternalEventView(in)
						shared := member && (share == "busy" || share == "details")
						label := fmt.Sprintf("%+v", in)
						if !shared || ov == "hidden" || ov == "bogus" {
							assert.Equal(t, ExternalViewNone, got, label)
							continue
						}
						if !hasTitle {
							assert.NotEqual(t, ExternalViewDetails, got, label)
						}
						wantDetails := hasTitle && (ov == "details" || (ov == "" && !private && share == "details"))
						if wantDetails {
							assert.Equal(t, ExternalViewDetails, got, label)
						} else {
							assert.Equal(t, ExternalViewBusy, got, label)
						}
					}
				}
			}
		}
	}
	assert.Equal(t, 160, n)
}

func TestHouseholdCalendarEvent_BusyCarriesNoTitle(t *testing.T) {
	groupID, owner := uuid.New(), uuid.New()
	start := time.Date(2026, 12, 1, 18, 0, 0, 0, time.UTC)
	row := models.HouseholdExternalEvent{
		Event: models.ExternalEvent{ID: uuid.New(), UserID: owner, ExternalUID: "u", StartsAt: start, EndsAt: start.Add(time.Hour),
			Title: strp("Secret therapy session"), SourcePrivate: true},
		ShareVisibility: "details", OwnerIsMember: true,
	}
	ev := householdCalendarEvent(row, groupID)
	require.NotNil(t, ev)
	assert.Equal(t, "", ev.Title)
	assert.True(t, ev.External.BusyOnly)
	assert.Equal(t, models.EventTypeExternalEvent, ev.Type)
	assert.Equal(t, "ext:"+row.Event.ID.String(), ev.ID)
	assert.Equal(t, groupID, ev.GroupID)
	raw, err := json.Marshal(ev)
	require.NoError(t, err)
	assert.NotContains(t, string(raw), "Secret")
	assert.NotContains(t, string(raw), "therapy")
	assert.NotContains(t, string(raw), "external_uid")

	row.Event.SourcePrivate = false
	ev = householdCalendarEvent(row, groupID)
	assert.Equal(t, "Secret therapy session", ev.Title)
	assert.False(t, ev.External.BusyOnly)

	row.OwnerIsMember = false
	assert.Nil(t, householdCalendarEvent(row, groupID))
}

// ---------------------------------------------------------------------------
// Service with a mocked repository
// ---------------------------------------------------------------------------

type fakeFetcher struct {
	mu    sync.Mutex
	res   *ICSFetchResult
	err   error
	calls []string
}

func (f *fakeFetcher) Fetch(_ context.Context, rawURL, etag, lastModified string) (*ICSFetchResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls = append(f.calls, rawURL+"|"+etag+"|"+lastModified)
	return f.res, f.err
}

type published struct {
	mu     sync.Mutex
	events []sse.Event
}

func (p *published) groups() []string {
	p.mu.Lock()
	defer p.mu.Unlock()
	var out []string
	for _, e := range p.events {
		out = append(out, e.GroupID)
	}
	return out
}

var testNow = time.Date(2026, 11, 24, 12, 0, 0, 0, time.UTC)

func newExtService(t *testing.T) (*ExternalCalendarService, *mocks.MockExternalCalendarRepo, *mocks.MockGroupRepo, *fakeFetcher, *published) {
	t.Helper()
	repo := new(mocks.MockExternalCalendarRepo)
	groups := new(mocks.MockGroupRepo)
	svc, err := NewExternalCalendarService(repo, groups, "test-secret-key-min-32-chars-long!!!")
	require.NoError(t, err)
	f := &fakeFetcher{}
	svc.SetFetcher(f)
	svc.SetClock(func() time.Time { return testNow })
	hub := sse.New()
	pub := &published{}
	hub.OnPublish(func(e sse.Event) {
		pub.mu.Lock()
		pub.events = append(pub.events, e)
		pub.mu.Unlock()
	})
	svc.SetHub(hub)
	return svc, repo, groups, f, pub
}

func TestHouseholdEvents_AppliesTheRuleToEveryRow(t *testing.T) {
	svc, repo, _, _, _ := newExtService(t)
	groupID := uuid.New()
	start := testNow.Add(time.Hour)
	ev := func(title *string, private bool) models.ExternalEvent {
		return models.ExternalEvent{ID: uuid.New(), UserID: uuid.New(), StartsAt: start, EndsAt: start.Add(time.Hour), Title: title, SourcePrivate: private}
	}
	rows := []models.HouseholdExternalEvent{
		{Event: ev(strp("Movie"), false), ShareVisibility: "details", OwnerIsMember: true},
		{Event: ev(strp("Doctor"), false), ShareVisibility: "busy", OwnerIsMember: true},
		{Event: ev(strp("Private"), true), ShareVisibility: "details", OwnerIsMember: true},
		{Event: ev(strp("Hidden"), false), ShareVisibility: "details", OwnerIsMember: true, Override: strp("hidden")},
		{Event: ev(strp("Left"), false), ShareVisibility: "details", OwnerIsMember: false},
		{Event: ev(nil, false), ShareVisibility: "details", OwnerIsMember: true},
	}
	from, to := testNow, testNow.AddDate(0, 0, 7)
	repo.On("ListHouseholdEvents", mock.Anything, groupID, from, to).Return(rows, nil)
	events, err := svc.HouseholdEvents(context.Background(), groupID, from, to)
	require.NoError(t, err)
	require.Len(t, events, 4)
	assert.Equal(t, "Movie", events[0].Title)
	for _, e := range events[1:] {
		assert.Equal(t, "", e.Title)
		assert.True(t, e.External.BusyOnly)
	}
	raw, _ := json.Marshal(events)
	for _, secret := range []string{"Doctor", "Private", "Hidden", "Left"} {
		assert.NotContains(t, string(raw), secret)
	}
}

func TestReplaceShares_Authorization(t *testing.T) {
	ctx := context.Background()
	user, calID, mine, notMine := uuid.New(), uuid.New(), uuid.New(), uuid.New()

	t.Run("someone else's calendar is not found", func(t *testing.T) {
		svc, repo, _, _, _ := newExtService(t)
		repo.On("GetCalendar", mock.Anything, calID, user).Return(nil, pgx.ErrNoRows)
		_, err := svc.ReplaceShares(ctx, user, calID, nil)
		assert.Equal(t, 404, api.HTTPStatusForError(err))
	})
	t.Run("a household the caller is not in is forbidden", func(t *testing.T) {
		svc, repo, groups, _, _ := newExtService(t)
		repo.On("GetCalendar", mock.Anything, calID, user).Return(&models.ExternalCalendar{ID: calID}, nil)
		groups.On("GetMembership", mock.Anything, mine, user).Return(&models.GroupMembership{Role: "member"}, nil)
		groups.On("GetMembership", mock.Anything, notMine, user).Return(nil, pgx.ErrNoRows)
		_, err := svc.ReplaceShares(ctx, user, calID, []models.CalendarShare{{GroupID: mine, Visibility: "busy"}, {GroupID: notMine, Visibility: "details"}})
		assert.Equal(t, 403, api.HTTPStatusForError(err))
		repo.AssertNotCalled(t, "ReplaceShares", mock.Anything, mock.Anything, mock.Anything)
	})
	t.Run("bad visibility and duplicates are rejected", func(t *testing.T) {
		svc, repo, _, _, _ := newExtService(t)
		repo.On("GetCalendar", mock.Anything, calID, user).Return(&models.ExternalCalendar{ID: calID}, nil)
		_, err := svc.ReplaceShares(ctx, user, calID, []models.CalendarShare{{GroupID: mine, Visibility: "everything"}})
		assert.Equal(t, 400, api.HTTPStatusForError(err))
		_, err = svc.ReplaceShares(ctx, user, calID, []models.CalendarShare{{GroupID: mine, Visibility: "busy"}, {GroupID: mine, Visibility: "details"}})
		assert.Equal(t, 400, api.HTTPStatusForError(err))
	})
	t.Run("replaces and tells old and new households", func(t *testing.T) {
		svc, repo, groups, _, pub := newExtService(t)
		old := uuid.New()
		repo.On("GetCalendar", mock.Anything, calID, user).Return(&models.ExternalCalendar{ID: calID}, nil)
		groups.On("GetMembership", mock.Anything, mine, user).Return(&models.GroupMembership{Role: "admin"}, nil)
		repo.On("ListShareGroupsForCalendar", mock.Anything, calID).Return([]uuid.UUID{old}, nil)
		shares := []models.CalendarShare{{GroupID: mine, Visibility: "details"}}
		repo.On("ReplaceShares", mock.Anything, calID, shares).Return(nil)
		_, err := svc.ReplaceShares(ctx, user, calID, shares)
		require.NoError(t, err)
		assert.ElementsMatch(t, []string{old.String(), mine.String()}, pub.groups())
		for _, e := range pub.events {
			assert.Equal(t, EventCalendarExternalChanged, e.Type)
			assert.JSONEq(t, fmt.Sprintf(`{"user_id":%q}`, user.String()), string(e.Payload))
		}
	})
}

func TestSetOverride_Validation(t *testing.T) {
	ctx := context.Background()
	svc, repo, _, _, pub := newExtService(t)
	user, calID, other := uuid.New(), uuid.New(), uuid.New()
	repo.On("GetCalendar", mock.Anything, other, user).Return(nil, pgx.ErrNoRows)
	assert.Equal(t, 404, api.HTTPStatusForError(svc.SetOverride(ctx, user, other, "uid", strp("hidden"))))
	assert.Equal(t, 400, api.HTTPStatusForError(svc.SetOverride(ctx, user, calID, "uid", strp("public"))))
	assert.Equal(t, 400, api.HTTPStatusForError(svc.SetOverride(ctx, user, calID, " ", nil)))

	g := uuid.New()
	repo.On("GetCalendar", mock.Anything, calID, user).Return(&models.ExternalCalendar{ID: calID}, nil)
	repo.On("SetOverride", mock.Anything, user, calID, "uid", (*string)(nil)).Return(nil)
	repo.On("ListShareGroupsForCalendar", mock.Anything, calID).Return([]uuid.UUID{g}, nil)
	require.NoError(t, svc.SetOverride(ctx, user, calID, "uid", nil))
	assert.Equal(t, []string{g.String()}, pub.groups())
}

func TestDeviceSync_NormalizesAndReplaces(t *testing.T) {
	ctx := context.Background()
	svc, repo, _, _, pub := newExtService(t)
	user, connID, g := uuid.New(), uuid.New(), uuid.New()
	repo.On("GetConnection", mock.Anything, connID, user).Return(&models.CalendarConnection{ID: connID, UserID: user, Kind: "device"}, nil)
	repo.On("ListShareGroupsForConnection", mock.Anything, connID).Return([]uuid.UUID{g}, nil)

	berlin, _ := time.LoadLocation("Europe/Berlin")
	in := DeviceSyncInput{
		Calendars: []DeviceCalendarInput{{ExternalID: "work", Name: "Work", Color: strp("#ff0000")}, {ExternalID: "home", Name: ""}},
		Events: []DeviceEventInput{
			{CalendarExternalID: "work", ExternalUID: "a", StartsAt: testNow.Add(time.Hour), EndsAt: testNow.Add(2 * time.Hour), Title: strp(strings.Repeat("x", 300))},
			{CalendarExternalID: "work", ExternalUID: "a", StartsAt: testNow.Add(time.Hour), EndsAt: testNow.Add(2 * time.Hour)},
			{CalendarExternalID: "home", ExternalUID: "trip", AllDay: true,
				StartsAt: time.Date(2026, 12, 24, 0, 0, 0, 0, berlin), EndsAt: time.Date(2026, 12, 24, 0, 0, 0, 0, berlin)},
			{CalendarExternalID: "home", ExternalUID: "old", StartsAt: testNow.AddDate(0, 0, -10), EndsAt: testNow.AddDate(0, 0, -10).Add(time.Hour)},
			{CalendarExternalID: "home", ExternalUID: "far", StartsAt: testNow.AddDate(0, 0, 200), EndsAt: testNow.AddDate(0, 0, 200).Add(time.Hour)},
			{CalendarExternalID: "home", ExternalUID: "blank", StartsAt: testNow.Add(3 * time.Hour), EndsAt: testNow.Add(4 * time.Hour), Title: strp("   ")},
		},
	}
	var gotEvents []repositories.DeviceSyncEvent
	var gotCals []models.ExternalCalendar
	repo.On("DeviceSync", mock.Anything, connID, user, mock.Anything, mock.Anything, mock.Anything, testNow).
		Run(func(a mock.Arguments) {
			gotCals = a.Get(3).([]models.ExternalCalendar)
			gotEvents = a.Get(4).([]repositories.DeviceSyncEvent)
		}).Return(nil)
	_, err := svc.DeviceSync(ctx, user, connID, in)
	require.NoError(t, err)

	require.Len(t, gotCals, 2)
	assert.Equal(t, "Calendar", gotCals[1].Name)
	require.Len(t, gotEvents, 3, "duplicate and out-of-window events are dropped")
	assert.Len(t, []rune(*gotEvents[0].Event.Title), 200)
	trip := gotEvents[1].Event
	assert.Equal(t, time.Date(2026, 12, 24, 0, 0, 0, 0, time.UTC), trip.StartsAt)
	assert.Equal(t, time.Date(2026, 12, 25, 0, 0, 0, 0, time.UTC), trip.EndsAt)
	assert.Nil(t, gotEvents[2].Event.Title)
	assert.Equal(t, []string{g.String()}, pub.groups())
}

func TestDeviceSync_Rejections(t *testing.T) {
	ctx := context.Background()
	svc, repo, _, _, _ := newExtService(t)
	user, dev, ics, other := uuid.New(), uuid.New(), uuid.New(), uuid.New()
	repo.On("GetConnection", mock.Anything, dev, user).Return(&models.CalendarConnection{ID: dev, Kind: "device"}, nil)
	repo.On("GetConnection", mock.Anything, ics, user).Return(&models.CalendarConnection{ID: ics, Kind: "ics"}, nil)
	repo.On("GetConnection", mock.Anything, other, user).Return(nil, pgx.ErrNoRows)

	_, err := svc.DeviceSync(ctx, user, other, DeviceSyncInput{})
	assert.Equal(t, 404, api.HTTPStatusForError(err))
	_, err = svc.DeviceSync(ctx, user, ics, DeviceSyncInput{})
	assert.Equal(t, 400, api.HTTPStatusForError(err))
	_, err = svc.DeviceSync(ctx, user, dev, DeviceSyncInput{
		Calendars: []DeviceCalendarInput{{ExternalID: "a"}},
		Events:    []DeviceEventInput{{CalendarExternalID: "b", ExternalUID: "x", StartsAt: testNow, EndsAt: testNow}},
	})
	assert.Equal(t, 400, api.HTTPStatusForError(err))
	_, err = svc.DeviceSync(ctx, user, dev, DeviceSyncInput{
		Calendars: []DeviceCalendarInput{{ExternalID: "a"}},
		Events:    []DeviceEventInput{{CalendarExternalID: "a", ExternalUID: "x", StartsAt: testNow, EndsAt: testNow.Add(-time.Hour)}},
	})
	assert.Equal(t, 400, api.HTTPStatusForError(err))
	many := make([]DeviceCalendarInput, 51)
	for i := range many {
		many[i] = DeviceCalendarInput{ExternalID: fmt.Sprint(i)}
	}
	_, err = svc.DeviceSync(ctx, user, dev, DeviceSyncInput{Calendars: many})
	assert.Equal(t, 400, api.HTTPStatusForError(err))
	repo.AssertNotCalled(t, "DeviceSync", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}

const sampleFeed = "BEGIN:VCALENDAR\r\nX-WR-CALNAME:Sam\r\nBEGIN:VEVENT\r\nUID:m\r\nDTSTART:20261201T180000Z\r\nDTEND:20261201T200000Z\r\nSUMMARY:Movie\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

func TestCreateICSConnection(t *testing.T) {
	ctx := context.Background()
	user := uuid.New()

	t.Run("http and garbage links are refused before fetching", func(t *testing.T) {
		svc, _, _, f, _ := newExtService(t)
		for _, u := range []string{"http://example.com/a.ics", "ftp://x/y", "not a url", "", "https://user:pw@example.com/a.ics"} {
			_, err := svc.CreateICSConnection(ctx, user, "", u)
			assert.Equal(t, 400, api.HTTPStatusForError(err), u)
		}
		assert.Empty(t, f.calls)
	})
	t.Run("not a calendar is a 422 code and nothing is stored", func(t *testing.T) {
		svc, repo, _, f, _ := newExtService(t)
		repo.On("CountConnections", mock.Anything, user).Return(0, nil)
		f.res = &ICSFetchResult{Body: []byte("<html>login</html>")}
		_, err := svc.CreateICSConnection(ctx, user, "", "https://example.com/a.ics")
		var se *CalendarSyncError
		require.ErrorAs(t, err, &se)
		assert.Equal(t, "not_calendar", se.Code)
		repo.AssertNotCalled(t, "CreateICSConnection", mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	})
	t.Run("fetch errors never carry the link", func(t *testing.T) {
		svc, repo, _, f, _ := newExtService(t)
		repo.On("CountConnections", mock.Anything, user).Return(0, nil)
		f.err = fmt.Errorf("Get \"https://example.com/secret-token.ics\": dial tcp: refused")
		_, err := svc.CreateICSConnection(ctx, user, "", "https://example.com/secret-token.ics")
		require.Error(t, err)
		assert.NotContains(t, err.Error(), "secret-token")
		assert.Equal(t, "calendar sync failed: fetch_failed", err.Error())
	})
	t.Run("the connection limit holds", func(t *testing.T) {
		svc, repo, _, f, _ := newExtService(t)
		repo.On("CountConnections", mock.Anything, user).Return(10, nil)
		_, err := svc.CreateICSConnection(ctx, user, "", "https://example.com/a.ics")
		assert.Equal(t, 400, api.HTTPStatusForError(err))
		assert.Empty(t, f.calls)
	})
	t.Run("stores the encrypted link, the calendar and its events", func(t *testing.T) {
		svc, repo, _, f, _ := newExtService(t)
		repo.On("CountConnections", mock.Anything, user).Return(0, nil)
		f.res = &ICSFetchResult{Body: []byte(sampleFeed), ETag: "\"v1\""}
		var stored *models.CalendarConnection
		var storedEvents []models.ExternalEvent
		repo.On("CreateICSConnection", mock.Anything, mock.Anything, mock.Anything, mock.Anything).Run(func(a mock.Arguments) {
			stored = a.Get(1).(*models.CalendarConnection)
			storedEvents = a.Get(3).([]models.ExternalEvent)
		}).Return(nil)
		repo.On("GetConnection", mock.Anything, mock.Anything, user).Return(&models.CalendarConnection{}, nil)
		_, err := svc.CreateICSConnection(ctx, user, "", "webcal://p01-caldav.icloud.com/published/2/secret")
		require.NoError(t, err)
		assert.Equal(t, []string{"https://p01-caldav.icloud.com/published/2/secret||"}, f.calls)
		require.NotNil(t, stored)
		assert.Equal(t, "Sam", stored.Name)
		assert.NotContains(t, string(stored.ICSURLEncrypted), "secret")
		link, err := svc.sealer.open(stored.ID, stored.ICSURLEncrypted)
		require.NoError(t, err)
		assert.Equal(t, "https://p01-caldav.icloud.com/published/2/secret", link)
		assert.Equal(t, "\"v1\"", *stored.HTTPETag)
		require.Len(t, storedEvents, 1)
		assert.Equal(t, "Movie", *storedEvents[0].Title)
		raw, _ := json.Marshal(stored)
		assert.NotContains(t, string(raw), "icloud")
	})
}

func icsConn(t *testing.T, svc *ExternalCalendarService, hash *string) *models.CalendarConnection {
	id := uuid.New()
	sealed, err := svc.sealer.seal(id, "https://example.com/feed.ics")
	require.NoError(t, err)
	return &models.CalendarConnection{ID: id, UserID: uuid.New(), Kind: "ics", ICSURLEncrypted: sealed, ContentHash: hash, HTTPETag: strp("\"old\""), FailureCount: 2}
}

func TestSyncICS_RecordsFailuresWithBackoff(t *testing.T) {
	ctx := context.Background()
	for _, code := range []string{"fetch_failed", "too_large", "not_calendar"} {
		svc, repo, _, f, pub := newExtService(t)
		conn := icsConn(t, svc, strp("h"))
		if code == "not_calendar" {
			f.res = &ICSFetchResult{Body: []byte("nope")}
			repo.On("ListCalendarIDs", mock.Anything, conn.ID).Return([]uuid.UUID{uuid.New()}, nil)
		} else {
			f.err = syncErr(code)
		}
		repo.On("RecordSyncResult", mock.Anything, conn.ID, repositories.ICSSyncRecord{
			AttemptAt: testNow, ErrorCode: strp(code), FailureCount: 3, NextAttemptAt: testNow.Add(2 * time.Hour),
		}).Return(nil)
		require.NoError(t, svc.syncICS(ctx, conn), code)
		repo.AssertExpectations(t)
		repo.AssertNotCalled(t, "ReplaceCalendarEvents", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
		assert.Empty(t, pub.groups())
		assert.Equal(t, []string{"https://example.com/feed.ics|\"old\"|"}, f.calls)
	}
}

func TestSyncICS_UnauthorizedClearsEvents(t *testing.T) {
	svc, repo, _, f, pub := newExtService(t)
	conn := icsConn(t, svc, strp("h"))
	calID, g := uuid.New(), uuid.New()
	f.err = syncErr("unauthorized")
	repo.On("RecordSyncResult", mock.Anything, conn.ID, mock.Anything).Return(nil)
	repo.On("ListCalendarIDs", mock.Anything, conn.ID).Return([]uuid.UUID{calID}, nil)
	repo.On("ReplaceCalendarEvents", mock.Anything, conn.ID, calID, []models.ExternalEvent(nil), (*string)(nil)).Return(nil)
	repo.On("ListShareGroupsForConnection", mock.Anything, conn.ID).Return([]uuid.UUID{g}, nil)
	require.NoError(t, svc.syncICS(context.Background(), conn))
	repo.AssertExpectations(t)
	assert.Equal(t, []string{g.String()}, pub.groups())
}

func TestSyncICS_ChangedUnchangedAndNotModified(t *testing.T) {
	ctx := context.Background()
	calID, g := uuid.New(), uuid.New()

	svc, repo, _, f, pub := newExtService(t)
	conn := icsConn(t, svc, nil)
	f.res = &ICSFetchResult{Body: []byte(sampleFeed), ETag: "\"new\""}
	repo.On("ListCalendarIDs", mock.Anything, conn.ID).Return([]uuid.UUID{calID}, nil)
	var hash *string
	repo.On("ReplaceCalendarEvents", mock.Anything, conn.ID, calID, mock.Anything, mock.Anything).Run(func(a mock.Arguments) {
		hash = a.Get(4).(*string)
	}).Return(nil)
	repo.On("ListShareGroupsForConnection", mock.Anything, conn.ID).Return([]uuid.UUID{g}, nil)
	repo.On("RecordSyncResult", mock.Anything, conn.ID, repositories.ICSSyncRecord{
		AttemptAt: testNow, Succeeded: true, NextAttemptAt: testNow.Add(icsRefreshInterval), ETag: strp("\"new\""),
	}).Return(nil)
	require.NoError(t, svc.syncICS(ctx, conn))
	assert.Equal(t, []string{g.String()}, pub.groups())
	require.NotNil(t, hash)

	// Same content again: nothing replaced, nobody told.
	svc2, repo2, _, f2, pub2 := newExtService(t)
	conn2 := icsConn(t, svc2, hash)
	f2.res = &ICSFetchResult{Body: []byte(sampleFeed)}
	repo2.On("ListCalendarIDs", mock.Anything, conn2.ID).Return([]uuid.UUID{calID}, nil)
	repo2.On("RecordSyncResult", mock.Anything, conn2.ID, mock.Anything).Return(nil)
	require.NoError(t, svc2.syncICS(ctx, conn2))
	repo2.AssertNotCalled(t, "ReplaceCalendarEvents", mock.Anything, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
	assert.Empty(t, pub2.groups())

	// 304: validators kept, nothing parsed.
	svc3, repo3, _, f3, _ := newExtService(t)
	conn3 := icsConn(t, svc3, hash)
	f3.res = &ICSFetchResult{NotModified: true}
	repo3.On("RecordSyncResult", mock.Anything, conn3.ID, repositories.ICSSyncRecord{
		AttemptAt: testNow, Succeeded: true, NextAttemptAt: testNow.Add(icsRefreshInterval), ETag: strp("\"old\""),
	}).Return(nil)
	require.NoError(t, svc3.syncICS(ctx, conn3))
	repo3.AssertNotCalled(t, "ListCalendarIDs", mock.Anything, mock.Anything)
}

func TestSyncNow_RateLimitAndKind(t *testing.T) {
	ctx := context.Background()
	svc, repo, _, _, _ := newExtService(t)
	user, ics, dev := uuid.New(), uuid.New(), uuid.New()
	repo.On("GetConnection", mock.Anything, ics, user).Return(&models.CalendarConnection{ID: ics, Kind: "ics"}, nil)
	repo.On("GetConnection", mock.Anything, dev, user).Return(&models.CalendarConnection{ID: dev, Kind: "device"}, nil)
	repo.On("ClaimAttempt", mock.Anything, ics, testNow, time.Minute).Return(false, nil)
	_, err := svc.SyncNow(ctx, user, ics)
	assert.ErrorIs(t, err, ErrSyncTooSoon)
	_, err = svc.SyncNow(ctx, user, dev)
	assert.Equal(t, 400, api.HTTPStatusForError(err))
}

func TestICSBackoff(t *testing.T) {
	assert.Equal(t, 30*time.Minute, icsBackoff(1))
	assert.Equal(t, time.Hour, icsBackoff(2))
	assert.Equal(t, 2*time.Hour, icsBackoff(3))
	assert.Equal(t, 24*time.Hour, icsBackoff(20))
}

func TestRefreshDueICS_SyncsEachDueConnection(t *testing.T) {
	svc, repo, _, f, _ := newExtService(t)
	var due []models.CalendarConnection
	for i := 0; i < 6; i++ {
		due = append(due, *icsConn(t, svc, nil))
	}
	repo.On("ListDueICSConnections", mock.Anything, testNow, icsRefreshBatch).Return(due, nil)
	repo.On("RecordSyncResult", mock.Anything, mock.Anything, mock.Anything).Return(nil)
	f.err = syncErr("fetch_failed")
	n, err := svc.RefreshDueICS(context.Background())
	require.NoError(t, err)
	assert.Equal(t, 6, n)
	assert.Len(t, f.calls, 6)
	repo.AssertNumberOfCalls(t, "RecordSyncResult", 6)
}

func TestICSURLSealer(t *testing.T) {
	s1, err := newICSURLSealer("secret-one")
	require.NoError(t, err)
	s2, _ := newICSURLSealer("secret-two")
	id := uuid.New()
	blob, err := s1.seal(id, "https://calendar.google.com/private-abc/basic.ics")
	require.NoError(t, err)
	assert.NotContains(t, string(blob), "private-abc")
	got, err := s1.open(id, blob)
	require.NoError(t, err)
	assert.Equal(t, "https://calendar.google.com/private-abc/basic.ics", got)
	_, err = s1.open(uuid.New(), blob)
	assert.Error(t, err, "bound to its connection")
	_, err = s2.open(id, blob)
	assert.Error(t, err, "another key")
	_, err = s1.open(id, blob[:5])
	assert.Error(t, err)
	again, _ := s1.seal(id, "https://calendar.google.com/private-abc/basic.ics")
	assert.NotEqual(t, blob, again, "fresh nonce each time")
}

func TestListOverrides_IsTheCallersOnly(t *testing.T) {
	svc, repo, _, _, _ := newExtService(t)
	user := uuid.New()
	want := []models.EventOverride{{CalendarID: uuid.New(), ExternalUID: "u", Visibility: "hidden"}}
	repo.On("ListOverrides", mock.Anything, user).Return(want, nil)
	got, err := svc.ListOverrides(context.Background(), user)
	require.NoError(t, err)
	assert.Equal(t, want, got)
	repo.AssertExpectations(t)
}
