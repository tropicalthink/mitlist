package ical

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var (
	winStart = time.Date(2026, 11, 23, 0, 0, 0, 0, time.UTC)
	winEnd   = winStart.AddDate(0, 0, 91)
)

func feed(body string) []byte {
	return []byte("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:test\r\n" + strings.ReplaceAll(strings.TrimSpace(body), "\n", "\r\n") + "\r\nEND:VCALENDAR\r\n")
}

func parse(t *testing.T, body string) *Calendar {
	t.Helper()
	cal, err := Parse(feed(body), winStart, winEnd, Limits{})
	require.NoError(t, err)
	return cal
}

func starts(cal *Calendar) []string {
	var out []string
	for _, e := range cal.Events {
		out = append(out, e.Start.Format(time.RFC3339))
	}
	return out
}

func TestParse_NotACalendar(t *testing.T) {
	for _, data := range []string{"", "<html><body>Sign in</body></html>", "BEGIN:VCARD\r\nEND:VCARD", "{\"a\":1}"} {
		_, err := Parse([]byte(data), winStart, winEnd, Limits{})
		assert.ErrorIs(t, err, ErrNotCalendar, "%q", data)
	}
}

func TestParse_BOMAndLFLineEndingsAndFolding(t *testing.T) {
	data := "\xef\xbb\xbfBEGIN:VCALENDAR\nX-WR-CALNAME:Sam\\, work\nBEGIN:VEVENT\nUID:a\nDTSTART:20261201T100000Z\nDTEND:20261201T110000Z\nSUMMARY:Dentist\n  appointment\nEND:VEVENT\nEND:VCALENDAR\n"
	cal, err := Parse([]byte(data), winStart, winEnd, Limits{})
	require.NoError(t, err)
	assert.Equal(t, "Sam, work", cal.Name)
	require.Len(t, cal.Events, 1)
	assert.Equal(t, "Dentist appointment", cal.Events[0].Title)
}

