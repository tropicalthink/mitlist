package services

import (
	"context"
	"regexp"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
)

// Product events (plans/048 stage 8) are first-party usage events: the
// onboarding funnel and actions on Home. This service is the gate in front
// of the store: a fixed name allowlist, short identifier-like props (never
// free text), a sane timestamp, and a household only when the caller is in it.

// ProductEventMaxBatch is how many events one request may carry.
const ProductEventMaxBatch = 20

const (
	productEventMaxProps = 6
	// productEventMaxAge drops events from a queue that sat on a device for
	// more than a week, or a clock that is badly wrong; they are stamped with
	// the receive time instead.
	productEventMaxAge  = 7 * 24 * time.Hour
	productEventMaxSkew = 5 * time.Minute
)

// productEventNames is the allowlist. Anything else is dropped.
var productEventNames = map[string]bool{
	"welcome_shown":         true,
	"tour_started":          true,
	"tour_skipped":          true,
	"tour_completed":        true,
	"signup_completed":      true,
	"household_created":     true,
	"household_joined":      true,
	"intent_answered":       true,
	"first_item_added":      true,
	"checklist_step_done":   true,
	"home_needs_you_action": true,
}

var (
	productEventPropKey = regexp.MustCompile(`^[a-z][a-z0-9_]{0,31}$`)
	// Values are identifiers (a page number, a step, a row type), so the
	// charset leaves no room for names, emails or other free text.
	productEventPropValue = regexp.MustCompile(`^[A-Za-z0-9_.:-]{1,64}$`)
)

type productEventStore interface {
	InsertEvents(ctx context.Context, events []models.ProductEvent) error
}

type productEventGroups interface {
	GetGroupByIDForUser(ctx context.Context, id, userID uuid.UUID) (*models.Group, error)
}

// ProductEventInput is one event as the app sends it.
type ProductEventInput struct {
	Name       string            `json:"name"`
	OccurredAt *time.Time        `json:"occurred_at,omitempty"`
	GroupID    *uuid.UUID        `json:"group_id,omitempty"`
	Props      map[string]string `json:"props,omitempty"`
}

// ProductEventService validates and stores product events.
type ProductEventService struct {
	store  productEventStore
	groups productEventGroups
	now    func() time.Time
}

func NewProductEventService(store productEventStore, groups productEventGroups) *ProductEventService {
	return &ProductEventService{store: store, groups: groups, now: time.Now}
}

// Record stores a batch for the signed-in caller (userID) or, before sign-up,
// for the app install (installID); one of the two is required. An event that
// fails validation is dropped rather than failing the batch, so an app with a
// newer allowlist than the server loses only what the server does not know.
// A household is attached only when the caller is a member, which also
// decides their role in it. It returns how many events were stored.
func (s *ProductEventService) Record(ctx context.Context, userID, installID *uuid.UUID, inputs []ProductEventInput) (int, error) {
	if userID == nil && installID == nil {
		return 0, &api.ValidationError{Field: "install_id", Message: "is required without a session"}
	}
	if len(inputs) > ProductEventMaxBatch {
		return 0, &api.ValidationError{Field: "events", Message: "too many events in one request"}
	}

	now := s.now().UTC()
	roles := map[uuid.UUID]string{}
	events := make([]models.ProductEvent, 0, len(inputs))
	for _, in := range inputs {
		if !productEventNames[in.Name] {
			continue
		}
		props, ok := cleanProductEventProps(in.Props)
		if !ok {
			continue
		}
		event := models.ProductEvent{
			OccurredAt: now,
			Name:       in.Name,
			UserID:     userID,
			InstallID:  installID,
			Props:      props,
		}
		if at := in.OccurredAt; at != nil && at.After(now.Add(-productEventMaxAge)) && at.Before(now.Add(productEventMaxSkew)) {
			event.OccurredAt = at.UTC()
		}
		if in.GroupID != nil && userID != nil {
			role, seen := roles[*in.GroupID]
			if !seen {
				role = s.roleIn(ctx, *in.GroupID, *userID)
				roles[*in.GroupID] = role
			}
			if role != "" {
				groupID := *in.GroupID
				event.GroupID = &groupID
				event.Role = role
			}
		}
		events = append(events, event)
	}
	if len(events) == 0 {
		return 0, nil
	}
	if err := s.store.InsertEvents(ctx, events); err != nil {
		return 0, err
	}
	return len(events), nil
}

// roleIn is "creator" when the caller made the household, "invitee" when they
// joined it, and empty when they are not a member (or the lookup failed).
func (s *ProductEventService) roleIn(ctx context.Context, groupID, userID uuid.UUID) string {
	group, err := s.groups.GetGroupByIDForUser(ctx, groupID, userID)
	if err != nil || group == nil {
		return ""
	}
	if group.CreatedBy == userID {
		return "creator"
	}
	return "invitee"
}

func cleanProductEventProps(props map[string]string) (map[string]string, bool) {
	if len(props) > productEventMaxProps {
		return nil, false
	}
	out := make(map[string]string, len(props))
	for k, v := range props {
		if !productEventPropKey.MatchString(k) || !productEventPropValue.MatchString(v) {
			return nil, false
		}
		out[k] = v
	}
	return out, true
}
