package models

import "time"

// Weekly summary category keys. These are stable API values: the Flutter client
// maps them to icons and localized labels, so renaming one is a breaking change.
const (
	WeeklyCategoryLists    = "lists"
	WeeklyCategoryExpenses = "expenses"
	WeeklyCategoryChores   = "chores"
	WeeklyCategoryMeals    = "meals"
	WeeklyCategoryRecipes  = "recipes"
)

// WeeklyCategoryOrder is the display order the client renders categories in.
// Kept server-side so a future reordering does not need a client release.
var WeeklyCategoryOrder = []string{
	WeeklyCategoryLists,
	WeeklyCategoryExpenses,
	WeeklyCategoryChores,
	WeeklyCategoryMeals,
	WeeklyCategoryRecipes,
}

// WeeklyCategoryCount is one activity category over the reported week, with the
// same category's count in the preceding week for comparison.
type WeeklyCategoryCount struct {
	Category string `json:"category"`
	Count    int    `json:"count"`
	Previous int    `json:"previous"`
	// Mine is how many of Count the requesting user is attributed with.
	Mine int `json:"mine"`
}

// Delta is the week-over-week change for this category.
func (c WeeklyCategoryCount) Delta() int { return c.Count - c.Previous }

// WeeklyDayCount is one day's total, used for the sparkline. Always exactly
// seven entries, oldest first, including days with no activity.
type WeeklyDayCount struct {
	Date  time.Time `json:"date"`
	Count int       `json:"count"`
}

// WeeklySummary is the household's activity for the last seven days, compared
// against the seven days before that.
//
// The definition of "activity" matches the weekly digest notification exactly
// (see jobs.WeeklySummary). The windows are not identical, though: the digest
// counts a week fixed at job time while this counts a rolling week at request
// time, so the two numbers drift apart as the tap gets further from the push.
type WeeklySummary struct {
	GroupID string `json:"group_id"`

	// PeriodStart is inclusive, PeriodEnd exclusive.
	PeriodStart time.Time `json:"period_start"`
	PeriodEnd   time.Time `json:"period_end"`

	Total    int `json:"total"`
	Previous int `json:"previous"`
	// Mine is the requesting user's share of Total.
	Mine int `json:"mine"`
	// MinePrevious is the same user's share of Previous, so the client can say
	// whether *they* did more, not just the household.
	MinePrevious int `json:"mine_previous"`

	Categories []WeeklyCategoryCount `json:"categories"`
	Days       []WeeklyDayCount      `json:"days"`

	// ActiveMembers is how many distinct members are attributed with at least
	// one activity this week; MemberCount is the household size.
	ActiveMembers int `json:"active_members"`
	MemberCount   int `json:"member_count"`
}

// Delta is the household's week-over-week change.
func (s WeeklySummary) Delta() int { return s.Total - s.Previous }
