package services

// KNOWN BUG: CalendarService cannot be unit-tested with mocks because it
// depends on *repositories.PinwallRepository (a concrete struct) rather than
// the repositories.PinwallRepo interface. The pinwallRepo field is typed as:
//
//   pinwallRepo *repositories.PinwallRepository
//
// ...instead of repositories.PinwallRepo. Adding an interface seam requires a
// production-code change and is out of scope for this plan. Track as tech debt.
//
// The tests below are skipped stubs that document expected behavior so they can
// be enabled once the interface seam is added.

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
)

// TestCalendarService_GetCalendar_Skipped documents the interface seam problem.
// KNOWN BUG: CalendarService.pinwallRepo is *repositories.PinwallRepository
// (concrete type), not the PinwallRepo interface; mock injection is impossible
// without a production-code change. Remove the t.Skip once the seam is added.
func TestCalendarService_GetCalendar_Skipped(t *testing.T) {
	t.Skip("KNOWN BUG: CalendarService uses *repositories.PinwallRepository instead of repositories.PinwallRepo interface — cannot inject mock without production code change")

	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	_ = ctx
	_ = groupID
	_ = userID

	from := time.Now()
	to := from.Add(7 * 24 * time.Hour)
	_ = from
	_ = to

	// When the seam is fixed, wire mocks here and assert:
	// - member sees events from all sub-sources (meal plans, chores, recurring expenses, pinwall reminders, expenses)
	// - non-member receives permission denied
	// - empty date range returns empty slice (not nil)
}