func TestParse_TimedEventWithTZID(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:berlin
DTSTART;TZID=Europe/Berlin:20261201T190000
DTEND;TZID=Europe/Berlin:20261201T213000
SUMMARY:Movie
END:VEVENT
BEGIN:VEVENT
UID:ny
DTSTART;TZID="America/New_York":20260615T090000
DTEND;TZID="America/New_York":20260615T100000
END:VEVENT`)
	require.Len(t, cal.Events, 1, "June event is outside the window")
	e := cal.Events[0]
	assert.Equal(t, time.Date(2026, 12, 1, 18, 0, 0, 0, time.UTC), e.Start)
	assert.Equal(t, time.Date(2026, 12, 1, 20, 30, 0, 0, time.UTC), e.End)
	assert.False(t, e.AllDay)
	assert.Equal(t, "Movie", e.Title)
}

func TestParse_FloatingUsesCalendarTimezone(t *testing.T) {
	cal := parse(t, `
X-WR-TIMEZONE:Asia/Tokyo
BEGIN:VEVENT
UID:f
DTSTART:20261201T090000
DURATION:PT2H
END:VEVENT`)
	require.Len(t, cal.Events, 1)
	assert.Equal(t, time.Date(2026, 12, 1, 0, 0, 0, 0, time.UTC), cal.Events[0].Start)
	assert.Equal(t, time.Date(2026, 12, 1, 2, 0, 0, 0, time.UTC), cal.Events[0].End)
}

func TestParse_InlineVTIMEZONEAndWindowsName(t *testing.T) {
	cal := parse(t, `
BEGIN:VTIMEZONE
TZID:Custom Zone
BEGIN:STANDARD
DTSTART:16011028T030000
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010325T020000
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
UID:winter
DTSTART;TZID=Custom Zone:20261210T120000
DTEND;TZID=Custom Zone:20261210T130000
END:VEVENT
BEGIN:VEVENT
UID:windows
DTSTART;TZID=Tokyo Standard Time:20261211T120000
DTEND;TZID=Tokyo Standard Time:20261211T130000
END:VEVENT
BEGIN:VEVENT
UID:unknown
DTSTART;TZID=Nowhere/Land:20261212T120000
END:VEVENT`)
	require.Len(t, cal.Events, 3)
	assert.Equal(t, time.Date(2026, 12, 10, 11, 0, 0, 0, time.UTC), cal.Events[0].Start)
	assert.Equal(t, time.Date(2026, 12, 11, 3, 0, 0, 0, time.UTC), cal.Events[1].Start)
	// An unknown zone falls back to the calendar default (UTC here).
	assert.Equal(t, time.Date(2026, 12, 12, 12, 0, 0, 0, time.UTC), cal.Events[2].Start)
}

func TestVTZZone_SummerOffset(t *testing.T) {
	data := feed(`
BEGIN:VTIMEZONE
TZID:Custom Zone
BEGIN:STANDARD
DTSTART:16011028T030000
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=10
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:16010325T020000
RRULE:FREQ=YEARLY;BYDAY=-1SU;BYMONTH=3
TZOFFSETFROM:+0100
TZOFFSETTO:+0200
END:DAYLIGHT
END:VTIMEZONE
BEGIN:VEVENT
UID:summer
DTSTART;TZID=Custom Zone:20270615T120000
END:VEVENT`)
	cal, err := Parse(data, time.Date(2027, 6, 1, 0, 0, 0, 0, time.UTC), time.Date(2027, 7, 1, 0, 0, 0, 0, time.UTC), Limits{})
	require.NoError(t, err)
	require.Len(t, cal.Events, 1)
	assert.Equal(t, time.Date(2027, 6, 15, 10, 0, 0, 0, time.UTC), cal.Events[0].Start)
}

func TestParse_AllDay(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:trip
DTSTART;VALUE=DATE:20261224
DTEND;VALUE=DATE:20261228
SUMMARY:Trip to Lisbon
TRANSP:TRANSPARENT
END:VEVENT
BEGIN:VEVENT
UID:oneday
DTSTART;VALUE=DATE:20261205
END:VEVENT`)
	require.Len(t, cal.Events, 2)
	one, trip := cal.Events[0], cal.Events[1]
	assert.True(t, one.AllDay)
	assert.Equal(t, time.Date(2026, 12, 5, 0, 0, 0, 0, time.UTC), one.Start)
	assert.Equal(t, time.Date(2026, 12, 6, 0, 0, 0, 0, time.UTC), one.End)
	assert.True(t, trip.AllDay)
	assert.True(t, trip.Free)
	assert.Equal(t, time.Date(2026, 12, 28, 0, 0, 0, 0, time.UTC), trip.End)
}

func TestParse_CancelledPrivateAndFree(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:gone
DTSTART:20261201T100000Z
STATUS:CANCELLED
SUMMARY:Cancelled
END:VEVENT
BEGIN:VEVENT
UID:priv
DTSTART:20261202T100000Z
CLASS:PRIVATE
SUMMARY:Therapy
END:VEVENT
BEGIN:VEVENT
UID:conf
DTSTART:20261203T100000Z
CLASS:CONFIDENTIAL
END:VEVENT
BEGIN:VEVENT
UID:pub
DTSTART:20261204T100000Z
CLASS:PUBLIC
END:VEVENT`)
	require.Len(t, cal.Events, 3)
	assert.True(t, cal.Events[0].Private)
	assert.True(t, cal.Events[1].Private)
	assert.False(t, cal.Events[2].Private)
	for _, e := range cal.Events {
		assert.NotEqual(t, "gone", e.UID)
	}
}

func TestParse_WeeklyRecurrenceWithExdateAndOverrides(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:yoga
DTSTART;TZID=Europe/Berlin:20261103T180000
DTEND;TZID=Europe/Berlin:20261103T190000
RRULE:FREQ=WEEKLY;BYDAY=TU;UNTIL=20261222T230000Z
EXDATE;TZID=Europe/Berlin:20261208T180000
SUMMARY:Yoga
END:VEVENT
BEGIN:VEVENT
UID:yoga
RECURRENCE-ID;TZID=Europe/Berlin:20261201T180000
DTSTART;TZID=Europe/Berlin:20261202T200000
DTEND;TZID=Europe/Berlin:20261202T210000
SUMMARY:Yoga (moved)
END:VEVENT
BEGIN:VEVENT
UID:yoga
RECURRENCE-ID;TZID=Europe/Berlin:20261215T180000
STATUS:CANCELLED
DTSTART;TZID=Europe/Berlin:20261215T180000
END:VEVENT`)
	assert.Equal(t, []string{
		"2026-11-24T17:00:00Z",
		"2026-12-02T19:00:00Z", // moved instance
		"2026-12-22T17:00:00Z",
	}, starts(cal))
	assert.Equal(t, "Yoga (moved)", cal.Events[1].Title)
	for _, e := range cal.Events {
		assert.Equal(t, "yoga", e.UID)
	}
}

