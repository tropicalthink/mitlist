// Package ical turns an iCalendar (RFC 5545) feed into the concrete event
// occurrences that fall inside a time window: the shape the household
// calendar stores for an ICS subscription.
//
// It is deliberately focused rather than complete. It reads VEVENTs with
// their time zones (IANA names, Windows names and inline VTIMEZONE
// definitions), all-day dates, DTEND or DURATION, RRULE/RDATE/EXDATE and
// RECURRENCE-ID overrides, and drops cancelled events. Everything it does is
// bounded: a feed is read once, recurrences are expanded only inside the
// window with per-series and per-feed work budgets, so a hostile feed (an
// every-second RRULE, a rule that never matches, thousands of time zones)
// costs a bounded amount of CPU and memory.
package ical

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	// Feeds name IANA zones; embed the database so a host without
	// /usr/share/zoneinfo still resolves them.
	_ "time/tzdata"
)

// ErrNotCalendar means the data is not an iCalendar feed (no VCALENDAR).
var ErrNotCalendar = errors.New("ical: not an iCalendar feed")

// Limits bound the work Parse does. Zero fields take the defaults.
type Limits struct {
	// MaxEvents caps the occurrences returned; the earliest are kept.
	MaxEvents int
	// MaxComponents caps the VEVENTs read from the feed.
	MaxComponents int
	// MaxPerSeries caps the occurrences one recurring series contributes.
	MaxPerSeries int
	// MaxWork caps the recurrence work units (rule periods and candidate
	// dates) spent on the whole feed.
	MaxWork int
	// MaxTitleRunes cuts titles to this many characters.
	MaxTitleRunes int
}

const (
	defaultMaxEvents     = 5000
	defaultMaxComponents = 50000
	defaultMaxPerSeries  = 1000
	defaultMaxWork       = 5_000_000
	defaultMaxTitleRunes = 200
	maxSeriesPeriods     = 100_000
	maxTimeZones         = 200
	maxObservances       = 400
	maxDepth             = 8
)

func (l Limits) withDefaults() Limits {
	if l.MaxEvents <= 0 {
		l.MaxEvents = defaultMaxEvents
	}
	if l.MaxComponents <= 0 {
		l.MaxComponents = defaultMaxComponents
	}
	if l.MaxPerSeries <= 0 {
		l.MaxPerSeries = defaultMaxPerSeries
	}
	if l.MaxWork <= 0 {
		l.MaxWork = defaultMaxWork
	}
	if l.MaxTitleRunes <= 0 {
		l.MaxTitleRunes = defaultMaxTitleRunes
	}
	return l
}

// Occurrence is one concrete instance of an event.
type Occurrence struct {
	// UID identifies the event; every instance of a recurring series
	// shares it.
	UID string
	// Start and End are UTC. For all-day events they are the UTC midnights
	// of the local dates, End exclusive.
	Start  time.Time
	End    time.Time
	AllDay bool
	// Title is the SUMMARY, trimmed and cut; empty when there is none.
	Title string
	// Private is set for CLASS:PRIVATE and CLASS:CONFIDENTIAL.
	Private bool
	// Free is set for TRANSP:TRANSPARENT.
	Free bool
}

// Calendar is the result of reading a feed.
type Calendar struct {
	// Name is X-WR-CALNAME, when the feed has one.
	Name string
	// Color is X-APPLE-CALENDAR-COLOR, when the feed has one.
	Color string
	// Events are the occurrences overlapping the window, ordered by start.
	Events []Occurrence
	// Truncated reports that a limit cut the result short.
	Truncated bool
}

