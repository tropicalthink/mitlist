package ical

import (
	"errors"
	"sort"
	"strconv"
	"strings"
	"time"
)

type frequency int

const (
	freqSecondly frequency = iota
	freqMinutely
	freqHourly
	freqDaily
	freqWeekly
	freqMonthly
	freqYearly
)

type weekdayNum struct {
	n  int
	wd time.Weekday
}

// rule is a parsed RRULE. Unsupported shapes (BYWEEKNO, sub-daily rules
// with BY parts, huge time-of-day products) fail to parse, and the event is
// then read as its first instance only.
type rule struct {
	freq       frequency
	interval   int
	count      int
	hasUntil   bool
	until      dtValue
	byMonth    []int
	byMonthDay []int
	byYearDay  []int
	byDay      []weekdayNum
	byHour     []int
	byMinute   []int
	bySecond   []int
	bySetPos   []int
	wkst       time.Weekday
}

var errRule = errors.New("ical: unsupported RRULE")

const maxRuleList = 400

var weekdays = map[string]time.Weekday{
	"SU": time.Sunday, "MO": time.Monday, "TU": time.Tuesday, "WE": time.Wednesday,
	"TH": time.Thursday, "FR": time.Friday, "SA": time.Saturday,
}

func parseRule(s string) (*rule, error) {
	r := &rule{interval: 1, wkst: time.Monday, freq: -1}
	for _, part := range strings.Split(strings.TrimSpace(s), ";") {
		if part == "" {
			continue
		}
		kv := strings.SplitN(part, "=", 2)
		if len(kv) != 2 {
			return nil, errRule
		}
		key, val := strings.ToUpper(strings.TrimSpace(kv[0])), strings.ToUpper(strings.TrimSpace(kv[1]))
		var err error
		switch key {
		case "FREQ":
			switch val {
			case "SECONDLY":
				r.freq = freqSecondly
			case "MINUTELY":
				r.freq = freqMinutely
			case "HOURLY":
				r.freq = freqHourly
			case "DAILY":
				r.freq = freqDaily
			case "WEEKLY":
				r.freq = freqWeekly
			case "MONTHLY":
				r.freq = freqMonthly
			case "YEARLY":
				r.freq = freqYearly
			default:
				return nil, errRule
			}
		case "INTERVAL":
			r.interval, err = strconv.Atoi(val)
			if err != nil || r.interval < 1 || r.interval > 10000 {
				return nil, errRule
			}
		case "COUNT":
			r.count, err = strconv.Atoi(val)
			if err != nil || r.count < 1 {
				return nil, errRule
			}
			// A count this large is never reached inside the window; reading
			// it as unbounded keeps the expansion able to skip ahead.
			if r.count > 100000 {
				r.count = 0
			}
		case "UNTIL":
			u, ok := parseUntil(val)
			if !ok {
				return nil, errRule
			}
			r.hasUntil, r.until = true, u
		case "BYMONTH":
			r.byMonth, err = intList(val, 1, 12, false)
		case "BYMONTHDAY":
			r.byMonthDay, err = intList(val, 1, 31, true)
		case "BYYEARDAY":
			r.byYearDay, err = intList(val, 1, 366, true)
		case "BYHOUR":
			r.byHour, err = intList(val, 0, 23, false)
		case "BYMINUTE":
			r.byMinute, err = intList(val, 0, 59, false)
		case "BYSECOND":
			r.bySecond, err = intList(val, 0, 60, false)
		case "BYSETPOS":
			r.bySetPos, err = intList(val, 1, 366, true)
		case "BYDAY":
			r.byDay, err = dayList(val)
		case "WKST":
			wd, ok := weekdays[val]
			if !ok {
				return nil, errRule
			}
			r.wkst = wd
		case "BYWEEKNO":
			return nil, errRule
		default:
			// X- parts and the like change nothing we expand.
		}
		if err != nil {
			return nil, errRule
		}
	}
	if r.freq < 0 {
		return nil, errRule
	}
	hasBy := len(r.byMonth)+len(r.byMonthDay)+len(r.byYearDay)+len(r.byDay)+len(r.byHour)+len(r.byMinute)+len(r.bySecond)+len(r.bySetPos) > 0
	if r.freq < freqDaily && hasBy {
		return nil, errRule
	}
	if times := max(1, len(r.byHour)) * max(1, len(r.byMinute)) * max(1, len(r.bySecond)); times > 100 {
		return nil, errRule
	}
	return r, nil
}

