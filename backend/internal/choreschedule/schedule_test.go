package choreschedule

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNextDueForRule(t *testing.T) {
	base := time.Date(2026, 3, 1, 9, 30, 0, 0, time.UTC) // Sunday
	spacing := 36 * time.Hour
	futureStart := time.Date(2026, 4, 10, 7, 15, 0, 0, time.UTC)

	tests := []struct {
		name string
		from time.Time
		rule Rule
		want *time.Time
	}{
		{
			name: "hourly interval 1",
			from: base,
			rule: Rule{Frequency: FrequencyHourly, Interval: 1},
			want: ptrTime(base.Add(time.Hour)),
		},
		{
			name: "hourly interval 3",
			from: base,
			rule: Rule{Frequency: FrequencyHourly, Interval: 3},
			want: ptrTime(base.Add(3 * time.Hour)),
		},
		{
			name: "daily interval 1",
			from: base,
			rule: Rule{Frequency: FrequencyDaily, Interval: 1},
			want: ptrTime(base.AddDate(0, 0, 1)),
		},
		{
			name: "daily interval 5",
			from: base,
			rule: Rule{Frequency: FrequencyDaily, Interval: 5},
			want: ptrTime(base.AddDate(0, 0, 5)),
		},
		{
			name: "weekly empty days interval 1",
			from: base,
			rule: Rule{Frequency: FrequencyWeekly, Interval: 1},
			want: ptrTime(base.AddDate(0, 0, 7)),
		},
		{
			name: "weekly empty days interval 2",
			from: base,
			rule: Rule{Frequency: FrequencyWeekly, Interval: 2},
			want: ptrTime(base.AddDate(0, 0, 14)),
		},
		{
			name: "weekly days picks next matching weekday",
			from: base,
			rule: Rule{
				Frequency:    FrequencyWeekly,
				Interval:     1,
				PeriodConfig: []string{"monday", "thursday"},
			},
			want: ptrTime(time.Date(2026, 3, 2, 9, 30, 0, 0, time.UTC)),
		},
		{
			name: "weekly days crosses week boundary",
			from: time.Date(2026, 3, 6, 9, 30, 0, 0, time.UTC), // Friday
			rule: Rule{
				Frequency:    FrequencyWeekly,
				Interval:     1,
				PeriodConfig: []string{"monday", "thursday"},
			},
			want: ptrTime(time.Date(2026, 3, 9, 9, 30, 0, 0, time.UTC)),
		},
		{
			name: "monthly interval 1",
			from: base,
			rule: Rule{Frequency: FrequencyMonthly, Interval: 1},
			want: ptrTime(base.AddDate(0, 1, 0)),
		},
		{
			name: "monthly interval 2",
			from: base,
			rule: Rule{Frequency: FrequencyMonthly, Interval: 2},
			want: ptrTime(base.AddDate(0, 2, 0)),
		},
		{
			name: "yearly interval 1",
			from: base,
			rule: Rule{Frequency: FrequencyYearly, Interval: 1},
			want: ptrTime(base.AddDate(1, 0, 0)),
		},
		{
			name: "yearly interval 2",
			from: base,
			rule: Rule{Frequency: FrequencyYearly, Interval: 2},
			want: ptrTime(base.AddDate(2, 0, 0)),
		},
		{
			name: "adaptive spacing",
			from: base,
			rule: Rule{Frequency: FrequencyAdaptive, AverageSpacing: &spacing},
			want: ptrTime(base.Add(spacing)),
		},
		{
			name: "adaptive nil spacing",
			from: base,
			rule: Rule{Frequency: FrequencyAdaptive},
			want: nil,
		},
		{
			name: "adaptive zero spacing",
			from: base,
			rule: Rule{Frequency: FrequencyAdaptive, AverageSpacing: ptrDuration(0)},
			want: nil,
		},
		{
			name: "future start date clamps base",
			from: base,
			rule: Rule{Frequency: FrequencyDaily, StartDate: &futureStart},
			want: ptrTime(futureStart.AddDate(0, 0, 1)),
		},
		{
			name: "track date only truncates time",
			from: base,
			rule: Rule{Frequency: FrequencyDaily, TrackDateOnly: true},
			want: ptrTime(time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC)),
		},
		{
			name: "non-positive interval normalizes to 1",
			from: base,
			rule: Rule{Frequency: FrequencyDaily, Interval: 0},
			want: ptrTime(base.AddDate(0, 0, 1)),
		},
		{
			name: "manual has no due date",
			from: base,
			rule: Rule{Frequency: FrequencyManual},
			want: nil,
		},
		{
			name: "unknown has no due date",
			from: base,
			rule: Rule{Frequency: "sometimes"},
			want: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := NextDueForRule(tt.from, tt.rule)
			if tt.want == nil {
				assert.Nil(t, got)
				return
			}
			require.NotNil(t, got)
			assert.Equal(t, *tt.want, *got)
		})
	}
}

func TestNextDueForRuleRollover(t *testing.T) {
	from := time.Now().UTC().Add(-10 * 24 * time.Hour).Truncate(time.Hour)
	got := NextDueForRule(from, Rule{
		Frequency: FrequencyDaily,
		Interval:  2,
		Rollover:  true,
	})

	require.NotNil(t, got)
	assert.False(t, got.Before(time.Now().UTC()), "rolled due date should not be in the past")
	assert.Equal(t, int64(0), got.Sub(from).Nanoseconds()%(48*time.Hour).Nanoseconds())
}

func TestNormalizeFrequency(t *testing.T) {
	assert.Equal(t, FrequencyNone, NormalizeFrequency(""))
	assert.Equal(t, FrequencyNone, NormalizeFrequency(FrequencyManual))
	assert.Equal(t, FrequencyNone, NormalizeFrequency("weekly-ish"))
	assert.Equal(t, FrequencyWeekly, NormalizeFrequency(FrequencyWeekly))
}

func TestIsScheduled(t *testing.T) {
	assert.False(t, IsScheduled(FrequencyNone))
	assert.False(t, IsScheduled(FrequencyManual))
	assert.True(t, IsScheduled(FrequencyDaily))
}

func TestNormalizeRotationType(t *testing.T) {
	assert.Equal(t, "manual", NormalizeRotationType("", FrequencyNone))
	assert.Equal(t, "schedule", NormalizeRotationType("", FrequencyWeekly))
	assert.Equal(t, "schedule", NormalizeRotationType("manual", FrequencyWeekly))
	assert.Equal(t, "round_robin", NormalizeRotationType("round_robin", FrequencyWeekly))
}

func ptrTime(t time.Time) *time.Time {
	return &t
}

func ptrDuration(d time.Duration) *time.Duration {
	return &d
}