// Parse reads data and returns the occurrences that overlap
// [windowStart, windowEnd).
func Parse(data []byte, windowStart, windowEnd time.Time, limits Limits) (*Calendar, error) {
	limits = limits.withDefaults()
	root, truncated, err := readComponents(data, limits.MaxComponents)
	if err != nil {
		return nil, err
	}
	cal := &Calendar{Truncated: truncated}
	defaultZone := zone(utcZone{})
	for _, p := range root.props {
		switch p.name {
		case "X-WR-CALNAME":
			cal.Name = cutRunes(cleanText(unescapeText(p.value)), 200)
		case "X-APPLE-CALENDAR-COLOR":
			cal.Color = cutRunes(strings.TrimSpace(p.value), 32)
		case "X-WR-TIMEZONE":
			if loc, ok := loadIANA(strings.TrimSpace(p.value)); ok {
				defaultZone = locZone{loc: loc}
			}
		}
	}

	zones := newZoneResolver(root, defaultZone)
	b := &budget{left: limits.MaxWork}
	win := window{start: windowStart.UTC(), end: windowEnd.UTC()}

	// Group the VEVENTs by UID: a series is its master plus the overrides
	// carrying a RECURRENCE-ID.
	type series struct {
		masters   []*event
		overrides []*event
	}
	byUID := map[string]*series{}
	var order []string
	for _, c := range root.children {
		if c.name != "VEVENT" {
			continue
		}
		ev, ok := readEvent(c, zones, limits.MaxTitleRunes)
		if !ok {
			continue
		}
		s := byUID[ev.uid]
		if s == nil {
			s = &series{}
			byUID[ev.uid] = s
			order = append(order, ev.uid)
		}
		if ev.recurrenceID != nil {
			s.overrides = append(s.overrides, ev)
		} else {
			s.masters = append(s.masters, ev)
		}
	}

	var out []Occurrence
	for _, uid := range order {
		s := byUID[uid]
		if b.exhausted() {
			cal.Truncated = true
			break
		}
		if len(s.masters) == 0 {
			// Overrides without their series (a single shared instance):
			// each stands on its own.
			for _, o := range s.overrides {
				if o.cancelled {
					continue
				}
				out = appendIfInWindow(out, o, o.startUTC, o.endFor(o.startUTC, o.start.naive), win)
			}
			continue
		}
		for i, m := range s.masters {
			if m.cancelled {
				continue
			}
			var overrides []*event
			if i == 0 {
				overrides = s.overrides
			}
			occ, cut := expandSeries(m, overrides, win, limits.MaxPerSeries, b)
			if cut {
				cal.Truncated = true
			}
			out = append(out, occ...)
		}
	}

	// One row per (uid, start): a feed may list the same instance twice.
	sort.SliceStable(out, func(i, j int) bool {
		if !out[i].Start.Equal(out[j].Start) {
			return out[i].Start.Before(out[j].Start)
		}
		return out[i].UID < out[j].UID
	})
	seen := make(map[string]struct{}, len(out))
	deduped := out[:0]
	for _, o := range out {
		key := o.UID + "\x00" + o.Start.Format(time.RFC3339)
		if _, dup := seen[key]; dup {
			continue
		}
		seen[key] = struct{}{}
		deduped = append(deduped, o)
	}
	out = deduped
	if len(out) > limits.MaxEvents {
		out = out[:limits.MaxEvents]
		cal.Truncated = true
	}
	cal.Events = out
	return cal, nil
}

type window struct{ start, end time.Time }

func (w window) overlaps(start, end time.Time) bool {
	if !start.Before(w.end) {
		return false
	}
	if end.After(start) {
		return end.After(w.start)
	}
	return !start.Before(w.start)
}

func appendIfInWindow(out []Occurrence, ev *event, start, end time.Time, w window) []Occurrence {
	if !w.overlaps(start, end) {
		return out
	}
	return append(out, Occurrence{
		UID:     ev.uid,
		Start:   start,
		End:     end,
		AllDay:  ev.start.isDate,
		Title:   ev.title,
		Private: ev.private,
		Free:    ev.free,
	})
}

// budget is the feed-wide allowance of recurrence work.
type budget struct{ left int }

func (b *budget) spend(n int) bool {
	b.left -= n
	return b.left >= 0
}

func (b *budget) exhausted() bool { return b.left < 0 }

// ---------------------------------------------------------------------------
// Content lines and components
// ---------------------------------------------------------------------------

type property struct {
	name   string
	params map[string][]string
	value  string
}

func (p property) param(name string) string {
	if v := p.params[name]; len(v) > 0 {
		return v[0]
	}
	return ""
}

type component struct {
	name     string
	props    []property
	children []*component
}

func (c *component) prop(name string) (property, bool) {
	for _, p := range c.props {
		if p.name == name {
			return p, true
		}
	}
	return property{}, false
}