func TestParse_RecurrenceKeepsLocalTimeAcrossDST(t *testing.T) {
	data := feed(`
BEGIN:VEVENT
UID:standup
DTSTART;TZID=Europe/Berlin:20270322T090000
DTEND;TZID=Europe/Berlin:20270322T091500
RRULE:FREQ=DAILY;COUNT=10
END:VEVENT`)
	cal, err := Parse(data, time.Date(2027, 3, 20, 0, 0, 0, 0, time.UTC), time.Date(2027, 4, 10, 0, 0, 0, 0, time.UTC), Limits{})
	require.NoError(t, err)
	require.Len(t, cal.Events, 10)
	assert.Equal(t, time.Date(2027, 3, 22, 8, 0, 0, 0, time.UTC), cal.Events[0].Start)
	// After the 28 March switch, 09:00 Berlin is 07:00 UTC.
	assert.Equal(t, time.Date(2027, 3, 31, 7, 0, 0, 0, time.UTC), cal.Events[9].Start)
	assert.Equal(t, 15*time.Minute, cal.Events[9].End.Sub(cal.Events[9].Start))
}

func TestParse_MonthlyAndYearlyRules(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:lastfri
DTSTART:20260130T180000Z
RRULE:FREQ=MONTHLY;BYDAY=-1FR
END:VEVENT
BEGIN:VEVENT
UID:lastweekday
DTSTART:20260130T080000Z
RRULE:FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=13
END:VEVENT
BEGIN:VEVENT
UID:bday
DTSTART;VALUE=DATE:20000115
RRULE:FREQ=YEARLY
END:VEVENT
BEGIN:VEVENT
UID:biweekly
DTSTART:20260105T070000Z
RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=MO
END:VEVENT`)
	byUID := map[string][]string{}
	for _, e := range cal.Events {
		byUID[e.UID] = append(byUID[e.UID], e.Start.Format("2006-01-02"))
	}
	assert.Equal(t, []string{"2026-11-27", "2026-12-25", "2027-01-29"}, byUID["lastfri"])
	// COUNT=13 from January 2026 ends with January 2027.
	assert.Equal(t, []string{"2026-11-30", "2026-12-31", "2027-01-29"}, byUID["lastweekday"])
	assert.Equal(t, []string{"2027-01-15"}, byUID["bday"])
	assert.Equal(t, []string{"2026-11-23", "2026-12-07", "2026-12-21", "2027-01-04", "2027-01-18", "2027-02-01", "2027-02-15"}, byUID["biweekly"])
}

func TestParse_RDATEAndCountWithPastStart(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:r
DTSTART:20261201T100000Z
RDATE:20261210T100000Z,20261220T100000Z
EXDATE:20261220T100000Z
END:VEVENT
BEGIN:VEVENT
UID:c
DTSTART:20261120T100000Z
RRULE:FREQ=DAILY;COUNT=5
END:VEVENT`)
	byUID := map[string]int{}
	for _, e := range cal.Events {
		byUID[e.UID]++
	}
	assert.Equal(t, 2, byUID["r"])
	// 20..24 November: only 23 and 24 overlap the window.
	assert.Equal(t, 2, byUID["c"])
}

