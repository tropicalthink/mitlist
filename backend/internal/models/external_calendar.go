package models

import (
	"time"

	"github.com/google/uuid"
)

// Calendar connection kinds.
const (
	CalendarConnectionICS    = "ics"
	CalendarConnectionDevice = "device"
)

// Share visibilities (per calendar and household).
const (
	ShareVisibilityBusy    = "busy"
	ShareVisibilityDetails = "details"
)

// Event override visibilities (per calendar and event UID, owner-wide).
const (
	OverrideHidden  = "hidden"
	OverrideBusy    = "busy"
	OverrideDetails = "details"
)

// Sync error codes reported in a connection's last_error.
const (
	CalendarErrFetchFailed  = "fetch_failed"
	CalendarErrNotCalendar  = "not_calendar"
	CalendarErrTooLarge     = "too_large"
	CalendarErrUnauthorized = "unauthorized"
)

// CalendarConnection is one source of a member's external calendars: an
// ICS subscription or a phone. The ICS URL is never serialized.
type CalendarConnection struct {
	ID           uuid.UUID          `json:"id"`
	UserID       uuid.UUID          `json:"-"`
	Kind         string             `json:"kind"`
	Name         string             `json:"name"`
	DeviceID     *string            `json:"device_id,omitempty"`
	LastSyncedAt *time.Time         `json:"last_synced_at,omitempty"`
	LastError    *string            `json:"last_error,omitempty"`
	Calendars    []ExternalCalendar `json:"calendars"`

	ICSURLEncrypted  []byte     `json:"-"`
	HTTPETag         *string    `json:"-"`
	HTTPLastModified *string    `json:"-"`
	LastAttemptAt    *time.Time `json:"-"`
	FailureCount     int        `json:"-"`
	NextAttemptAt    *time.Time `json:"-"`
	ContentHash      *string    `json:"-"`
	CreatedAt        time.Time  `json:"-"`
	UpdatedAt        time.Time  `json:"-"`
}

// ExternalCalendar is one calendar of a connection, with its household
// shares.
type ExternalCalendar struct {
	ID           uuid.UUID       `json:"id"`
	ConnectionID uuid.UUID       `json:"-"`
	UserID       uuid.UUID       `json:"-"`
	ExternalID   string          `json:"external_id"`
	Name         string          `json:"name"`
	Color        *string         `json:"color,omitempty"`
	Shares       []CalendarShare `json:"shares"`
}

// CalendarShare shares a calendar with one household.
type CalendarShare struct {
	GroupID    uuid.UUID `json:"group_id"`
	Visibility string    `json:"visibility"`
}

// ExternalEvent is a stored event instance. Title is nil when the source
// had none or the device left it out.
type ExternalEvent struct {
	ID            uuid.UUID
	CalendarID    uuid.UUID
	UserID        uuid.UUID
	ExternalUID   string
	StartsAt      time.Time
	EndsAt        time.Time
	AllDay        bool
	Title         *string
	SourcePrivate bool
	Free          bool
}

// OwnEvent is an event as its owner sees it (GET /calendar/external/events/mine).
type OwnEvent struct {
	CalendarID    uuid.UUID `json:"calendar_id"`
	ExternalUID   string    `json:"external_uid"`
	StartsAt      time.Time `json:"starts_at"`
	EndsAt        time.Time `json:"ends_at"`
	AllDay        bool      `json:"all_day"`
	Title         *string   `json:"title,omitempty"`
	SourcePrivate bool      `json:"source_private"`
	Free          bool      `json:"free"`
	Override      *string   `json:"override,omitempty"`
}

// EventOverride is one of the owner's per-event visibility choices. It may
// name an event the server does not store (a hidden phone event is never
// uploaded).
type EventOverride struct {
	CalendarID  uuid.UUID `json:"calendar_id"`
	ExternalUID string    `json:"external_uid"`
	Visibility  string    `json:"visibility"`
}

// HouseholdExternalEvent is a stored event shared with a household, with
// what decides its visibility there. OwnerIsMember is the owner's current
// membership of that household.
type HouseholdExternalEvent struct {
	Event           ExternalEvent
	ShareVisibility string
	Override        *string
	OwnerIsMember   bool
}
