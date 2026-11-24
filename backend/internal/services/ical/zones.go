package ical

import (
	"strconv"
	"strings"
	"time"
)

// zone turns a wall-clock time (held in a UTC time.Time) into an instant.
// Implementations are comparable so two values naming the same zone match.
type zone interface {
	toUTC(naive time.Time) time.Time
}

type utcZone struct{}

func (utcZone) toUTC(n time.Time) time.Time { return n }

type locZone struct{ loc *time.Location }

func (z locZone) toUTC(n time.Time) time.Time {
	return time.Date(n.Year(), n.Month(), n.Day(), n.Hour(), n.Minute(), n.Second(), 0, z.loc).UTC()
}

func loadIANA(name string) (*time.Location, bool) {
	name = strings.TrimSpace(name)
	if name == "" || len(name) > 64 || strings.EqualFold(name, "local") || strings.Contains(name, "..") {
		return nil, false
	}
	loc, err := time.LoadLocation(name)
	if err != nil {
		return nil, false
	}
	return loc, true
}

// zoneResolver maps TZIDs to zones for one feed: an IANA name first, then
// the feed's own VTIMEZONE, then a Windows zone name, else the calendar's
// default zone. It resolves at most maxTimeZones distinct TZIDs.
type zoneResolver struct {
	defs  map[string]*component
	cache map[string]zone
	def   zone
}

func newZoneResolver(root *component, def zone) *zoneResolver {
	z := &zoneResolver{defs: map[string]*component{}, cache: map[string]zone{}, def: def}
	for _, c := range root.children {
		if c.name != "VTIMEZONE" || len(z.defs) >= maxTimeZones {
			continue
		}
		if p, ok := c.prop("TZID"); ok {
			z.defs[strings.TrimSpace(p.value)] = c
		}
	}
	return z
}

func (z *zoneResolver) get(tzid string) zone {
	tzid = strings.TrimSpace(tzid)
	if cached, ok := z.cache[tzid]; ok {
		return cached
	}
	if len(z.cache) >= maxTimeZones {
		return z.def
	}
	resolved := z.resolve(tzid)
	z.cache[tzid] = resolved
	return resolved
}

func (z *zoneResolver) resolve(tzid string) zone {
	name := strings.TrimPrefix(strings.Trim(tzid, "\""), "/")
	if loc, ok := loadIANA(name); ok {
		return locZone{loc: loc}
	}
	if def, ok := z.defs[tzid]; ok {
		if v := buildVTZ(def); v != nil {
			return v
		}
	}
	if iana, ok := windowsZones[name]; ok {
		if loc, ok := loadIANA(iana); ok {
			return locZone{loc: loc}
		}
	}
	return z.def
}

type observance struct {
	start  time.Time
	from   time.Duration
	to     time.Duration
	rule   *rule
	rdates []time.Time
}

type onset struct {
	at     time.Time
	offset time.Duration
}

// vtzZone is a time zone defined inline by a VTIMEZONE: the offset at a
// wall-clock time is the TZOFFSETTO of the latest observance onset before
// it.
type vtzZone struct {
	obs   []observance
	years map[int][]onset
}

func buildVTZ(c *component) *vtzZone {
	z := &vtzZone{years: map[int][]onset{}}
	for _, o := range c.children {
		if len(z.obs) >= maxObservances {
			break
		}
		var ob observance
		var haveStart, haveTo bool
		for _, p := range o.props {
			switch p.name {
			case "DTSTART":
				if t, err := time.Parse("20060102T150405", strings.TrimSuffix(strings.TrimSpace(p.value), "Z")); err == nil {
					ob.start, haveStart = t, true
				}
			case "TZOFFSETFROM":
				ob.from, _ = parseOffset(p.value)
			case "TZOFFSETTO":
				ob.to, haveTo = parseOffset(p.value)
			case "RRULE":
				if r, err := parseRule(p.value); err == nil {
					ob.rule = r
				}
			case "RDATE":
				for _, raw := range strings.Split(p.value, ",") {
					if t, err := time.Parse("20060102T150405", strings.TrimSuffix(strings.TrimSpace(raw), "Z")); err == nil && len(ob.rdates) < 500 {
						ob.rdates = append(ob.rdates, t)
					}
				}
			}
		}
		if haveStart && haveTo {
			z.obs = append(z.obs, ob)
		}
	}
	if len(z.obs) == 0 {
		return nil
	}
	return z
}

func parseOffset(s string) (time.Duration, bool) {
	s = strings.TrimSpace(s)
	if len(s) != 5 && len(s) != 7 {
		return 0, false
	}
	sign := time.Duration(1)
	switch s[0] {
	case '-':
		sign = -1
	case '+':
	default:
		return 0, false
	}
	h, err1 := strconv.Atoi(s[1:3])
	m, err2 := strconv.Atoi(s[3:5])
	sec := 0
	var err3 error
	if len(s) == 7 {
		sec, err3 = strconv.Atoi(s[5:7])
	}
	if err1 != nil || err2 != nil || err3 != nil || h > 23 || m > 59 || sec > 59 {
		return 0, false
	}
	return sign * (time.Duration(h)*time.Hour + time.Duration(m)*time.Minute + time.Duration(sec)*time.Second), true
}

