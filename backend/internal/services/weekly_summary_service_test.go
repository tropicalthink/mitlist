package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

type fakeWeeklyRepo struct {
	categories []models.WeeklyCategoryCount
	mine       int
	minePrev   int
	days       []models.WeeklyDayCount
	active     int
	members    int

	gotStart, gotCurrentStart, gotEnd time.Time
	gotOffsetMinutes                  int
}

func (f *fakeWeeklyRepo) CountByCategory(_ context.Context, _, _ uuid.UUID, start, currentStart, end time.Time) ([]models.WeeklyCategoryCount, error) {
	f.gotStart, f.gotCurrentStart, f.gotEnd = start, currentStart, end
	return f.categories, nil
}

func (f *fakeWeeklyRepo) CountMine(_ context.Context, _, _ uuid.UUID, _, _, _ time.Time) (int, int, error) {
	return f.mine, f.minePrev, nil
}

func (f *fakeWeeklyRepo) CountByDay(_ context.Context, _ uuid.UUID, _, _ time.Time, offsetMinutes int) ([]models.WeeklyDayCount, error) {
	f.gotOffsetMinutes = offsetMinutes
	return f.days, nil
}

func (f *fakeWeeklyRepo) CountActiveMembers(_ context.Context, _ uuid.UUID, _, _ time.Time) (int, int, error) {
	return f.active, f.members, nil
}

type fakeMemberChecker struct{ member bool }

func (f *fakeMemberChecker) GetMembership(_ context.Context, groupID, userID uuid.UUID) (*models.GroupMembership, error) {
	if !f.member {
		return nil, &notAMemberError{}
	}
	return &models.GroupMembership{GroupID: groupID, UserID: userID, Role: "member"}, nil
}

type notAMemberError struct{}

func (e *notAMemberError) Error() string { return "not a member" }

// pinnedNow is a Wednesday, so the seven-day window straddles a month boundary
// in neither direction — keeps the expected dates easy to read.
var pinnedNow = time.Date(2026, 8, 26, 15, 4, 5, 0, time.UTC)

func newTestService(repo WeeklySummaryRepo) *WeeklySummaryService {
	s := NewWeeklySummaryService(repo, &fakeMemberChecker{member: true})
	s.now = func() time.Time { return pinnedNow }
	return s
}

func TestWeeklySummary_FillsEveryCategoryInOrder(t *testing.T) {
	repo := &fakeWeeklyRepo{
		// Deliberately partial and out of order: only two of five categories,
		// reversed relative to the display order.
		categories: []models.WeeklyCategoryCount{
			{Category: models.WeeklyCategoryChores, Count: 11, Previous: 5, Mine: 4},
			{Category: models.WeeklyCategoryLists, Count: 21, Previous: 17, Mine: 8},
		},
	}
	svc := newTestService(repo)

	got, err := svc.GetWeeklySummary(context.Background(), &models.User{ID: uuid.New()}, uuid.New(), 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(got.Categories) != len(models.WeeklyCategoryOrder) {
		t.Fatalf("expected %d categories, got %d", len(models.WeeklyCategoryOrder), len(got.Categories))
	}
	for i, want := range models.WeeklyCategoryOrder {
		if got.Categories[i].Category != want {
			t.Errorf("category %d: want %q, got %q", i, want, got.Categories[i].Category)
		}
	}
	// Totals must sum the filled set, not just the rows the repo returned.
	if got.Total != 32 {
		t.Errorf("total: want 32, got %d", got.Total)
	}
	if got.Previous != 22 {
		t.Errorf("previous: want 22, got %d", got.Previous)
	}
	if got.Delta() != 10 {
		t.Errorf("delta: want 10, got %d", got.Delta())
	}
	// An absent category is zero, not missing.
	for _, c := range got.Categories {
		if c.Category == models.WeeklyCategoryMeals && (c.Count != 0 || c.Previous != 0) {
			t.Errorf("meals should be zero-filled, got %+v", c)
		}
	}
}

func TestWeeklySummary_PadsSevenDaysIncludingQuietOnes(t *testing.T) {
	// Only two of the seven days saw activity.
	repo := &fakeWeeklyRepo{
		days: []models.WeeklyDayCount{
			{Date: time.Date(2026, 8, 21, 0, 0, 0, 0, time.UTC), Count: 3},
			{Date: time.Date(2026, 8, 25, 0, 0, 0, 0, time.UTC), Count: 9},
		},
	}
	svc := newTestService(repo)

	got, err := svc.GetWeeklySummary(context.Background(), &models.User{ID: uuid.New()}, uuid.New(), 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(got.Days) != 7 {
		t.Fatalf("expected 7 days, got %d", len(got.Days))
	}
	// Seven days ending today: with now pinned to the 26th, the chart runs
	// from the 20th through the 26th. The partial tail of the window on the
	// 19th is not rendered.
	if gotFirst := got.Days[0].Date.Format("2006-01-02"); gotFirst != "2026-08-20" {
		t.Errorf("first day: want 2026-08-20, got %s", gotFirst)
	}
	if gotLast := got.Days[6].Date.Format("2006-01-02"); gotLast != "2026-08-26" {
		t.Errorf("last day: want 2026-08-26, got %s", gotLast)
	}
	byDate := map[string]int{}
	for _, d := range got.Days {
		byDate[d.Date.Format("2006-01-02")] = d.Count
	}
	if byDate["2026-08-21"] != 3 || byDate["2026-08-25"] != 9 {
		t.Errorf("known days not carried through: %v", byDate)
	}
	if byDate["2026-08-20"] != 0 {
		t.Errorf("quiet day should be 0, got %d", byDate["2026-08-20"])
	}
}

func TestWeeklySummary_WindowsAreAdjacentSevenDaySpans(t *testing.T) {
	repo := &fakeWeeklyRepo{}
	svc := newTestService(repo)

	if _, err := svc.GetWeeklySummary(context.Background(), &models.User{ID: uuid.New()}, uuid.New(), 0); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !repo.gotEnd.Equal(pinnedNow) {
		t.Errorf("end: want %v, got %v", pinnedNow, repo.gotEnd)
	}
	if want := pinnedNow.Add(-weekWindow); !repo.gotCurrentStart.Equal(want) {
		t.Errorf("currentStart: want %v, got %v", want, repo.gotCurrentStart)
	}
	if want := pinnedNow.Add(-2 * weekWindow); !repo.gotStart.Equal(want) {
		t.Errorf("start: want %v, got %v", want, repo.gotStart)
	}
	if repo.gotOffsetMinutes != 0 {
		t.Errorf("offset: want 0, got %d", repo.gotOffsetMinutes)
	}
}

func TestWeeklySummary_RejectsNonMembers(t *testing.T) {
	svc := NewWeeklySummaryService(&fakeWeeklyRepo{}, &fakeMemberChecker{member: false})
	svc.now = func() time.Time { return pinnedNow }

	_, err := svc.GetWeeklySummary(context.Background(), &models.User{ID: uuid.New()}, uuid.New(), 0)
	if err == nil {
		t.Fatal("expected an error for a non-member, got nil")
	}
}
