package services

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// WeeklySummaryRepo is the repository surface the weekly summary needs.
type WeeklySummaryRepo interface {
	CountByCategory(ctx context.Context, groupID, userID uuid.UUID, start, currentStart, end time.Time) ([]models.WeeklyCategoryCount, error)
	CountMine(ctx context.Context, groupID, userID uuid.UUID, start, currentStart, end time.Time) (int, int, error)
	CountByDay(ctx context.Context, groupID uuid.UUID, currentStart, end time.Time, offsetMinutes int) ([]models.WeeklyDayCount, error)
	CountActiveMembers(ctx context.Context, groupID uuid.UUID, currentStart, end time.Time) (int, int, error)
}

// WeeklySummaryService builds the household's week-over-week activity summary.
type WeeklySummaryService struct {
	repo      WeeklySummaryRepo
	groupRepo GroupMembershipChecker
	// now is injectable so tests can pin the week boundaries.
	now func() time.Time
}

// NewWeeklySummaryService creates a new WeeklySummaryService.
func NewWeeklySummaryService(repo WeeklySummaryRepo, groupRepo GroupMembershipChecker) *WeeklySummaryService {
	return &WeeklySummaryService{repo: repo, groupRepo: groupRepo, now: time.Now}
}

// weekWindow is the reporting period length. The digest job runs every seven
// days and reports the seven days behind it; the screen must agree.
const weekWindow = 7 * 24 * time.Hour

// GetWeeklySummary returns the last seven days of household activity compared
// against the seven days before that.
//
// offsetMinutes is the caller's UTC offset, used only to bucket the daily
// sparkline against their own calendar. Zero means UTC.
func (s *WeeklySummaryService) GetWeeklySummary(
	ctx context.Context, user *models.User, groupID uuid.UUID, offsetMinutes int,
) (*models.WeeklySummary, error) {
	if err := requireGroupMember(ctx, s.groupRepo, groupID, user.ID); err != nil {
		return nil, err
	}

	end := s.now().UTC()
	currentStart := end.Add(-weekWindow)
	start := currentStart.Add(-weekWindow)

	categories, err := s.repo.CountByCategory(ctx, groupID, user.ID, start, currentStart, end)
	if err != nil {
		return nil, err
	}
	mine, minePrevious, err := s.repo.CountMine(ctx, groupID, user.ID, start, currentStart, end)
	if err != nil {
		return nil, err
	}
	days, err := s.repo.CountByDay(ctx, groupID, currentStart, end, offsetMinutes)
	if err != nil {
		return nil, err
	}
	activeMembers, memberCount, err := s.repo.CountActiveMembers(ctx, groupID, currentStart, end)
	if err != nil {
		return nil, err
	}

	summary := &models.WeeklySummary{
		GroupID:       groupID.String(),
		PeriodStart:   currentStart,
		PeriodEnd:     end,
		Mine:          mine,
		MinePrevious:  minePrevious,
		Categories:    orderCategories(categories),
		Days:          padDays(days, end, offsetMinutes),
		ActiveMembers: activeMembers,
		MemberCount:   memberCount,
	}
	for _, c := range summary.Categories {
		summary.Total += c.Count
		summary.Previous += c.Previous
	}
	return summary, nil
}

// orderCategories returns every known category in display order, filling in
// zeroes for the ones the query returned no row for. The client can then render
// a stable list without special-casing absent keys.
func orderCategories(found []models.WeeklyCategoryCount) []models.WeeklyCategoryCount {
	byKey := make(map[string]models.WeeklyCategoryCount, len(found))
	for _, c := range found {
		byKey[c.Category] = c
	}
	out := make([]models.WeeklyCategoryCount, 0, len(models.WeeklyCategoryOrder))
	for _, key := range models.WeeklyCategoryOrder {
		if c, ok := byKey[key]; ok {
			out = append(out, c)
			continue
		}
		out = append(out, models.WeeklyCategoryCount{Category: key})
	}
	return out
}

// padDays expands the sparse per-day rows into exactly seven consecutive days
// ending today (in the client's zone), oldest first. A quiet day must render as
// a zero-height bar rather than shifting the chart, so the gaps are filled here
// and not in the UI.
//
// The rolling [end-7d, end) window touches up to eight calendar days; the
// oldest, partial one is dropped so the chart always ends on today. Its events
// still count toward Total, so the bars can sum to slightly less than the
// headline.
func padDays(found []models.WeeklyDayCount, end time.Time, offsetMinutes int) []models.WeeklyDayCount {
	loc := time.FixedZone("client", offsetMinutes*60)
	byDay := make(map[string]int, len(found))
	for _, d := range found {
		byDay[d.Date.Format("2006-01-02")] = d.Count
	}

	last := end.In(loc)
	first := time.Date(last.Year(), last.Month(), last.Day(), 0, 0, 0, 0, loc).AddDate(0, 0, -6)

	out := make([]models.WeeklyDayCount, 0, 7)
	for i := 0; i < 7; i++ {
		day := first.AddDate(0, 0, i)
		out = append(out, models.WeeklyDayCount{
			Date:  day,
			Count: byDay[day.Format("2006-01-02")],
		})
	}
	return out
}
