package models

import (
	"time"

	"github.com/google/uuid"
)

// Subscription statuses mirrored from the payment provider. Only Active and
// Trialing grant entitlement.
const (
	SubscriptionStatusActive   = "active"
	SubscriptionStatusTrialing = "trialing"
	SubscriptionStatusPastDue  = "past_due"
	SubscriptionStatusCanceled = "canceled"
	SubscriptionStatusUnpaid   = "unpaid"
	SubscriptionStatusPaused   = "paused"
)

// BillingSubscription is a premium subscription held by one user. It covers
// exactly one household — PrimaryGroupID, the "premium household" — rather than
// every household the payer belongs to. The owner picks which, and can move it.
type BillingSubscription struct {
	ID     uuid.UUID `json:"id"`
	UserID uuid.UUID `json:"user_id"`
	// PrimaryGroupID is the single household this subscription makes premium.
	// Nil means the owner has not chosen one yet (or the household was
	// deleted), in which case the subscription covers nothing.
	PrimaryGroupID         *uuid.UUID `json:"primary_group_id,omitempty"`
	Provider               string     `json:"provider"`
	ProviderSubscriptionID string     `json:"provider_subscription_id"`
	ProviderCustomerID     string     `json:"provider_customer_id"`
	ProductID              string     `json:"product_id"`
	Status                 string     `json:"status"`
	RecurringInterval      *string    `json:"recurring_interval,omitempty"`
	AmountCents            int        `json:"amount_cents"`
	Currency               string     `json:"currency"`
	DiscountID             *string    `json:"discount_id,omitempty"`
	CurrentPeriodEnd       *time.Time `json:"current_period_end,omitempty"`
	CancelAtPeriodEnd      bool       `json:"cancel_at_period_end"`
	TrialEnd               *time.Time `json:"trial_end,omitempty"`
	StartedAt              *time.Time `json:"started_at,omitempty"`
	EndsAt                 *time.Time `json:"ends_at,omitempty"`
	ProviderModifiedAt     *time.Time `json:"-"`
	CreatedAt              time.Time  `json:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at"`
}

// IsLive reports whether the subscription currently grants entitlement.
// A subscription that is canceled but still inside its paid period keeps its
// entitlement: the provider reports it as active until the period ends.
func (s *BillingSubscription) IsLive(now time.Time) bool {
	if s.Status != SubscriptionStatusActive && s.Status != SubscriptionStatusTrialing {
		return false
	}
	if s.CurrentPeriodEnd != nil && s.CurrentPeriodEnd.Before(now) {
		return false
	}
	return true
}

// HouseholdEntitlement describes whether a household may keep growing and what
// is standing in its way. It is what the client renders the paywall from.
type HouseholdEntitlement struct {
	GroupID     uuid.UUID `json:"group_id"`
	MemberCount int       `json:"member_count"`
	FreeLimit   int       `json:"free_limit"`
	// Premium is true when some member has designated this household as their
	// subscription's premium household, which lifts the limit for everyone in it.
	Premium bool `json:"premium"`
	// CanAddMember is false when the household is at the free limit and nobody
	// has paid. Existing members are never locked out — only growth is gated.
	CanAddMember bool `json:"can_add_member"`
	// CoveredBy is the display name of the member whose subscription is
	// covering this household, when there is one.
	CoveredBy *string `json:"covered_by,omitempty"`
	// ViewerSubscribed reports whether the caller personally holds a live
	// subscription. Together with ViewerPrimaryGroupID it lets the client tell
	// "you need to subscribe" apart from "you already pay, but your premium is
	// pinned to another household — move it here".
	ViewerSubscribed bool `json:"viewer_subscribed"`
	// ViewerPrimaryGroupID is where the caller's own subscription is currently
	// pinned, when they hold one.
	ViewerPrimaryGroupID *uuid.UUID `json:"viewer_primary_group_id,omitempty"`
}

// Supporter purchase statuses. Only Paid grants the supporter perks.
const (
	SupporterStatusPaid     = "paid"
	SupporterStatusPending  = "pending"
	SupporterStatusRefunded = "refunded"
)

// SupporterPurchase is the one-time supporter pack bought by one user. Unlike
// a BillingSubscription it covers no household: the badge and the look
// customisation it unlocks belong to the person who paid and follow them into
// every household they are in.
type SupporterPurchase struct {
	ID                 uuid.UUID  `json:"id"`
	UserID             uuid.UUID  `json:"user_id"`
	Provider           string     `json:"provider"`
	ProviderOrderID    string     `json:"provider_order_id"`
	ProviderCustomerID string     `json:"provider_customer_id"`
	ProductID          string     `json:"product_id"`
	Status             string     `json:"status"`
	AmountCents        int        `json:"amount_cents"`
	Currency           string     `json:"currency"`
	PurchasedAt        *time.Time `json:"purchased_at,omitempty"`
	RefundedAt         *time.Time `json:"refunded_at,omitempty"`
	ProviderModifiedAt *time.Time `json:"-"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
}

// IsPaid reports whether this purchase currently grants the supporter perks.
func (p *SupporterPurchase) IsPaid() bool {
	return p != nil && p.Status == SupporterStatusPaid
}
