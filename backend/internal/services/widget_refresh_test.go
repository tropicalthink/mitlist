package services

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/push"
	"github.com/mitlist-app/mitlist/internal/sse"
)

type refreshMembersFake map[uuid.UUID][]uuid.UUID

func (f refreshMembersFake) ListMembershipsByGroup(_ context.Context, groupID uuid.UUID) ([]models.GroupMembership, error) {
	var out []models.GroupMembership
	for _, id := range f[groupID] {
		out = append(out, models.GroupMembership{GroupID: groupID, UserID: id})
	}
	return out, nil
}

type refreshDevicesFake struct {
	withWidgets map[uuid.UUID]bool
	tokens      []string
	cleared     []string
}

func (f *refreshDevicesFake) ListUsersWithWidgets(_ context.Context, ids []uuid.UUID) ([]uuid.UUID, error) {
	var out []uuid.UUID
	for _, id := range ids {
		if f.withWidgets[id] {
			out = append(out, id)
		}
	}
	return out, nil
}

func (f *refreshDevicesFake) ListPushTokens(context.Context, []uuid.UUID) ([]string, error) {
	return f.tokens, nil
}

func (f *refreshDevicesFake) ClearPushToken(_ context.Context, token string) error {
	f.cleared = append(f.cleared, token)
	return nil
}

type refreshPushFake struct {
	mu    sync.Mutex
	sends []refreshSend
}

type refreshSend struct {
	group uuid.UUID
	users []uuid.UUID
}

func (f *refreshPushFake) SendWidgetRefresh(_ context.Context, users []uuid.UUID, group uuid.UUID) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sends = append(f.sends, refreshSend{group: group, users: users})
}

type widgetKitFake struct {
	sent []string
	dead map[string]bool
}

func (f *widgetKitFake) SendWidgetPush(_ context.Context, token string) error {
	f.sent = append(f.sent, token)
	if f.dead[token] {
		return push.ErrAPNSUnregistered
	}
	return nil
}

type scheduledFire struct {
	delay time.Duration
	fire  func()
}

func newTestRefreshNotifier(members refreshMembersFake, devices *refreshDevicesFake, pushFake *refreshPushFake, apns widgetKitPush) (*WidgetRefreshNotifier, *time.Time, *[]scheduledFire) {
	now := time.Date(2026, 10, 2, 9, 0, 0, 0, time.UTC)
	var timers []scheduledFire
	n := NewWidgetRefreshNotifier(members, devices, pushFake, apns, nil)
	n.now = func() time.Time { return now }
	n.afterFunc = func(d time.Duration, f func()) { timers = append(timers, scheduledFire{d, f}) }
	return n, &now, &timers
}

func TestWidgetRefreshBatchesAndPacesPerHousehold(t *testing.T) {
	home, other := uuid.New(), uuid.New()
	me, sam, noWidgets := uuid.New(), uuid.New(), uuid.New()
	pushFake := &refreshPushFake{}
	n, now, timers := newTestRefreshNotifier(
		refreshMembersFake{home: {me, sam, noWidgets}, other: {me}},
		&refreshDevicesFake{withWidgets: map[uuid.UUID]bool{me: true, sam: true}},
		pushFake, nil)

	// A burst in one household arms one timer, after the batch window.
	n.Observe(sse.Event{Type: "list:item_created", GroupID: home.String()})
	n.Observe(sse.Event{Type: "list:item_updated", GroupID: home.String()})
	n.Observe(sse.Event{Type: "chore:completed", GroupID: home.String()})
	require.Len(t, *timers, 1)
	require.Equal(t, widgetRefreshBatch, (*timers)[0].delay)

	// Changes widgets do not show, and malformed events, are ignored.
	n.Observe(sse.Event{Type: "chore:subtask_created", GroupID: other.String()})
	n.Observe(sse.Event{Type: "recipe:created", GroupID: other.String()})
	n.Observe(sse.Event{Type: "list:item_created", GroupID: "not-a-uuid"})
	require.Len(t, *timers, 1)

	(*timers)[0].fire()
	require.Len(t, pushFake.sends, 1)
	require.Equal(t, home, pushFake.sends[0].group)
	require.ElementsMatch(t, []uuid.UUID{me, sam}, pushFake.sends[0].users, "only members with widgets")

	// The next change within the interval waits out the rest of it.
	*now = now.Add(10 * time.Second)
	n.Observe(sse.Event{Type: "expense:created", GroupID: home.String()})
	require.Len(t, *timers, 2)
	require.Equal(t, widgetRefreshInterval-10*time.Second, (*timers)[1].delay)

	// Another household is paced on its own.
	n.Observe(sse.Event{Type: "settlement:created", GroupID: other.String()})
	require.Len(t, *timers, 3)
	require.Equal(t, widgetRefreshBatch, (*timers)[2].delay)
}

func TestWidgetRefreshSkipsHouseholdsWithoutWidgets(t *testing.T) {
	home := uuid.New()
	pushFake := &refreshPushFake{}
	n, _, timers := newTestRefreshNotifier(refreshMembersFake{home: {uuid.New()}}, &refreshDevicesFake{}, pushFake, &widgetKitFake{})
	n.Observe(sse.Event{Type: "meal_plan:created", GroupID: home.String()})
	(*timers)[0].fire()
	require.Empty(t, pushFake.sends)
}

func TestWidgetRefreshSendsWidgetKitPushAndForgetsDeadTokens(t *testing.T) {
	home, me := uuid.New(), uuid.New()
	devices := &refreshDevicesFake{withWidgets: map[uuid.UUID]bool{me: true}, tokens: []string{"live", "dead"}}
	widgetKit := &widgetKitFake{dead: map[string]bool{"dead": true}}
	n, _, timers := newTestRefreshNotifier(refreshMembersFake{home: {me}}, devices, &refreshPushFake{}, widgetKit)
	n.Observe(sse.Event{Type: "group:updated", GroupID: home.String()})
	(*timers)[0].fire()
	require.Equal(t, []string{"live", "dead"}, widgetKit.sent)
	require.Equal(t, []string{"dead"}, devices.cleared)
}