func parseUntil(v string) (dtValue, bool) {
	switch {
	case len(v) == 8:
		t, err := time.Parse("20060102", v)
		return dtValue{naive: t, isDate: true}, err == nil
	case strings.HasSuffix(v, "Z"):
		t, err := time.Parse("20060102T150405", v[:len(v)-1])
		return dtValue{naive: t, utc: true}, err == nil
	default:
		t, err := time.Parse("20060102T150405", v)
		return dtValue{naive: t}, err == nil
	}
}

func intList(v string, lo, hi int, allowNeg bool) ([]int, error) {
	parts := strings.Split(v, ",")
	if len(parts) > maxRuleList {
		return nil, errRule
	}
	out := make([]int, 0, len(parts))
	for _, p := range parts {
		n, err := strconv.Atoi(strings.TrimPrefix(strings.TrimSpace(p), "+"))
		if err != nil {
			return nil, errRule
		}
		a := n
		if a < 0 {
			if !allowNeg {
				return nil, errRule
			}
			a = -a
		}
		if a < lo || a > hi || (n == 0 && lo > 0) {
			return nil, errRule
		}
		out = append(out, n)
	}
	return out, nil
}

func dayList(v string) ([]weekdayNum, error) {
	parts := strings.Split(v, ",")
	if len(parts) > maxRuleList {
		return nil, errRule
	}
	out := make([]weekdayNum, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if len(p) < 2 {
			return nil, errRule
		}
		wd, ok := weekdays[p[len(p)-2:]]
		if !ok {
			return nil, errRule
		}
		n := 0
		if num := strings.TrimPrefix(p[:len(p)-2], "+"); num != "" {
			var err error
			n, err = strconv.Atoi(num)
			if err != nil || n == 0 || n > 53 || n < -53 {
				return nil, errRule
			}
		}
		out = append(out, weekdayNum{n: n, wd: wd})
	}
	return out, nil
}

// expand lists the rule's wall-clock starts in [from, to], DTSTART
// included as the first instance. untilAfter reports a start past UNTIL.
// It stops at maxOut starts, after maxSeriesPeriods periods, or when the
// feed budget runs out; the second result reports such a cut.
func (r *rule) expand(dtstart, from, to time.Time, untilAfter func(time.Time) bool, maxOut int, b *budget) ([]time.Time, bool) {
	var out []time.Time
	emitted := 0
	cut := false
	// emit reports whether expansion should stop.
	emit := func(t time.Time) bool {
		if untilAfter != nil && untilAfter(t) {
			return true
		}
		emitted++
		if r.count > 0 && emitted > r.count {
			return true
		}
		if t.After(to) {
			return true
		}
		if !t.Before(from) {
			out = append(out, t)
			if len(out) >= maxOut {
				cut = true
				return true
			}
		}
		return false
	}
	if emit(dtstart) {
		return out, cut
	}

	if r.freq < freqDaily {
		unit := time.Second
		switch r.freq {
		case freqMinutely:
			unit = time.Minute
		case freqHourly:
			unit = time.Hour
		}
		stepSecs := int64(r.interval) * int64(unit/time.Second)
		k := int64(1)
		if from.After(dtstart) {
			if k0 := (from.Unix() - dtstart.Unix()) / stepSecs; k0 > 1 {
				k = k0
			}
		}
		// Every step is one instance, so the skipped ones still count.
		emitted = int(min(k, int64(1<<31-1)))
		for ; ; k++ {
			if !b.spend(1) {
				return out, true
			}
			t := dtstart.Add(time.Duration(k*stepSecs) * time.Second)
			if emit(t) {
				return out, cut
			}
		}
	}

	k := 0
	if r.count == 0 {
		k = r.fastForward(dtstart, from)
	}
	for periods := 0; ; k, periods = k+1, periods+1 {
		if periods > maxSeriesPeriods || !b.spend(1) {
			return out, true
		}
		start, cands := r.period(dtstart, k)
		if start.After(to) || start.Year() > 9999 {
			return out, cut
		}
		if !b.spend(len(cands)) {
			return out, true
		}
		for _, c := range cands {
			if !c.After(dtstart) {
				continue
			}
			if emit(c) {
				return out, cut
			}
		}
	}
}

