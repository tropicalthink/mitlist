package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/internal/sse"
)

type stubICSFetcher struct {
	body []byte
	err  error
}

func (s *stubICSFetcher) Fetch(context.Context, string, string, string) (*services.ICSFetchResult, error) {
	if s.err != nil {
		return nil, s.err
	}
	return &services.ICSFetchResult{Body: s.body}, nil
}

// asCredential marks requests carrying X-Test-Credential as made with an
// integration (or widget) credential, as AuthWithCredentials does.
func asCredential(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if kind := r.Header.Get("X-Test-Credential"); kind != "" {
			user, _ := userFromContext(r)
			r = r.WithContext(middleware.WithIntegrationCredential(r.Context(), &services.CredentialIdentity{
				CredentialID: uuid.New(), UserID: user.ID, Kind: kind, Scopes: []string{"*"},
			}))
		}
		next.ServeHTTP(w, r)
	})
}

type extEnv struct {
	router  chi.Router
	fetcher *stubICSFetcher
}

func newExternalCalendarEnv(t *testing.T) *extEnv {
	t.Helper()
	if testDB == nil {
		t.Skip("test database not connected")
	}
	extSvc, err := services.NewExternalCalendarService(repositories.NewExternalCalendarRepository(testDB), newTestGroupRepo(), testCfg.SecretKey)
	require.NoError(t, err)
	fetcher := &stubICSFetcher{}
	extSvc.SetFetcher(fetcher)
	calSvc := services.NewCalendarService(repositories.NewMealPlanRepo(testDB), newTestRecipeRepo(), newTestChoreRepo(),
		newTestFinanceRepo(), newTestGroupRepo(), repositories.NewPinwallRepository(testDB), newTestListRepo())
	calSvc.SetExternalEvents(extSvc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Use(asCredential)
	NewCalendarHandler(calSvc).RegisterRoutes(r)
	NewExternalCalendarHandler(extSvc).RegisterRoutes(r)
	return &extEnv{router: r, fetcher: fetcher}
}

func (e *extEnv) do(t *testing.T, method, path string, body any, token string, headers ...string) *httptest.ResponseRecorder {
	t.Helper()
	req := buildRequest(t, method, path, body, token)
	for i := 0; i+1 < len(headers); i += 2 {
		req.Header.Set(headers[i], headers[i+1])
	}
	rec := httptest.NewRecorder()
	e.router.ServeHTTP(rec, req)
	return rec
}

func newHousehold(t *testing.T, owner uuid.UUID, members ...uuid.UUID) uuid.UUID {
	t.Helper()
	g := &models.Group{Name: "Flat", Currency: "EUR", CreatedBy: owner}
	require.NoError(t, newTestGroupRepo().CreateGroup(context.Background(), g))
	addTestMembership(t, g.ID, owner, "admin")
	for _, m := range members {
		addTestMembership(t, g.ID, m, "member")
	}
	return g.ID
}

func uniqueUser(t *testing.T, name string) (*models.User, string) {
	u := createTestUser(t, fmt.Sprintf("%s-%s@test.com", name, uuid.NewString()[:8]), "Password123!")
	return u, generateTestToken(u.ID)
}

type connectionJSON struct {
	ID        uuid.UUID `json:"id"`
	Kind      string    `json:"kind"`
	Name      string    `json:"name"`
	LastError *string   `json:"last_error"`
	Calendars []struct {
		ID         uuid.UUID              `json:"id"`
		ExternalID string                 `json:"external_id"`
		Name       string                 `json:"name"`
		Shares     []models.CalendarShare `json:"shares"`
	} `json:"calendars"`
}

func calendarByExt(t *testing.T, c connectionJSON, ext string) uuid.UUID {
	for _, cal := range c.Calendars {
		if cal.ExternalID == ext {
			return cal.ID
		}
	}
	t.Fatalf("calendar %s missing from %+v", ext, c)
	return uuid.Nil
}

type calendarEventJSON struct {
	ID       string `json:"id"`
	Type     string `json:"type"`
	Title    string `json:"title"`
	External *struct {
		UserID   uuid.UUID `json:"user_id"`
		BusyOnly bool      `json:"busy_only"`
		AllDay   bool      `json:"all_day"`
	} `json:"external"`
}

func (e *extEnv) externalEvents(t *testing.T, groupID uuid.UUID, token string, headers ...string) []calendarEventJSON {
	t.Helper()
	from := time.Now().UTC().AddDate(0, 0, -1).Format("2006-01-02")
	to := time.Now().UTC().AddDate(0, 0, 30).Format("2006-01-02")
	rec := e.do(t, "GET", "/calendar?group_id="+groupID.String()+"&from="+from+"&to="+to+"&include=external", nil, token, headers...)
	requireStatus(t, rec, http.StatusOK)
	var body struct {
		Events []calendarEventJSON `json:"events"`
	}
	parseJSONResponse(t, rec, &body)
	var out []calendarEventJSON
	for _, ev := range body.Events {
		if ev.Type == "external_event" {
			out = append(out, ev)
		}
	}
	return out
}

func titles(events []calendarEventJSON) []string {
	var out []string
	for _, e := range events {
		if e.External.BusyOnly {
			out = append(out, "busy:"+e.Title)
		} else {
			out = append(out, e.Title)
		}
	}
	return out
}

func TestExternalCalendars_EndToEndVisibility(t *testing.T) {
	env := newExternalCalendarEnv(t)
	owner, ownerTok := uniqueUser(t, "owner")
	mate, mateTok := uniqueUser(t, "mate")
	outsider, outsiderTok := uniqueUser(t, "outsider")
	home := newHousehold(t, owner.ID, mate.ID)
	elsewhere := newHousehold(t, outsider.ID)

	// Device connection: 201 then 200 for the same device.
	rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Pixel", "device_id": "dev-1"}, ownerTok)
	requireStatus(t, rec, http.StatusCreated)
	var conn connectionJSON
	parseJSONResponse(t, rec, &conn)
	rec = env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Pixel 9", "device_id": "dev-1"}, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	var again connectionJSON
	parseJSONResponse(t, rec, &again)
	assert.Equal(t, conn.ID, again.ID)
	assert.Equal(t, "Pixel 9", again.Name)

	start := time.Now().UTC().Add(48 * time.Hour).Truncate(time.Hour)
	day := time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, 3)
	upload := map[string]any{
		"calendars": []map[string]any{{"external_id": "personal", "name": "Personal"}, {"external_id": "work", "name": "Work"}},
		"events": []map[string]any{
			{"calendar_external_id": "personal", "external_uid": "movie", "starts_at": start, "ends_at": start.Add(2 * time.Hour), "all_day": false, "title": "Movie night", "source_private": false, "free": false},
			{"calendar_external_id": "personal", "external_uid": "therapy", "starts_at": start.Add(3 * time.Hour), "ends_at": start.Add(4 * time.Hour), "all_day": false, "title": "Therapy", "source_private": true, "free": false},
			{"calendar_external_id": "personal", "external_uid": "trip", "starts_at": day, "ends_at": day.AddDate(0, 0, 2), "all_day": true, "title": "Lisbon", "source_private": false, "free": true},
			{"calendar_external_id": "work", "external_uid": "board", "starts_at": start, "ends_at": start.Add(time.Hour), "all_day": false, "title": "Board meeting", "source_private": false, "free": false},
		},
	}
	rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync", upload, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	parseJSONResponse(t, rec, &conn)
	personal, work := calendarByExt(t, conn, "personal"), calendarByExt(t, conn, "work")

	// Nothing is shared yet.
	assert.Empty(t, env.externalEvents(t, home, mateTok))

	// Sharing with a household the owner is not in is forbidden.
	rec = env.do(t, "PUT", "/calendar/external/calendars/"+personal.String()+"/shares",
		map[string]any{"shares": []map[string]any{{"group_id": elsewhere, "visibility": "details"}}}, ownerTok)
	requireStatus(t, rec, http.StatusForbidden)

	rec = env.do(t, "PUT", "/calendar/external/calendars/"+personal.String()+"/shares",
		map[string]any{"shares": []map[string]any{{"group_id": home, "visibility": "details"}}}, ownerTok)
	requireStatus(t, rec, http.StatusOK)

	got := env.externalEvents(t, home, mateTok)
	assert.ElementsMatch(t, []string{"Movie night", "busy:", "Lisbon"}, titles(got))
	for _, ev := range got {
		assert.Equal(t, owner.ID, ev.External.UserID)
		assert.True(t, strings.HasPrefix(ev.ID, "ext:"))
	}
	// The owner sees the household calendar exactly as housemates do.
	assert.ElementsMatch(t, []string{"Movie night", "busy:", "Lisbon"}, titles(env.externalEvents(t, home, ownerTok)))

	// The raw response never contains an unshared calendar's or a private
	// event's title.
	from := time.Now().UTC().AddDate(0, 0, -1).Format("2006-01-02")
	to := time.Now().UTC().AddDate(0, 0, 30).Format("2006-01-02")
	raw := env.do(t, "GET", "/calendar?group_id="+home.String()+"&from="+from+"&to="+to+"&include=external", nil, mateTok).Body.String()
	assert.NotContains(t, raw, "Board meeting")
	assert.NotContains(t, raw, "Therapy")

	// Without include=external, and for credentials, nothing external.
	rec = env.do(t, "GET", "/calendar?group_id="+home.String()+"&from="+from+"&to="+to, nil, mateTok)
	requireStatus(t, rec, http.StatusOK)
	assert.NotContains(t, rec.Body.String(), "external_event")
	assert.Empty(t, env.externalEvents(t, home, mateTok, "X-Test-Credential", "integration"))
	assert.Empty(t, env.externalEvents(t, home, mateTok, "X-Test-Credential", "widget"))
	// The iCal export never includes them.
	rec = env.do(t, "GET", "/calendar/ical?group_id="+home.String()+"&from="+from+"&to="+to, nil, mateTok)
	requireStatus(t, rec, http.StatusOK)
	assert.NotContains(t, rec.Body.String(), "Movie")

	// A non-member never gets the household's events.
	rec = env.do(t, "GET", "/calendar?group_id="+home.String()+"&from="+from+"&to="+to+"&include=external", nil, outsiderTok)
	requireStatus(t, rec, http.StatusForbidden)

	// Overrides: hide the movie, reveal the private one, then clear.
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "movie", "visibility": "hidden"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "therapy", "visibility": "details"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "trip", "visibility": "busy"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	assert.ElementsMatch(t, []string{"Therapy", "busy:"}, titles(env.externalEvents(t, home, mateTok)))
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "therapy", "visibility": nil}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	assert.ElementsMatch(t, []string{"busy:", "busy:"}, titles(env.externalEvents(t, home, mateTok)))

	// The owner's own view has titles and overrides.
	rec = env.do(t, "GET", "/calendar/external/events/mine", nil, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	var mine struct {
		Events []models.OwnEvent `json:"events"`
	}
	parseJSONResponse(t, rec, &mine)
	assert.Len(t, mine.Events, 4)
	for _, e := range mine.Events {
		if e.ExternalUID == "movie" {
			require.NotNil(t, e.Override)
			assert.Equal(t, "hidden", *e.Override)
			assert.Equal(t, "Movie night", *e.Title)
		}
	}
	// A housemate's "mine" is their own (empty).
	rec = env.do(t, "GET", "/calendar/external/events/mine", nil, mateTok)
	requireStatus(t, rec, http.StatusOK)
	assert.JSONEq(t, `{"events":[]}`, rec.Body.String())

	// Device-sync is a full replace that keeps ids, shares and overrides:
	// "work" goes, "personal" is renamed and gets new events.
	upload = map[string]any{
		"calendars": []map[string]any{{"external_id": "personal", "name": "Me"}},
		"events": []map[string]any{
			{"calendar_external_id": "personal", "external_uid": "movie", "starts_at": start, "ends_at": start.Add(2 * time.Hour), "all_day": false, "title": "Movie night", "source_private": false, "free": false},
			{"calendar_external_id": "personal", "external_uid": "dinner", "starts_at": start.Add(5 * time.Hour), "ends_at": start.Add(6 * time.Hour), "all_day": false, "title": "Dinner", "source_private": false, "free": false},
		},
	}
	rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync", upload, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	var synced connectionJSON
	parseJSONResponse(t, rec, &synced)
	require.Len(t, synced.Calendars, 1)
	assert.Equal(t, personal, synced.Calendars[0].ID)
	assert.Equal(t, "Me", synced.Calendars[0].Name)
	assert.Equal(t, []models.CalendarShare{{GroupID: home, Visibility: "details"}}, synced.Calendars[0].Shares)
	// movie keeps its hidden override; dinner is new; therapy and trip are gone.
	assert.Equal(t, []string{"Dinner"}, titles(env.externalEvents(t, home, mateTok)))
	var count int
	require.NoError(t, testDB.QueryRow(context.Background(), `SELECT count(*) FROM external_calendars WHERE id = $1`, work).Scan(&count))
	assert.Equal(t, 0, count)

	// Leaving the household stops it at once.
	m, err := newTestGroupRepo().GetMembership(context.Background(), home, owner.ID)
	require.NoError(t, err)
	require.NoError(t, newTestGroupRepo().EndMembership(context.Background(), m.ID))
	assert.Empty(t, env.externalEvents(t, home, mateTok))
	// The listing drops shares to households the owner left.
	rec = env.do(t, "GET", "/calendar/external/connections", nil, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	var list struct {
		Connections []connectionJSON `json:"connections"`
	}
	parseJSONResponse(t, rec, &list)
	require.Len(t, list.Connections, 1)
	assert.Empty(t, list.Connections[0].Calendars[0].Shares)

	rec = env.do(t, "DELETE", "/calendar/external/connections/"+conn.ID.String(), nil, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	require.NoError(t, testDB.QueryRow(context.Background(), `SELECT count(*) FROM external_events WHERE user_id = $1`, owner.ID).Scan(&count))
	assert.Equal(t, 0, count)
	require.NoError(t, testDB.QueryRow(context.Background(), `SELECT count(*) FROM external_event_overrides WHERE user_id = $1`, owner.ID).Scan(&count))
	assert.Equal(t, 0, count)
}

func TestExternalCalendars_OtherUsersResourcesAreNotFound(t *testing.T) {
	env := newExternalCalendarEnv(t)
	owner, ownerTok := uniqueUser(t, "owner")
	mate, mateTok := uniqueUser(t, "mate")
	home := newHousehold(t, owner.ID, mate.ID)

	rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Phone", "device_id": "d"}, ownerTok)
	requireStatus(t, rec, http.StatusCreated)
	var conn connectionJSON
	parseJSONResponse(t, rec, &conn)
	rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync",
		map[string]any{"calendars": []map[string]any{{"external_id": "c", "name": "C"}}, "events": []map[string]any{}}, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	parseJSONResponse(t, rec, &conn)
	calID := conn.Calendars[0].ID
	id := conn.ID.String()

	for _, c := range []struct {
		method, path string
		body         any
	}{
		{"PATCH", "/calendar/external/connections/" + id, map[string]any{"name": "Mine now"}},
		{"DELETE", "/calendar/external/connections/" + id, nil},
		{"POST", "/calendar/external/connections/" + id + "/sync", nil},
		{"PUT", "/calendar/external/connections/" + id + "/device-sync", map[string]any{"calendars": []any{}, "events": []any{}}},
		{"PUT", "/calendar/external/calendars/" + calID.String() + "/shares", map[string]any{"shares": []map[string]any{{"group_id": home, "visibility": "details"}}}},
		{"PUT", "/calendar/external/overrides", map[string]any{"calendar_id": calID, "external_uid": "x", "visibility": "details"}},
	} {
		rec := env.do(t, c.method, c.path, c.body, mateTok)
		assert.Equal(t, http.StatusNotFound, rec.Code, "%s %s: %s", c.method, c.path, rec.Body.String())
	}
	rec = env.do(t, "GET", "/calendar/external/connections", nil, mateTok)
	requireStatus(t, rec, http.StatusOK)
	assert.JSONEq(t, `{"connections":[]}`, rec.Body.String())

	// The owner's connection survived all of that.
	rec = env.do(t, "GET", "/calendar/external/connections", nil, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	assert.Contains(t, rec.Body.String(), `"name":"Phone"`)
	assert.Empty(t, env.externalEvents(t, home, mateTok))
}

func TestExternalCalendars_CredentialsAreRejected(t *testing.T) {
	env := newExternalCalendarEnv(t)
	_, tok := uniqueUser(t, "cred")
	for _, kind := range []string{"integration", "widget"} {
		for _, c := range []struct{ method, path string }{
			{"GET", "/calendar/external/connections"},
			{"POST", "/calendar/external/connections"},
			{"PATCH", "/calendar/external/connections/" + uuid.NewString()},
			{"DELETE", "/calendar/external/connections/" + uuid.NewString()},
			{"POST", "/calendar/external/connections/" + uuid.NewString() + "/sync"},
			{"PUT", "/calendar/external/connections/" + uuid.NewString() + "/device-sync"},
			{"PUT", "/calendar/external/calendars/" + uuid.NewString() + "/shares"},
			{"GET", "/calendar/external/events/mine"},
			{"GET", "/calendar/external/overrides"},
			{"PUT", "/calendar/external/overrides"},
		} {
			rec := env.do(t, c.method, c.path, map[string]any{}, tok, "X-Test-Credential", kind)
			assert.Equal(t, http.StatusForbidden, rec.Code, "%s %s %s", kind, c.method, c.path)
		}
	}
}

const handlerFeed = "BEGIN:VCALENDAR\r\nX-WR-CALNAME:Sam's Google\r\nBEGIN:VEVENT\r\nUID:x\r\nDTSTART:%s\r\nDURATION:PT1H\r\nSUMMARY:Climbing\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"

func TestExternalCalendars_ICSConnection(t *testing.T) {
	env := newExternalCalendarEnv(t)
	_, tok := uniqueUser(t, "ics")
	start := time.Now().UTC().Add(24 * time.Hour).Format("20060102T150405Z")
	secret := "https://calendar.google.com/calendar/ical/sam/private-0123456789abcdef/basic.ics"

	env.fetcher.body = []byte("<html>Sign in</html>")
	rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "ics", "name": "", "url": secret}, tok)
	requireStatus(t, rec, http.StatusUnprocessableEntity)
	assert.Equal(t, "not_calendar", parseErrorResponse(t, rec)["error"])

	rec = env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "ics", "name": "", "url": "http://example.com/a.ics"}, tok)
	requireStatus(t, rec, http.StatusBadRequest)

	env.fetcher.body = []byte(fmt.Sprintf(handlerFeed, start))
	rec = env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "ics", "name": "", "url": secret}, tok)
	requireStatus(t, rec, http.StatusCreated)
	assert.NotContains(t, rec.Body.String(), "private-0123456789abcdef")
	assert.NotContains(t, rec.Body.String(), "google.com")
	var conn connectionJSON
	parseJSONResponse(t, rec, &conn)
	assert.Equal(t, "ics", conn.Kind)
	assert.Equal(t, "Sam's Google", conn.Name)
	require.Len(t, conn.Calendars, 1)

	var stored []byte
	require.NoError(t, testDB.QueryRow(context.Background(), `SELECT ics_url_encrypted FROM calendar_connections WHERE id = $1`, conn.ID).Scan(&stored))
	assert.NotContains(t, string(stored), "private-0123456789abcdef")

	// The first sync just ran: a manual one is too soon.
	rec = env.do(t, "POST", "/calendar/external/connections/"+conn.ID.String()+"/sync", nil, tok)
	requireStatus(t, rec, http.StatusTooManyRequests)
	// Device-sync is for device connections.
	rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync", map[string]any{"calendars": []any{}, "events": []any{}}, tok)
	requireStatus(t, rec, http.StatusBadRequest)

	rec = env.do(t, "GET", "/calendar/external/events/mine", nil, tok)
	requireStatus(t, rec, http.StatusOK)
	assert.Contains(t, rec.Body.String(), "Climbing")

	var raw map[string]any
	rec = env.do(t, "GET", "/calendar/external/connections", nil, tok)
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &raw))
	assert.NotContains(t, rec.Body.String(), "url")
}