// readComponents unfolds the content lines and builds the VCALENDAR tree,
// keeping only what Parse reads: calendar properties, VEVENTs (without
// their alarms) and VTIMEZONEs with their observances.
func readComponents(data []byte, maxEvents int) (*component, bool, error) {
	data = bytes.TrimPrefix(data, []byte("\xef\xbb\xbf"))
	lines := unfold(data)
	first := -1
	for i, l := range lines {
		if strings.TrimSpace(l) != "" {
			first = i
			break
		}
	}
	if first < 0 || !strings.EqualFold(strings.TrimSpace(lines[first]), "BEGIN:VCALENDAR") {
		return nil, false, ErrNotCalendar
	}

	root := &component{name: "VCALENDAR"}
	// stack holds the open components; nil entries are components whose
	// content is skipped (alarms, to-dos, unknown ones).
	stack := []*component{root}
	events := 0
	truncated := false
	for _, line := range lines[first+1:] {
		if line == "" {
			continue
		}
		p, ok := parseLine(line)
		if !ok {
			continue
		}
		switch p.name {
		case "BEGIN":
			name := strings.ToUpper(strings.TrimSpace(p.value))
			if len(stack) >= maxDepth {
				return nil, false, ErrNotCalendar
			}
			parent := stack[len(stack)-1]
			var child *component
			if parent != nil {
				switch {
				case parent == root && name == "VEVENT":
					if events < maxEvents {
						child = &component{name: name}
						events++
					} else {
						truncated = true
					}
				case parent == root && name == "VTIMEZONE":
					child = &component{name: name}
				case parent.name == "VTIMEZONE" && (name == "STANDARD" || name == "DAYLIGHT"):
					child = &component{name: name}
				}
				if child != nil {
					parent.children = append(parent.children, child)
				}
			}
			stack = append(stack, child)
		case "END":
			if len(stack) > 1 {
				stack = stack[:len(stack)-1]
			} else {
				// END:VCALENDAR; anything after it is ignored.
				return root, truncated, nil
			}
		default:
			if cur := stack[len(stack)-1]; cur != nil {
				cur.props = append(cur.props, p)
			}
		}
	}
	return root, truncated, nil
}

// unfold splits data into logical lines, joining folded continuations.
func unfold(data []byte) []string {
	var lines []string
	var cur strings.Builder
	have := false
	for len(data) > 0 {
		i := bytes.IndexByte(data, '\n')
		var raw []byte
		if i < 0 {
			raw, data = data, nil
		} else {
			raw, data = data[:i], data[i+1:]
		}
		raw = bytes.TrimSuffix(raw, []byte("\r"))
		if len(raw) > 0 && (raw[0] == ' ' || raw[0] == '\t') && have {
			cur.Write(raw[1:])
			continue
		}
		if have {
			lines = append(lines, cur.String())
			cur.Reset()
		}
		cur.Write(raw)
		have = true
	}
	if have {
		lines = append(lines, cur.String())
	}
	return lines
}

// parseLine splits "NAME;PARAM=a,b;Q=\"x:y\":value".
func parseLine(line string) (property, bool) {
	i := strings.IndexAny(line, ";:")
	if i <= 0 {
		return property{}, false
	}
	p := property{name: strings.ToUpper(strings.TrimSpace(line[:i]))}
	rest := line[i:]
	for len(rest) > 0 && rest[0] == ';' {
		rest = rest[1:]
		eq := strings.IndexByte(rest, '=')
		if eq < 0 {
			return property{}, false
		}
		name := strings.ToUpper(strings.TrimSpace(rest[:eq]))
		rest = rest[eq+1:]
		var values []string
		for {
			if len(rest) > 0 && rest[0] == '"' {
				end := strings.IndexByte(rest[1:], '"')
				if end < 0 {
					return property{}, false
				}
				values = append(values, rest[1:1+end])
				rest = rest[2+end:]
			} else {
				end := strings.IndexAny(rest, ",;:")
				if end < 0 {
					return property{}, false
				}
				values = append(values, rest[:end])
				rest = rest[end:]
			}
			if len(rest) > 0 && rest[0] == ',' {
				rest = rest[1:]
				continue
			}
			break
		}
		if p.params == nil {
			p.params = map[string][]string{}
		}
		p.params[name] = values
	}
	if len(rest) == 0 || rest[0] != ':' {
		return property{}, false
	}
	p.value = rest[1:]
	return p, true
}