func dateOf(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

func weekStart(d time.Time, wkst time.Weekday) time.Time {
	diff := (int(d.Weekday()) - int(wkst) + 7) % 7
	return dateOf(d).AddDate(0, 0, -diff)
}

// fastForward is the first period index worth generating for a rule with
// no COUNT: one interval-aligned period before the one holding from.
func (r *rule) fastForward(dtstart, from time.Time) int {
	if !from.After(dtstart) {
		return 0
	}
	var periods int64
	switch r.freq {
	case freqDaily:
		periods = (from.Unix() - dateOf(dtstart).Unix()) / 86400
	case freqWeekly:
		periods = (from.Unix() - weekStart(dtstart, r.wkst).Unix()) / (7 * 86400)
	case freqMonthly:
		periods = int64(from.Year()-dtstart.Year())*12 + int64(from.Month()-dtstart.Month())
	case freqYearly:
		periods = int64(from.Year() - dtstart.Year())
	}
	k := periods/int64(r.interval) - 1
	if k < 0 {
		return 0
	}
	if k > 1<<30 {
		k = 1 << 30
	}
	return int(k)
}

// period returns the k-th period's first day and its sorted candidate
// starts, BYSETPOS applied.
func (r *rule) period(dtstart time.Time, k int) (time.Time, []time.Time) {
	var start time.Time
	var dates []time.Time
	step := k * r.interval
	switch r.freq {
	case freqDaily:
		start = dateOf(dtstart).AddDate(0, 0, step)
		if r.matchesDay(start) {
			dates = append(dates, start)
		}
	case freqWeekly:
		start = weekStart(dtstart, r.wkst).AddDate(0, 0, 7*step)
		for i := 0; i < 7; i++ {
			d := start.AddDate(0, 0, i)
			if len(r.byDay) > 0 {
				if !r.hasWeekday(d.Weekday()) {
					continue
				}
			} else if d.Weekday() != dtstart.Weekday() {
				continue
			}
			if len(r.byMonth) > 0 && !contains(r.byMonth, int(d.Month())) {
				continue
			}
			dates = append(dates, d)
		}
	case freqMonthly:
		start = time.Date(dtstart.Year(), dtstart.Month()+time.Month(step), 1, 0, 0, 0, 0, time.UTC)
		if len(r.byMonth) == 0 || contains(r.byMonth, int(start.Month())) {
			dates = r.monthDates(start.Year(), start.Month(), dtstart)
		}
	case freqYearly:
		start = time.Date(dtstart.Year()+step, 1, 1, 0, 0, 0, 0, time.UTC)
		dates = r.yearDates(start.Year(), dtstart)
	}

	hours, minutes, seconds := r.byHour, r.byMinute, r.bySecond
	if len(hours) == 0 {
		hours = []int{dtstart.Hour()}
	}
	if len(minutes) == 0 {
		minutes = []int{dtstart.Minute()}
	}
	if len(seconds) == 0 {
		seconds = []int{dtstart.Second()}
	}
	cands := make([]time.Time, 0, len(dates)*len(hours)*len(minutes)*len(seconds))
	for _, d := range dates {
		for _, h := range hours {
			for _, mi := range minutes {
				for _, s := range seconds {
					cands = append(cands, time.Date(d.Year(), d.Month(), d.Day(), h, mi, s, 0, time.UTC))
				}
			}
		}
	}
	sort.Slice(cands, func(i, j int) bool { return cands[i].Before(cands[j]) })
	cands = uniqTimes(cands)
	if len(r.bySetPos) > 0 && len(cands) > 0 {
		var picked []time.Time
		for _, p := range r.bySetPos {
			i := p - 1
			if p < 0 {
				i = len(cands) + p
			}
			if i >= 0 && i < len(cands) {
				picked = append(picked, cands[i])
			}
		}
		sort.Slice(picked, func(i, j int) bool { return picked[i].Before(picked[j]) })
		cands = uniqTimes(picked)
	}
	return start, cands
}

func (r *rule) matchesDay(d time.Time) bool {
	if len(r.byMonth) > 0 && !contains(r.byMonth, int(d.Month())) {
		return false
	}
	if len(r.byMonthDay) > 0 {
		dim := daysIn(d.Year(), d.Month())
		ok := false
		for _, md := range r.byMonthDay {
			if resolveDay(md, dim) == d.Day() {
				ok = true
				break
			}
		}
		if !ok {
			return false
		}
	}
	if len(r.byYearDay) > 0 {
		diy := daysInYear(d.Year())
		ok := false
		for _, yd := range r.byYearDay {
			if resolveDay(yd, diy) == d.YearDay() {
				ok = true
				break
			}
		}
		if !ok {
			return false
		}
	}
	if len(r.byDay) > 0 && !r.hasWeekday(d.Weekday()) {
		return false
	}
	return true
}

func (r *rule) hasWeekday(wd time.Weekday) bool {
	for _, d := range r.byDay {
		if d.wd == wd {
			return true
		}
	}
	return false
}

// monthDates are a month's candidate days: BYMONTHDAY and BYDAY (with
// month-relative ordinals), intersected when both are given, else
// DTSTART's day of the month.
func (r *rule) monthDates(y int, m time.Month, dtstart time.Time) []time.Time {
	dim := daysIn(y, m)
	var days []int
	switch {
	case len(r.byMonthDay) == 0 && len(r.byDay) == 0:
		if dtstart.Day() <= dim {
			days = []int{dtstart.Day()}
		}
	default:
		var fromMD, fromD map[int]bool
		if len(r.byMonthDay) > 0 {
			fromMD = map[int]bool{}
			for _, md := range r.byMonthDay {
				if d := resolveDay(md, dim); d >= 1 {
					fromMD[d] = true
				}
			}
		}
		if len(r.byDay) > 0 {
			fromD = map[int]bool{}
			first := time.Date(y, m, 1, 0, 0, 0, 0, time.UTC)
			for _, wn := range r.byDay {
				var all []int
				for d := 1; d <= dim; d++ {
					if first.AddDate(0, 0, d-1).Weekday() == wn.wd {
						all = append(all, d)
					}
				}
				for _, d := range pickOrdinal(all, wn.n) {
					fromD[d] = true
				}
			}
		}
		for d := 1; d <= dim; d++ {
			if (fromMD == nil || fromMD[d]) && (fromD == nil || fromD[d]) {
				days = append(days, d)
			}
		}
	}
	out := make([]time.Time, 0, len(days))
	for _, d := range days {
		out = append(out, time.Date(y, m, d, 0, 0, 0, 0, time.UTC))
	}
	return out
}

func (r *rule) yearDates(y int, dtstart time.Time) []time.Time {
	var out []time.Time
	switch {
	case len(r.byYearDay) > 0:
		diy := daysInYear(y)
		for _, yd := range r.byYearDay {
			if d := resolveDay(yd, diy); d >= 1 {
				t := time.Date(y, 1, d, 0, 0, 0, 0, time.UTC)
				if r.matchesDay(t) {
					out = append(out, t)
				}
			}
		}
	case len(r.byMonth) > 0:
		for _, m := range r.byMonth {
			out = append(out, r.monthDates(y, time.Month(m), dtstart)...)
		}
	case len(r.byMonthDay) > 0:
		for m := time.January; m <= time.December; m++ {
			out = append(out, r.monthDates(y, m, dtstart)...)
		}
	case len(r.byDay) > 0:
		// Ordinals count within the year ("20MO" is the 20th Monday).
		first := time.Date(y, 1, 1, 0, 0, 0, 0, time.UTC)
		diy := daysInYear(y)
		for _, wn := range r.byDay {
			var all []int
			for d := 0; d < diy; d++ {
				if first.AddDate(0, 0, d).Weekday() == wn.wd {
					all = append(all, d)
				}
			}
			for _, d := range pickOrdinal(all, wn.n) {
				out = append(out, first.AddDate(0, 0, d))
			}
		}
	default:
		if dtstart.Day() <= daysIn(y, dtstart.Month()) {
			out = append(out, time.Date(y, dtstart.Month(), dtstart.Day(), 0, 0, 0, 0, time.UTC))
		}
	}
	return out
}

func pickOrdinal(all []int, n int) []int {
	switch {
	case n == 0:
		return all
	case n > 0 && n <= len(all):
		return []int{all[n-1]}
	case n < 0 && -n <= len(all):
		return []int{all[len(all)+n]}
	}
	return nil
}

func resolveDay(n, total int) int {
	if n > 0 {
		if n > total {
			return -1
		}
		return n
	}
	d := total + n + 1
	if d < 1 {
		return -1
	}
	return d
}

func daysIn(y int, m time.Month) int {
	return time.Date(y, m+1, 0, 0, 0, 0, 0, time.UTC).Day()
}

func daysInYear(y int) int {
	return time.Date(y, 12, 31, 0, 0, 0, 0, time.UTC).YearDay()
}

func contains(list []int, v int) bool {
	for _, x := range list {
		if x == v {
			return true
		}
	}
	return false
}

func uniqTimes(ts []time.Time) []time.Time {
	if len(ts) < 2 {
		return ts
	}
	out := ts[:1]
	for _, t := range ts[1:] {
		if !t.Equal(out[len(out)-1]) {
			out = append(out, t)
		}
	}
	return out
}
