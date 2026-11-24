package services

import (
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
)

// ExternalEventView is how much of a member's synced event a household sees.
type ExternalEventView int

const (
	// ExternalViewNone: the event is not shown at all.
	ExternalViewNone ExternalEventView = iota
	// ExternalViewBusy: a time block, no title and no other text.
	ExternalViewBusy
	// ExternalViewDetails: the time block with its title.
	ExternalViewDetails
)

// ExternalVisibilityInput is everything the visibility rule reads.
type ExternalVisibilityInput struct {
	// ShareVisibility is the (calendar, household) share: "" when there is
	// no share row, else "busy" or "details".
	ShareVisibility string
	// OwnerIsMember is whether the owner is a current member of the
	// household right now.
	OwnerIsMember bool
	// Override is the owner's per-event override: "", "hidden", "busy" or
	// "details".
	Override string
	// SourcePrivate is set for events the source calendar marks private.
	SourcePrivate bool
	// HasTitle is whether a non-empty title is stored.
	HasTitle bool
}

// ResolveExternalEventView is the single visibility rule for synced events
// (the contract's rules 1-4). Anything it does not recognise resolves to
// nothing, so a bad value can only hide an event, never reveal one.
func ResolveExternalEventView(in ExternalVisibilityInput) ExternalEventView {
	// 1. Not shared with this household, or the owner has left it.
	if !in.OwnerIsMember {
		return ExternalViewNone
	}
	if in.ShareVisibility != models.ShareVisibilityBusy && in.ShareVisibility != models.ShareVisibilityDetails {
		return ExternalViewNone
	}
	var view ExternalEventView
	switch in.Override {
	// 2. The owner's override wins.
	case models.OverrideHidden:
		return ExternalViewNone
	case models.OverrideBusy:
		view = ExternalViewBusy
	case models.OverrideDetails:
		view = ExternalViewDetails
	case "":
		// 3. Private at the source: busy; else the share's visibility.
		switch {
		case in.SourcePrivate:
			view = ExternalViewBusy
		case in.ShareVisibility == models.ShareVisibilityDetails:
			view = ExternalViewDetails
		default:
			view = ExternalViewBusy
		}
	default:
		return ExternalViewNone
	}
	// 4. Details without a title degrade to busy.
	if view == ExternalViewDetails && !in.HasTitle {
		view = ExternalViewBusy
	}
	return view
}

// householdCalendarEvent is the calendar event a household sees of h, or
// nil when it sees nothing. A busy event carries no title.
func householdCalendarEvent(h models.HouseholdExternalEvent, groupID uuid.UUID) *models.CalendarEvent {
	e := h.Event
	override := ""
	if h.Override != nil {
		override = *h.Override
	}
	hasTitle := e.Title != nil && *e.Title != ""
	view := ResolveExternalEventView(ExternalVisibilityInput{
		ShareVisibility: h.ShareVisibility,
		OwnerIsMember:   h.OwnerIsMember,
		Override:        override,
		SourcePrivate:   e.SourcePrivate,
		HasTitle:        hasTitle,
	})
	if view == ExternalViewNone {
		return nil
	}
	title := ""
	if view == ExternalViewDetails {
		title = *e.Title
	}
	return &models.CalendarEvent{
		ID:      "ext:" + e.ID.String(),
		Type:    models.EventTypeExternalEvent,
		Title:   title,
		Date:    e.StartsAt.UTC(),
		GroupID: groupID,
		External: &models.CalendarExternal{
			UserID:   e.UserID,
			StartsAt: e.StartsAt.UTC(),
			EndsAt:   e.EndsAt.UTC(),
			AllDay:   e.AllDay,
			BusyOnly: view == ExternalViewBusy,
			Free:     e.Free,
		},
	}
}
