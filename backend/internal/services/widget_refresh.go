package services

import (
	"context"
	"errors"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/push"
	"github.com/mitlist-app/mitlist/internal/sse"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Widget refresh pacing (plans/047, contract C6). A burst of edits collapses
// into one push sent widgetRefreshBatch after the first edit, and a
// household gets at most one push per widgetRefreshInterval. iOS throttles
// background pushes to a few an hour anyway.
const (
	widgetRefreshBatch    = 5 * time.Second
	widgetRefreshInterval = 60 * time.Second
	widgetRefreshTimeout  = 30 * time.Second
)

type widgetRefreshMembers interface {
	ListMembershipsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMembership, error)
}

type widgetRefreshDevices interface {
	ListUsersWithWidgets(ctx context.Context, userIDs []uuid.UUID) ([]uuid.UUID, error)
	ListPushTokens(ctx context.Context, userIDs []uuid.UUID) ([]string, error)
	ClearPushToken(ctx context.Context, token string) error
}

type widgetRefreshPush interface {
	SendWidgetRefresh(ctx context.Context, userIDs []uuid.UUID, groupID uuid.UUID)
}

type widgetKitPush interface {
	SendWidgetPush(ctx context.Context, deviceToken string) error
}

// WidgetRefreshNotifier tells the devices of a household's members to
// refresh their home screen widgets when something the widgets show
// changes. It observes the domain events this process publishes, so every
// write path is covered without each service knowing about widgets.
type WidgetRefreshNotifier struct {
	members widgetRefreshMembers
	devices widgetRefreshDevices
	push    widgetRefreshPush
	apns    widgetKitPush
	log     *logger.Logger

	batch, interval time.Duration
	now             func() time.Time
	afterFunc       func(time.Duration, func())

	mu       sync.Mutex
	pending  map[uuid.UUID]bool
	lastSent map[uuid.UUID]time.Time
}

// NewWidgetRefreshNotifier wires the notifier. apns may be nil when
// WidgetKit push is not configured; the FCM push still goes out.
func NewWidgetRefreshNotifier(members widgetRefreshMembers, devices widgetRefreshDevices, pushSvc widgetRefreshPush, apns widgetKitPush, log *logger.Logger) *WidgetRefreshNotifier {
	return &WidgetRefreshNotifier{
		members: members, devices: devices, push: pushSvc, apns: apns, log: log,
		batch: widgetRefreshBatch, interval: widgetRefreshInterval,
		now:       time.Now,
		afterFunc: func(d time.Duration, f func()) { time.AfterFunc(d, f) },
		pending:   map[uuid.UUID]bool{},
		lastSent:  map[uuid.UUID]time.Time{},
	}
}

// Observe is the hub's publish hook. It never blocks: it only arms a timer.
func (n *WidgetRefreshNotifier) Observe(event sse.Event) {
	if !widgetRelevantEvent(event.Type) {
		return
	}
	groupID, err := uuid.Parse(event.GroupID)
	if err != nil {
		return
	}
	n.schedule(groupID)
}

// widgetRelevantEvent reports whether an event changes something a widget
// shows: lists and items, chores, the household and its members, and the
// meal plan and money behind the household-today and balance widgets.
func widgetRelevantEvent(eventType string) bool {
	switch {
	case strings.HasPrefix(eventType, "chore:subtask"):
		return false
	case strings.HasPrefix(eventType, "list:"),
		strings.HasPrefix(eventType, "chore:"),
		strings.HasPrefix(eventType, "member:"),
		strings.HasPrefix(eventType, "meal_plan:"),
		strings.HasPrefix(eventType, "expense:"),
		strings.HasPrefix(eventType, "settlement:"),
		eventType == "group:updated", eventType == "group:deleted":
		return true
	}
	return false
}

func (n *WidgetRefreshNotifier) schedule(groupID uuid.UUID) {
	n.mu.Lock()
	defer n.mu.Unlock()
	if n.pending[groupID] {
		return
	}
	n.pending[groupID] = true
	delay := n.batch
	if last, ok := n.lastSent[groupID]; ok {
		if wait := last.Add(n.interval).Sub(n.now()); wait > delay {
			delay = wait
		}
	}
	n.afterFunc(delay, func() { n.fire(groupID) })
}

func (n *WidgetRefreshNotifier) fire(groupID uuid.UUID) {
	n.mu.Lock()
	now := n.now()
	delete(n.pending, groupID)
	n.lastSent[groupID] = now
	// Forget households that have been quiet for a whole interval, so the
	// map stays as small as the set of recently active households.
	for id, sent := range n.lastSent {
		if now.Sub(sent) > n.interval && !n.pending[id] {
			delete(n.lastSent, id)
		}
	}
	n.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), widgetRefreshTimeout)
	defer cancel()
	n.send(ctx, groupID)
}

func (n *WidgetRefreshNotifier) send(ctx context.Context, groupID uuid.UUID) {
	memberships, err := n.members.ListMembershipsByGroup(ctx, groupID)
	if err != nil {
		n.warn(err, "widget refresh: failed to list members")
		return
	}
	userIDs := make([]uuid.UUID, 0, len(memberships))
	for _, m := range memberships {
		userIDs = append(userIDs, m.UserID)
	}
	withWidgets, err := n.devices.ListUsersWithWidgets(ctx, userIDs)
	if err != nil {
		n.warn(err, "widget refresh: failed to find widget devices")
		return
	}
	if len(withWidgets) == 0 {
		return
	}
	n.push.SendWidgetRefresh(ctx, withWidgets, groupID)

	if n.apns == nil {
		return
	}
	tokens, err := n.devices.ListPushTokens(ctx, withWidgets)
	if err != nil {
		n.warn(err, "widget refresh: failed to list WidgetKit push tokens")
		return
	}
	for _, token := range tokens {
		err := n.apns.SendWidgetPush(ctx, token)
		switch {
		case err == nil:
		case errors.Is(err, push.ErrAPNSUnregistered):
			if clearErr := n.devices.ClearPushToken(ctx, token); clearErr != nil {
				n.warn(clearErr, "widget refresh: failed to forget a dead WidgetKit push token")
			}
		default:
			n.warn(err, "widget refresh: WidgetKit push failed")
		}
	}
}

func (n *WidgetRefreshNotifier) warn(err error, msg string) {
	if n.log != nil {
		n.log.Warn().Err(err).Msg(msg)
	}
}
