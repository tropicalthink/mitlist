package models

import (
	"time"

	"github.com/google/uuid"
)

// ProductEvent is one first-party product usage event (plans/048 stage 8):
// a step in the onboarding funnel or an action on Home. It identifies the
// person by account when signed in, otherwise by the random install id the
// app generated; it never holds an IP address, user agent or free text.
type ProductEvent struct {
	OccurredAt time.Time
	Name       string
	UserID     *uuid.UUID
	InstallID  *uuid.UUID
	GroupID    *uuid.UUID
	// Role is "creator" (the person made the household) or "invitee" (they
	// joined it); empty when no household is attached.
	Role  string
	Props map[string]string
}