func unescapeText(s string) string {
	if !strings.Contains(s, "\\") {
		return s
	}
	var b strings.Builder
	b.Grow(len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '\\' && i+1 < len(s) {
			i++
			switch s[i] {
			case 'n', 'N':
				b.WriteByte('\n')
			default:
				b.WriteByte(s[i])
			}
			continue
		}
		b.WriteByte(c)
	}
	return b.String()
}

// cleanText makes a one-line title: valid UTF-8, no control characters,
// whitespace collapsed.
func cleanText(s string) string {
	s = strings.ToValidUTF8(s, "")
	return strings.Join(strings.FieldsFunc(s, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '\r' || r < 0x20 || r == 0x7f
	}), " ")
}

func cutRunes(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	r := []rune(s)
	return strings.TrimSpace(string(r[:n]))
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

// dtValue is a DATE or DATE-TIME as written: naive holds the wall-clock
// fields in a UTC time.Time.
type dtValue struct {
	naive  time.Time
	isDate bool
	utc    bool
	zone   zone
}

// toUTC is the absolute instant (for a date, its UTC midnight).
func (d dtValue) toUTC() time.Time {
	if d.isDate || d.utc {
		return d.naive
	}
	return d.zone.toUTC(d.naive)
}

type event struct {
	uid       string
	title     string
	private   bool
	free      bool
	cancelled bool
	start     dtValue
	startUTC  time.Time
	// The end is the start plus a wall-clock length (when DTEND shares
	// DTSTART's zone, or for DURATION) or plus an absolute one.
	naiveLen     time.Duration
	absLen       time.Duration
	absolute     bool
	rule         *rule
	ruleBad      bool
	rdates       []dtValue
	exdates      []dtValue
	recurrenceID *dtValue
}

// endFor is the end of the instance starting at start (naive: its wall clock).
func (e *event) endFor(start time.Time, naive time.Time) time.Time {
	if e.start.isDate {
		days := int(e.naiveLen / (24 * time.Hour))
		if days < 1 {
			days = 1
		}
		return start.AddDate(0, 0, days)
	}
	var end time.Time
	if e.absolute {
		end = start.Add(e.absLen)
	} else if e.start.utc {
		end = start.Add(e.naiveLen)
	} else {
		end = e.start.zone.toUTC(naive.Add(e.naiveLen))
	}
	if end.Before(start) {
		return start
	}
	return end
}

func readEvent(c *component, zones *zoneResolver, maxTitle int) (*event, bool) {
	ev := &event{}
	var (
		haveStart bool
		end       *dtValue
		dur       *time.Duration
		rawStart  string
	)
	for _, p := range c.props {
		switch p.name {
		case "UID":
			ev.uid = strings.TrimSpace(p.value)
		case "SUMMARY":
			ev.title = cutRunes(cleanText(unescapeText(p.value)), maxTitle)
		case "DTSTART":
			v, ok := parseDT(p.value, p, zones, zones.def)
			if !ok {
				return nil, false
			}
			ev.start, haveStart, rawStart = v, true, p.value
		case "DTEND":
			if v, ok := parseDT(p.value, p, zones, zones.def); ok {
				end = &v
			}
		case "DURATION":
			if d, ok := parseDuration(p.value); ok {
				dur = &d
			}
		case "RRULE":
			if ev.rule != nil || ev.ruleBad {
				// One RRULE per series; a second one is not something
				// calendar apps write.
				continue
			}
			r, err := parseRule(p.value)
			if err != nil {
				ev.ruleBad = true
				continue
			}
			ev.rule = r
		case "RDATE", "EXDATE":
			for _, raw := range strings.Split(p.value, ",") {
				if p.param("VALUE") == "PERIOD" || strings.Contains(raw, "/") {
					raw = strings.SplitN(raw, "/", 2)[0]
				}
				// The event's own zone is not known yet; floating values are
				// resolved against it below.
				v, ok := parseDT(raw, p, zones, nil)
				if !ok {
					continue
				}
				if p.name == "RDATE" {
					if len(ev.rdates) < 1000 {
						ev.rdates = append(ev.rdates, v)
					}
				} else if len(ev.exdates) < 5000 {
					ev.exdates = append(ev.exdates, v)
				}
			}
		case "RECURRENCE-ID":
			if v, ok := parseDT(p.value, p, zones, nil); ok {
				ev.recurrenceID = &v
			}
		case "STATUS":
			ev.cancelled = strings.EqualFold(strings.TrimSpace(p.value), "CANCELLED")
		case "CLASS":
			cls := strings.ToUpper(strings.TrimSpace(p.value))
			ev.private = cls == "PRIVATE" || cls == "CONFIDENTIAL"
		case "TRANSP":
			ev.free = strings.EqualFold(strings.TrimSpace(p.value), "TRANSPARENT")
		}
	}
	if !haveStart {
		return nil, false
	}
	if ev.uid == "" {
		sum := sha256.Sum256([]byte(rawStart + "\x00" + ev.title))
		ev.uid = "mitlist-" + hex.EncodeToString(sum[:12])
	}
	if len(ev.uid) > 1024 {
		sum := sha256.Sum256([]byte(ev.uid))
		ev.uid = "mitlist-" + hex.EncodeToString(sum[:16])
	}

	// Floating DTSTART-relative values (EXDATE/RDATE/RECURRENCE-ID without a
	// TZID) share the event's zone.
	fix := func(v *dtValue) {
		if !v.isDate && !v.utc && v.zone == nil {
			v.zone = ev.start.zone
		}
	}
	for i := range ev.rdates {
		fix(&ev.rdates[i])
	}
	for i := range ev.exdates {
		fix(&ev.exdates[i])
	}
	if ev.recurrenceID != nil {
		fix(ev.recurrenceID)
	}
	ev.startUTC = ev.start.toUTC()

	switch {
	case end != nil && end.isDate == ev.start.isDate && (ev.start.isDate || (end.utc == ev.start.utc && end.zone == ev.start.zone)):
		ev.naiveLen = end.naive.Sub(ev.start.naive)
	case end != nil && !ev.start.isDate:
		ev.absolute = true
		ev.absLen = end.toUTC().Sub(ev.startUTC)
	case end != nil:
		// A date DTSTART with a date-time DTEND: a one-day event.
		ev.naiveLen = 24 * time.Hour
	case dur != nil:
		ev.naiveLen = *dur
	case ev.start.isDate:
		ev.naiveLen = 24 * time.Hour
	}
	if ev.naiveLen < 0 {
		ev.naiveLen = 0
	}
	if ev.absLen < 0 {
		ev.absLen = 0
	}
	return ev, true
}

// parseDT reads a DATE or DATE-TIME value. fallback is the zone of a
// floating value; nil leaves it unset for the caller to fill.
func parseDT(value string, p property, zones *zoneResolver, fallback zone) (dtValue, bool) {
	value = strings.TrimSpace(value)
	if strings.EqualFold(p.param("VALUE"), "DATE") || len(value) == 8 {
		t, err := time.Parse("20060102", value)
		if err != nil {
			return dtValue{}, false
		}
		return dtValue{naive: t, isDate: true}, true
	}
	if strings.HasSuffix(value, "Z") || strings.HasSuffix(value, "z") {
		t, err := time.Parse("20060102T150405", value[:len(value)-1])
		if err != nil {
			return dtValue{}, false
		}
		return dtValue{naive: t, utc: true}, true
	}
	t, err := time.Parse("20060102T150405", value)
	if err != nil {
		return dtValue{}, false
	}
	v := dtValue{naive: t}
	if tzid := p.param("TZID"); tzid != "" {
		v.zone = zones.get(tzid)
	} else {
		v.zone = fallback
	}
	return v, true
}

// parseDuration reads an RFC 5545 duration ("P1D", "PT1H30M", "-P1W").
func parseDuration(s string) (time.Duration, bool) {
	s = strings.ToUpper(strings.TrimSpace(s))
	neg := false
	if strings.HasPrefix(s, "-") {
		neg, s = true, s[1:]
	} else {
		s = strings.TrimPrefix(s, "+")
	}
	if !strings.HasPrefix(s, "P") || len(s) < 3 {
		return 0, false
	}
	s = s[1:]
	var total time.Duration
	inTime := false
	num := 0
	digits := 0
	for _, r := range s {
		switch {
		case r >= '0' && r <= '9':
			num = num*10 + int(r-'0')
			digits++
			if digits > 7 {
				return 0, false
			}
		case r == 'T':
			inTime = true
		default:
			if digits == 0 {
				return 0, false
			}
			var unit time.Duration
			switch {
			case r == 'W' && !inTime:
				unit = 7 * 24 * time.Hour
			case r == 'D' && !inTime:
				unit = 24 * time.Hour
			case r == 'H' && inTime:
				unit = time.Hour
			case r == 'M' && inTime:
				unit = time.Minute
			case r == 'S' && inTime:
				unit = time.Second
			default:
				return 0, false
			}
			total += time.Duration(num) * unit
			num, digits = 0, 0
		}
	}
	if digits != 0 {
		return 0, false
	}
	// Nothing is longer than a few years; a longer duration is garbage.
	if total > 5*366*24*time.Hour {
		return 0, false
	}
	if neg {
		total = -total
	}
	return total, true
}

// ---------------------------------------------------------------------------
// Series expansion
// ---------------------------------------------------------------------------

// expandSeries lists the instances of master inside the window, applying
// EXDATEs and the overrides.
func expandSeries(m *event, overrides []*event, w window, maxPer int, b *budget) ([]Occurrence, bool) {
	type inst struct {
		naive time.Time // wall clock of the start, for date matching
		start time.Time
	}
	var insts []inst
	truncated := false

	if !b.spend(1) {
		return nil, true
	}

	if m.rule == nil {
		insts = append(insts, inst{naive: m.start.naive, start: m.startUTC})
	} else {
		// Expand on the wall clock, with a day of slack each side for the
		// zone offset and the event's own length.
		slack := 24*time.Hour + m.naiveLen + m.absLen
		from := w.start.Add(-slack)
		to := w.end.Add(24 * time.Hour)
		var untilAfter func(time.Time) bool
		if m.rule.hasUntil {
			u := m.rule.until
			switch {
			case u.isDate:
				limit := u.naive.AddDate(0, 0, 1)
				untilAfter = func(n time.Time) bool { return !n.Before(limit) }
			case u.utc && !m.start.isDate:
				untilAfter = func(n time.Time) bool { return toUTCFor(m, n).After(u.naive) }
			default:
				untilAfter = func(n time.Time) bool { return n.After(u.naive) }
			}
		}
		starts, cut := m.rule.expand(m.start.naive, from, to, untilAfter, maxPer, b)
		if cut {
			truncated = true
		}
		for _, n := range starts {
			insts = append(insts, inst{naive: n, start: toUTCFor(m, n)})
		}
	}
	for _, r := range m.rdates {
		n := r.naive
		if !m.start.isDate && r.isDate {
			// A date RDATE on a timed event keeps the event's time of day.
			n = time.Date(n.Year(), n.Month(), n.Day(), m.start.naive.Hour(), m.start.naive.Minute(), m.start.naive.Second(), 0, time.UTC)
			insts = append(insts, inst{naive: n, start: toUTCFor(m, n)})
			continue
		}
		insts = append(insts, inst{naive: n, start: r.toUTC()})
	}

	// EXDATEs and RECURRENCE-IDs name an instance by its original start:
	// an instant, or for a date value, a day.
	excludedAt := map[int64]bool{}
	excludedDay := map[string]bool{}
	mark := func(v dtValue) {
		if v.isDate {
			excludedDay[v.naive.Format("20060102")] = true
		} else if m.start.isDate {
			excludedDay[v.naive.Format("20060102")] = true
		} else {
			excludedAt[v.toUTC().Unix()] = true
		}
	}
	for _, x := range m.exdates {
		mark(x)
	}
	for _, o := range overrides {
		mark(*o.recurrenceID)
	}

	var out []Occurrence
	for _, in := range insts {
		if excludedAt[in.start.Unix()] || excludedDay[in.naive.Format("20060102")] {
			continue
		}
		out = appendIfInWindow(out, m, in.start, m.endFor(in.start, in.naive), w)
	}
	for _, o := range overrides {
		if o.cancelled {
			continue
		}
		out = appendIfInWindow(out, o, o.startUTC, o.endFor(o.startUTC, o.start.naive), w)
	}
	if len(out) > maxPer {
		out = out[:maxPer]
		truncated = true
	}
	return out, truncated
}

// toUTCFor converts a wall-clock start of m's series to an instant.
func toUTCFor(m *event, naive time.Time) time.Time {
	if m.start.isDate || m.start.utc {
		return naive
	}
	return m.start.zone.toUTC(naive)
}
