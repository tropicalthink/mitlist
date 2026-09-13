package models

import (
	"time"

	"github.com/google/uuid"
)

// Group represents a household or team group.
type Group struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description,omitempty"`
	Currency    string    `json:"currency"`
	ChoreZones  []string  `json:"chore_zones"`
	CreatedBy   uuid.UUID `json:"created_by"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// GroupMembership links a user to a group with a role.
type GroupMembership struct {
	ID       uuid.UUID `json:"id"`
	GroupID  uuid.UUID `json:"group_id"`
	UserID   uuid.UUID `json:"user_id"`
	Role     string    `json:"role"`
	JoinedAt time.Time `json:"joined_at"`
	// LeftAt is set when the member was removed or left. The row is kept so
	// their expenses, chores and posts still resolve to a name; a rejoin
	// clears it again.
	LeftAt *time.Time `json:"left_at,omitempty"`
}

// GroupMemberProfile is a membership enriched with display information.
type GroupMemberProfile struct {
	UserID      uuid.UUID `json:"user_id"`
	DisplayName string    `json:"display_name"`
	Role        string    `json:"role"`
	// Supporter is true when this member bought the supporter pack; the
	// client renders a badge housemates can see.
	Supporter bool `json:"supporter"`
	// LeftAt is set for former members. They are listed so history keeps its
	// names; clients must not offer them for new assignments or splits.
	LeftAt *time.Time `json:"left_at,omitempty"`
}

// GroupInvite stores an invite code for joining a group. A code admits anyone
// who presents it until it expires; accepting does not consume it, so one
// link can bring in a whole household.
type GroupInvite struct {
	ID        uuid.UUID `json:"id"`
	GroupID   uuid.UUID `json:"group_id"`
	Code      string    `json:"code"`
	ExpiresAt time.Time `json:"expires_at"`
}

// Invite preview statuses. A preview tells the recipient what accepting
// would do before they commit.
const (
	InviteStatusValid         = "valid"
	InviteStatusExpired       = "expired"
	InviteStatusAlreadyMember = "already_member"
)

// InvitePreview is what a recipient sees on the accept/decline page: which
// household the code opens, how big it is, and whether it can still be used.
type InvitePreview struct {
	Code        string    `json:"code"`
	GroupID     uuid.UUID `json:"group_id"`
	GroupName   string    `json:"group_name"`
	MemberCount int       `json:"member_count"`
	ExpiresAt   time.Time `json:"expires_at"`
	Status      string    `json:"status"`
}

// PendingClaim stores a claim code that can be used to join a group.
type PendingClaim struct {
	ID        uuid.UUID  `json:"id"`
	GroupID   uuid.UUID  `json:"group_id"`
	Code      string     `json:"code"`
	ExpiresAt time.Time  `json:"expires_at"`
	ClaimedBy *uuid.UUID `json:"claimed_by,omitempty"`
	ClaimedAt *time.Time `json:"claimed_at,omitempty"`
}