func TestExternalCalendars_AccountDeletionRemovesThem(t *testing.T) {
	env := newExternalCalendarEnv(t)
	user, tok := uniqueUser(t, "leaver")
	rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Phone", "device_id": "d"}, tok)
	requireStatus(t, rec, http.StatusCreated)
	require.NoError(t, newTestUserRepo().SoftDelete(context.Background(), user.ID))
	var count int
	require.NoError(t, testDB.QueryRow(context.Background(), `SELECT count(*) FROM calendar_connections WHERE user_id = $1`, user.ID).Scan(&count))
	assert.Equal(t, 0, count)
}

type overridesJSON struct {
	Overrides []models.EventOverride `json:"overrides"`
}

func TestExternalCalendars_OverridesForUnstoredEventsAndListing(t *testing.T) {
	env := newExternalCalendarEnv(t)
	owner, ownerTok := uniqueUser(t, "owner")
	mate, mateTok := uniqueUser(t, "mate")
	home := newHousehold(t, owner.ID, mate.ID)

	syncDevice := func(tok string, cals []map[string]any, events []map[string]any) connectionJSON {
		rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Phone", "device_id": "d"}, tok)
		require.Contains(t, []int{http.StatusOK, http.StatusCreated}, rec.Code, rec.Body.String())
		var conn connectionJSON
		parseJSONResponse(t, rec, &conn)
		rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync", map[string]any{"calendars": cals, "events": events}, tok)
		requireStatus(t, rec, http.StatusOK)
		parseJSONResponse(t, rec, &conn)
		return conn
	}
	start := time.Now().UTC().Add(24 * time.Hour).Truncate(time.Hour)
	ev := func(uid, title string) map[string]any {
		return map[string]any{"calendar_external_id": "personal", "external_uid": uid, "starts_at": start, "ends_at": start.Add(time.Hour),
			"all_day": false, "title": title, "source_private": false, "free": false}
	}
	cals := []map[string]any{{"external_id": "personal", "name": "Personal"}, {"external_id": "work", "name": "Work"}}
	conn := syncDevice(ownerTok, cals, []map[string]any{ev("movie", "Movie")})
	personal, work := calendarByExt(t, conn, "personal"), calendarByExt(t, conn, "work")

	// The housemate has overrides of their own, which the owner must never see.
	mateConn := syncDevice(mateTok, []map[string]any{{"external_id": "personal", "name": "Mine"}}, []map[string]any{})
	mateCal := mateConn.Calendars[0].ID
	rec := env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": mateCal, "external_uid": "mate-secret", "visibility": "hidden"}, mateTok)
	requireStatus(t, rec, http.StatusNoContent)

	// An override for an event the server never stored is accepted.
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "never-uploaded", "visibility": "hidden"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "movie", "visibility": "busy"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": work, "external_uid": "standup", "visibility": "details"}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	// Not on someone else's calendar.
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": mateCal, "external_uid": "x", "visibility": "details"}, ownerTok)
	requireStatus(t, rec, http.StatusNotFound)

	list := func(tok string) []models.EventOverride {
		rec := env.do(t, "GET", "/calendar/external/overrides", nil, tok)
		requireStatus(t, rec, http.StatusOK)
		var body overridesJSON
		parseJSONResponse(t, rec, &body)
		return body.Overrides
	}
	assert.ElementsMatch(t, []models.EventOverride{
		{CalendarID: personal, ExternalUID: "never-uploaded", Visibility: "hidden"},
		{CalendarID: personal, ExternalUID: "movie", Visibility: "busy"},
		{CalendarID: work, ExternalUID: "standup", Visibility: "details"},
	}, list(ownerTok))
	assert.Equal(t, []models.EventOverride{{CalendarID: mateCal, ExternalUID: "mate-secret", Visibility: "hidden"}}, list(mateTok))

	// A device-sync keeps the overrides of calendars still listed, the
	// never-uploaded one included; a calendar no longer listed takes its
	// overrides with it.
	syncDevice(ownerTok, []map[string]any{{"external_id": "personal", "name": "Personal"}}, []map[string]any{ev("movie", "Movie"), ev("dinner", "Dinner")})
	assert.ElementsMatch(t, []models.EventOverride{
		{CalendarID: personal, ExternalUID: "never-uploaded", Visibility: "hidden"},
		{CalendarID: personal, ExternalUID: "movie", Visibility: "busy"},
	}, list(ownerTok))

	// The overrides still apply to what the household sees.
	rec = env.do(t, "PUT", "/calendar/external/calendars/"+personal.String()+"/shares",
		map[string]any{"shares": []map[string]any{{"group_id": home, "visibility": "details"}}}, ownerTok)
	requireStatus(t, rec, http.StatusOK)
	assert.ElementsMatch(t, []string{"busy:", "Dinner"}, titles(env.externalEvents(t, home, mateTok)))

	// Clearing removes it from the list.
	rec = env.do(t, "PUT", "/calendar/external/overrides", map[string]any{"calendar_id": personal, "external_uid": "never-uploaded", "visibility": nil}, ownerTok)
	requireStatus(t, rec, http.StatusNoContent)
	assert.Equal(t, []models.EventOverride{{CalendarID: personal, ExternalUID: "movie", Visibility: "busy"}}, list(ownerTok))

	// Someone with no overrides gets an empty list, not null.
	_, otherTok := uniqueUser(t, "other")
	rec = env.do(t, "GET", "/calendar/external/overrides", nil, otherTok)
	requireStatus(t, rec, http.StatusOK)
	assert.JSONEq(t, `{"overrides":[]}`, rec.Body.String())
}