func (z *vtzZone) onsets(year int) []onset {
	if got, ok := z.years[year]; ok {
		return got
	}
	var out []onset
	from := time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(year, 12, 31, 23, 59, 59, 0, time.UTC)
	for _, ob := range z.obs {
		if ob.start.After(to) {
			continue
		}
		if !ob.start.Before(from) {
			out = append(out, onset{at: ob.start, offset: ob.to})
		}
		if ob.rule != nil {
			var untilAfter func(time.Time) bool
			if ob.rule.hasUntil {
				u, shift := ob.rule.until, ob.from
				untilAfter = func(n time.Time) bool {
					if u.utc {
						return n.Add(-shift).After(u.naive)
					}
					return n.After(u.naive)
				}
			}
			starts, _ := ob.rule.expand(ob.start, from, to, untilAfter, 16, &budget{left: 20000})
			for _, s := range starts {
				out = append(out, onset{at: s, offset: ob.to})
			}
		}
		for _, rd := range ob.rdates {
			if !rd.Before(from) && !rd.After(to) {
				out = append(out, onset{at: rd, offset: ob.to})
			}
		}
	}
	if len(z.years) < 64 {
		z.years[year] = out
	}
	return out
}

func (z *vtzZone) offsetAt(n time.Time) time.Duration {
	var best *onset
	for _, y := range []int{n.Year() - 1, n.Year()} {
		list := z.onsets(y)
		for i := range list {
			o := list[i]
			if o.at.After(n) {
				continue
			}
			if best == nil || o.at.After(best.at) {
				best = &o
			}
		}
	}
	if best != nil {
		return best.offset
	}
	// Before every onset: the earliest observance's previous offset; a
	// zone whose last onset is long ago keeps its latest offset.
	earliest := z.obs[0]
	latest := z.obs[0]
	for _, ob := range z.obs[1:] {
		if ob.start.Before(earliest.start) {
			earliest = ob
		}
		if ob.start.After(latest.start) {
			latest = ob
		}
	}
	if n.Before(earliest.start) {
		return earliest.from
	}
	return latest.to
}

func (z *vtzZone) toUTC(n time.Time) time.Time { return n.Add(-z.offsetAt(n)) }

// windowsZones maps the Windows zone names Outlook and Exchange write to
// IANA names, for feeds that use them without a VTIMEZONE.
var windowsZones = map[string]string{
	"Dateline Standard Time":          "Etc/GMT+12",
	"Hawaiian Standard Time":          "Pacific/Honolulu",
	"Alaskan Standard Time":           "America/Anchorage",
	"Pacific Standard Time":           "America/Los_Angeles",
	"Mountain Standard Time":          "America/Denver",
	"US Mountain Standard Time":       "America/Phoenix",
	"Central Standard Time":           "America/Chicago",
	"Eastern Standard Time":           "America/New_York",
	"Atlantic Standard Time":          "America/Halifax",
	"Newfoundland Standard Time":      "America/St_Johns",
	"E. South America Standard Time":  "America/Sao_Paulo",
	"Argentina Standard Time":         "America/Argentina/Buenos_Aires",
	"UTC":                             "UTC",
	"GMT Standard Time":               "Europe/London",
	"Greenwich Standard Time":         "Atlantic/Reykjavik",
	"W. Europe Standard Time":         "Europe/Berlin",
	"Central Europe Standard Time":    "Europe/Budapest",
	"Central European Standard Time":  "Europe/Warsaw",
	"Romance Standard Time":           "Europe/Paris",
	"E. Europe Standard Time":         "Europe/Chisinau",
	"FLE Standard Time":               "Europe/Kiev",
	"GTB Standard Time":               "Europe/Bucharest",
	"Egypt Standard Time":             "Africa/Cairo",
	"South Africa Standard Time":      "Africa/Johannesburg",
	"Turkey Standard Time":            "Europe/Istanbul",
	"Israel Standard Time":            "Asia/Jerusalem",
	"Russian Standard Time":           "Europe/Moscow",
	"Arabian Standard Time":           "Asia/Dubai",
	"Arab Standard Time":              "Asia/Riyadh",
	"Iran Standard Time":              "Asia/Tehran",
	"Pakistan Standard Time":          "Asia/Karachi",
	"India Standard Time":             "Asia/Kolkata",
	"Bangladesh Standard Time":        "Asia/Dhaka",
	"SE Asia Standard Time":           "Asia/Bangkok",
	"China Standard Time":             "Asia/Shanghai",
	"Singapore Standard Time":         "Asia/Singapore",
	"Taipei Standard Time":            "Asia/Taipei",
	"Tokyo Standard Time":             "Asia/Tokyo",
	"Korea Standard Time":             "Asia/Seoul",
	"AUS Eastern Standard Time":       "Australia/Sydney",
	"E. Australia Standard Time":      "Australia/Brisbane",
	"Cen. Australia Standard Time":    "Australia/Adelaide",
	"W. Australia Standard Time":      "Australia/Perth",
	"New Zealand Standard Time":       "Pacific/Auckland",
	"Morocco Standard Time":           "Africa/Casablanca",
	"W. Central Africa Standard Time": "Africa/Lagos",
	"E. Africa Standard Time":         "Africa/Nairobi",
	"Mexico Standard Time":            "America/Mexico_City",
	"Central Standard Time (Mexico)":  "America/Mexico_City",
	"SA Pacific Standard Time":        "America/Bogota",
}
