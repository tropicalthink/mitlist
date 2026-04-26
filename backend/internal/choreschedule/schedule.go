package choreschedule

import "time"

const (
	FrequencyNone     = "none"
	FrequencyManual   = "manual"
	FrequencyHourly   = "hourly"
	FrequencyDaily    = "daily"
	FrequencyWeekly   = "weekly"
	FrequencyMonthly  = "monthly"
	FrequencyYearly   = "yearly"
	FrequencyAdaptive = "adaptive"
)

// NormalizeFrequency maps empty and legacy manual values to a stable schedule key.
func NormalizeFrequency(frequency string) string {
	switch frequency {
	case FrequencyManual:
		return FrequencyNone
	case FrequencyHourly, FrequencyDaily, FrequencyWeekly, FrequencyMonthly, FrequencyYearly, FrequencyAdaptive, FrequencyNone:
		return frequency
	default:
		return FrequencyNone
	}
}

func IsScheduled(frequency string) bool {
	return NormalizeFrequency(frequency) != FrequencyNone
}

func NormalizeRotationType(rotationType, frequency string) string {
	if !IsScheduled(frequency) {
		return "manual"
	}
	if rotationType == "" || rotationType == "none" || rotationType == "manual" {
		return "schedule"
	}
	return rotationType
}

// NextDue returns the next due date for a scheduled chore. Manual chores have no due date.
type Rule struct {
	Frequency      string
	Interval       int
	PeriodConfig   []string
	StartDate      *time.Time
	TrackDateOnly  bool
	Rollover       bool
	AverageSpacing *time.Duration
}

func NextDue(from time.Time, frequency string) *time.Time {
	return NextDueForRule(from, Rule{Frequency: frequency, Interval: 1})
}

func NextDueForRule(from time.Time, rule Rule) *time.Time {
	interval := rule.Interval
	if interval <= 0 {
		interval = 1
	}
	base := from
	if rule.StartDate != nil && from.Before(*rule.StartDate) {
		base = *rule.StartDate
	}

	var due time.Time
	switch NormalizeFrequency(rule.Frequency) {
	case FrequencyHourly:
		due = base.Add(time.Duration(interval) * time.Hour)
	case FrequencyDaily:
		due = base.AddDate(0, 0, interval)
	case FrequencyWeekly:
		due = nextWeeklyDue(base, interval, rule.PeriodConfig)
	case FrequencyMonthly:
		due = base.AddDate(0, interval, 0)
	case FrequencyYearly:
		due = base.AddDate(interval, 0, 0)
	case FrequencyAdaptive:
		if rule.AverageSpacing == nil || *rule.AverageSpacing <= 0 {
			return nil
		}
		due = base.Add(*rule.AverageSpacing)
	default:
		return nil
	}
	if rule.TrackDateOnly {
		due = time.Date(due.Year(), due.Month(), due.Day(), 0, 0, 0, 0, due.Location())
	}
	if rule.Rollover {
		now := time.Now().UTC()
		for due.Before(now) {
			next := NextDueForRule(due, Rule{
				Frequency:      rule.Frequency,
				Interval:       interval,
				PeriodConfig:   rule.PeriodConfig,
				TrackDateOnly:  rule.TrackDateOnly,
				AverageSpacing: rule.AverageSpacing,
			})
			if next == nil || !next.After(due) {
				break
			}
			due = *next
		}
	}
	return &due
}

func nextWeeklyDue(from time.Time, interval int, days []string) time.Time {
	if len(days) == 0 {
		return from.AddDate(0, 0, 7*interval)
	}
	allowed := map[time.Weekday]bool{}
	for _, day := range days {
		switch day {
		case "sunday":
			allowed[time.Sunday] = true
		case "monday":
			allowed[time.Monday] = true
		case "tuesday":
			allowed[time.Tuesday] = true
		case "wednesday":
			allowed[time.Wednesday] = true
		case "thursday":
			allowed[time.Thursday] = true
		case "friday":
			allowed[time.Friday] = true
		case "saturday":
			allowed[time.Saturday] = true
		}
	}
	for i := 1; i <= 7*interval; i++ {
		candidate := from.AddDate(0, 0, i)
		if allowed[candidate.Weekday()] {
			return candidate
		}
	}
	return from.AddDate(0, 0, 7*interval)
}