// Leaving or being removed from a household ends that person's calendar
// shares with it: rejoining shows nothing until they share again, and
// their shares with other households stay.
func TestExternalCalendars_EndingMembershipDropsSharesWithThatHousehold(t *testing.T) {
	env := newExternalCalendarEnv(t)
	ctx := context.Background()
	groups := services.NewGroupService(newTestGroupRepo(), newTestUserRepo())
	hub := sse.New()
	var seen []sse.Event
	var mu sync.Mutex
	hub.OnPublish(func(e sse.Event) { mu.Lock(); seen = append(seen, e); mu.Unlock() })
	groups.SetHub(hub)
	calendarChanged := func(groupID, userID uuid.UUID) bool {
		mu.Lock()
		defer mu.Unlock()
		for _, e := range seen {
			if e.Type == services.EventCalendarExternalChanged && e.GroupID == groupID.String() && strings.Contains(string(e.Payload), userID.String()) {
				return true
			}
		}
		return false
	}

	admin, adminTok := uniqueUser(t, "admin")
	sam, samTok := uniqueUser(t, "sam")
	alex, alexTok := uniqueUser(t, "alex")
	home := newHousehold(t, admin.ID, sam.ID, alex.ID)
	other := newHousehold(t, admin.ID, sam.ID, alex.ID)

	start := time.Now().UTC().Add(24 * time.Hour).Truncate(time.Hour)
	share := func(tok string, deviceID string, title string) uuid.UUID {
		rec := env.do(t, "POST", "/calendar/external/connections", map[string]any{"kind": "device", "name": "Phone", "device_id": deviceID}, tok)
		require.Contains(t, []int{http.StatusOK, http.StatusCreated}, rec.Code, rec.Body.String())
		var conn connectionJSON
		parseJSONResponse(t, rec, &conn)
		rec = env.do(t, "PUT", "/calendar/external/connections/"+conn.ID.String()+"/device-sync", map[string]any{
			"calendars": []map[string]any{{"external_id": "c", "name": "C"}},
			"events": []map[string]any{{"calendar_external_id": "c", "external_uid": "e", "starts_at": start, "ends_at": start.Add(time.Hour),
				"all_day": false, "title": title, "source_private": false, "free": false}},
		}, tok)
		requireStatus(t, rec, http.StatusOK)
		parseJSONResponse(t, rec, &conn)
		calID := conn.Calendars[0].ID
		rec = env.do(t, "PUT", "/calendar/external/calendars/"+calID.String()+"/shares", map[string]any{"shares": []map[string]any{
			{"group_id": home, "visibility": "details"}, {"group_id": other, "visibility": "details"},
		}}, tok)
		requireStatus(t, rec, http.StatusOK)
		return calID
	}
	samCal := share(samTok, "sam-phone", "Sam's gig")
	alexCal := share(alexTok, "alex-phone", "Alex's match")
	shareRows := func(calID, groupID uuid.UUID) int {
		var n int
		require.NoError(t, testDB.QueryRow(ctx, `SELECT count(*) FROM external_calendar_shares WHERE calendar_id = $1 AND group_id = $2`, calID, groupID).Scan(&n))
		return n
	}
	assert.ElementsMatch(t, []string{"Sam's gig", "Alex's match"}, titles(env.externalEvents(t, home, adminTok)))

	// Sam leaves: Sam's share with home goes, the one with other stays,
	// and home is told to refresh.
	require.NoError(t, groups.LeaveGroup(ctx, sam.ID, home))
	assert.Equal(t, 0, shareRows(samCal, home))
	assert.Equal(t, 1, shareRows(samCal, other))
	assert.Equal(t, 1, shareRows(alexCal, home), "other members' shares are untouched")
	assert.True(t, calendarChanged(home, sam.ID))
	assert.Equal(t, []string{"Alex's match"}, titles(env.externalEvents(t, home, adminTok)))
	assert.ElementsMatch(t, []string{"Sam's gig", "Alex's match"}, titles(env.externalEvents(t, other, adminTok)))

	// Alex is removed by the admin: same.
	require.NoError(t, groups.RemoveMember(ctx, admin.ID, home, alex.ID))
	assert.Equal(t, 0, shareRows(alexCal, home))
	assert.Equal(t, 1, shareRows(alexCal, other))
	assert.True(t, calendarChanged(home, alex.ID))
	assert.Empty(t, env.externalEvents(t, home, adminTok))

	// Sam rejoins: nothing is shared until Sam shares again.
	addTestMembership(t, home, sam.ID, "member")
	assert.Empty(t, env.externalEvents(t, home, adminTok))
	rec := env.do(t, "GET", "/calendar/external/connections", nil, samTok)
	requireStatus(t, rec, http.StatusOK)
	var list struct {
		Connections []connectionJSON `json:"connections"`
	}
	parseJSONResponse(t, rec, &list)
	assert.Equal(t, []models.CalendarShare{{GroupID: other, Visibility: "details"}}, list.Connections[0].Calendars[0].Shares)
	rec = env.do(t, "PUT", "/calendar/external/calendars/"+samCal.String()+"/shares", map[string]any{"shares": []map[string]any{
		{"group_id": home, "visibility": "busy"}, {"group_id": other, "visibility": "details"},
	}}, samTok)
	requireStatus(t, rec, http.StatusOK)
	assert.Equal(t, []string{"busy:"}, titles(env.externalEvents(t, home, adminTok)))
	assert.ElementsMatch(t, []string{"Sam's gig", "Alex's match"}, titles(env.externalEvents(t, other, adminTok)))
}