func TestParse_HostileRulesAreBounded(t *testing.T) {
	var b strings.Builder
	for i := 0; i < 2000; i++ {
		fmt.Fprintf(&b, "BEGIN:VEVENT\nUID:s%d\nDTSTART:19700101T000000Z\nRRULE:FREQ=SECONDLY\nEND:VEVENT\n", i)
		fmt.Fprintf(&b, "BEGIN:VEVENT\nUID:n%d\nDTSTART:00010101T000000Z\nRRULE:FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30;COUNT=5\nEND:VEVENT\n", i)
		fmt.Fprintf(&b, "BEGIN:VEVENT\nUID:d%d\nDTSTART:00010101T000000Z\nRRULE:FREQ=DAILY;COUNT=99999\nEND:VEVENT\n", i)
	}
	start := time.Now()
	cal, err := Parse(feed(b.String()), winStart, winEnd, Limits{})
	require.NoError(t, err)
	assert.Less(t, time.Since(start), 10*time.Second)
	assert.LessOrEqual(t, len(cal.Events), defaultMaxEvents)
	assert.True(t, cal.Truncated)
}

func TestParse_EverySecondRuleIsCapped(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:spam
DTSTART:20261123T000000Z
RRULE:FREQ=SECONDLY
END:VEVENT`)
	assert.Len(t, cal.Events, defaultMaxPerSeries)
	assert.True(t, cal.Truncated)
}

func TestParse_UnsupportedRuleKeepsFirstInstance(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:w
DTSTART:20261201T100000Z
RRULE:FREQ=YEARLY;BYWEEKNO=20
END:VEVENT
BEGIN:VEVENT
UID:h
DTSTART:20261201T100000Z
RRULE:FREQ=MINUTELY;BYHOUR=1,2,3
END:VEVENT`)
	assert.Len(t, cal.Events, 2)
}

func TestParse_LimitsEventsAndTitles(t *testing.T) {
	var b strings.Builder
	for i := 0; i < 30; i++ {
		fmt.Fprintf(&b, "BEGIN:VEVENT\nUID:e%d\nDTSTART:202612%02dT100000Z\nSUMMARY:%s\nEND:VEVENT\n", i, i%28+1, strings.Repeat("é", 300))
	}
	cal, err := Parse(feed(b.String()), winStart, winEnd, Limits{MaxEvents: 10})
	require.NoError(t, err)
	assert.Len(t, cal.Events, 10)
	assert.True(t, cal.Truncated)
	assert.Equal(t, 200, len([]rune(cal.Events[0].Title)))
}

func TestParse_DuplicateInstancesAndMissingUID(t *testing.T) {
	cal := parse(t, `
BEGIN:VEVENT
UID:dup
DTSTART:20261201T100000Z
END:VEVENT
BEGIN:VEVENT
UID:dup
DTSTART:20261201T100000Z
END:VEVENT
BEGIN:VEVENT
DTSTART:20261202T100000Z
SUMMARY:No uid
END:VEVENT
BEGIN:VEVENT
SUMMARY:No start
END:VEVENT`)
	require.Len(t, cal.Events, 2)
	assert.True(t, strings.HasPrefix(cal.Events[1].UID, "mitlist-"))
}

func TestParseDuration(t *testing.T) {
	for in, want := range map[string]time.Duration{
		"PT1H30M": 90 * time.Minute, "P1D": 24 * time.Hour, "P2W": 14 * 24 * time.Hour,
		"P1DT2H": 26 * time.Hour, "-PT15M": -15 * time.Minute,
	} {
		got, ok := parseDuration(in)
		assert.True(t, ok, in)
		assert.Equal(t, want, got, in)
	}
	for _, bad := range []string{"", "P", "1H", "PT", "P99999999D", "PTXH"} {
		_, ok := parseDuration(bad)
		assert.False(t, ok, bad)
	}
}
