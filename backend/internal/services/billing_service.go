package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services/polar"
)

// DefaultFreeMemberLimit is the household size that stays free. Households of
// this many members or fewer never see a paywall; the limit only applies when
// growing past it. Chosen to cover an ordinary shared flat — the fifth member
// is where a household starts paying.
const DefaultFreeMemberLimit = 4

// PlanInterval identifies which of the two premium products to sell.
type PlanInterval string

const (
	PlanMonthly PlanInterval = "monthly"
	PlanYearly  PlanInterval = "yearly"
)

// BillingConfig is the subset of application config the billing service needs.
type BillingConfig struct {
	// FreeMemberLimit is the largest household size that stays free.
	FreeMemberLimit int
	// ProductIDMonthly and ProductIDYearly are the Polar products to sell.
	ProductIDMonthly string
	ProductIDYearly  string
	// DefaultDiscountID, when set, is auto-applied to every new checkout —
	// a launch promo, say. Customers can still enter their own code instead.
	DefaultDiscountID string
	// CheckoutSuccessURL is where Polar returns the customer after paying.
	CheckoutSuccessURL string
}

// Plan is what one of the two premium products costs, read from the payment
// provider rather than hardcoded so the app can never advertise a price the
// customer will not actually be charged.
type Plan struct {
	Interval    PlanInterval `json:"interval"`
	ProductID   string       `json:"product_id"`
	AmountCents int          `json:"amount_cents"`
	// Currency is upper-case ISO 4217 ("EUR"), normalised for client formatting.
	Currency string `json:"currency"`
}

// planCacheTTL is how long product prices are reused before being re-read from
// the provider. Prices change rarely and /billing/status is called on every app
// open, so this trades a little staleness for not hitting Polar constantly.
const planCacheTTL = time.Hour

// BillingService owns premium entitlement: who has paid, which household that
// covers, and how a household starts paying.
//
// The plan it enforces: a household of FreeMemberLimit members or fewer is
// free. Beyond that the household needs one member with a live subscription —
// any one member, covering everyone in it. A subscription covers exactly one
// household, the owner's designated "premium household", which they choose at
// checkout and can move later; it does not follow them into every household
// they belong to.
type BillingService struct {
	repo      repositories.BillingRepo
	groupRepo repositories.GroupRepo
	userRepo  repositories.UserRepo
	client    *polar.Client
	cfg       BillingConfig

	planMu      sync.RWMutex
	planCache   []Plan
	planFetched time.Time
}

// NewBillingService creates a BillingService. A nil or disabled client leaves
// checkout unavailable while entitlement reads keep working, so an instance
// with billing switched off behaves as if every household is free.
func NewBillingService(
	repo repositories.BillingRepo,
	groupRepo repositories.GroupRepo,
	userRepo repositories.UserRepo,
	client *polar.Client,
	cfg BillingConfig,
) *BillingService {
	if cfg.FreeMemberLimit <= 0 {
		cfg.FreeMemberLimit = DefaultFreeMemberLimit
	}
	return &BillingService{
		repo:      repo,
		groupRepo: groupRepo,
		userRepo:  userRepo,
		client:    client,
		cfg:       cfg,
	}
}

// Enabled reports whether checkout can actually be started.
func (s *BillingService) Enabled() bool {
	return s != nil && s.client.Enabled()
}

// FreeMemberLimit exposes the configured free household size.
func (s *BillingService) FreeMemberLimit() int {
	return s.cfg.FreeMemberLimit
}

// GetPlans returns what each premium interval costs, read from the payment
// provider's product catalog.
//
// Results are cached for planCacheTTL. A provider that is unreachable, or a
// product that carries no sellable price, yields an empty slice rather than an
// error: the price is decoration on a paywall that still works without it, and
// failing the whole status call over it would be worse than showing no price.
func (s *BillingService) GetPlans(ctx context.Context) []Plan {
	if !s.Enabled() {
		return nil
	}

	s.planMu.RLock()
	if s.planCache != nil && time.Since(s.planFetched) < planCacheTTL {
		cached := s.planCache
		s.planMu.RUnlock()
		return cached
	}
	s.planMu.RUnlock()

	plans := make([]Plan, 0, 2)
	for _, candidate := range []struct {
		interval  PlanInterval
		productID string
	}{
		{PlanYearly, s.cfg.ProductIDYearly},
		{PlanMonthly, s.cfg.ProductIDMonthly},
	} {
		if candidate.productID == "" {
			continue
		}
		product, err := s.client.GetProduct(ctx, candidate.productID)
		if err != nil {
			continue
		}
		price := product.ListedPrice()
		if price == nil {
			continue
		}
		plans = append(plans, Plan{
			Interval:    candidate.interval,
			ProductID:   candidate.productID,
			AmountCents: price.PriceAmount,
			Currency:    strings.ToUpper(price.PriceCurrency),
		})
	}

	// Only cache a complete-looking answer. Caching an empty result would hide
	// prices for a full hour after one transient provider failure.
	if len(plans) > 0 {
		s.planMu.Lock()
		s.planCache = plans
		s.planFetched = time.Now()
		s.planMu.Unlock()
	}
	return plans
}

// GetHouseholdEntitlement reports whether a household is premium and whether it
// may still grow. The caller's own subscription position is included so the
// client can offer "move your premium here" rather than a second checkout.
func (s *BillingService) GetHouseholdEntitlement(ctx context.Context, userID, groupID uuid.UUID) (*models.HouseholdEntitlement, error) {
	if _, err := s.groupRepo.GetMembership(ctx, groupID, userID); err != nil {
		return nil, &api.PermissionDeniedError{Action: "view household billing"}
	}
	return s.householdEntitlement(ctx, groupID, userID)
}

// householdEntitlement computes a household's position. viewerID may be
// uuid.Nil when there is no caller in context (the member gate), in which case
// the viewer fields are left zeroed.
func (s *BillingService) householdEntitlement(ctx context.Context, groupID, viewerID uuid.UUID) (*models.HouseholdEntitlement, error) {
	count, err := s.repo.CountGroupMembers(ctx, groupID)
	if err != nil {
		return nil, err
	}
	premium, coveredBy, err := s.repo.GetGroupCoverage(ctx, groupID)
	if err != nil {
		return nil, err
	}

	ent := &models.HouseholdEntitlement{
		GroupID:      groupID,
		MemberCount:  count,
		FreeLimit:    s.cfg.FreeMemberLimit,
		Premium:      premium,
		CanAddMember: premium || count < s.cfg.FreeMemberLimit,
		CoveredBy:    coveredBy,
	}

	if viewerID != uuid.Nil {
		sub, err := s.repo.GetLiveSubscriptionForUser(ctx, viewerID)
		if err != nil {
			return nil, err
		}
		if sub != nil {
			ent.ViewerSubscribed = true
			ent.ViewerPrimaryGroupID = sub.PrimaryGroupID
		}
	}
	return ent, nil
}

// SetPremiumHousehold points the caller's subscription at groupID — the
// PlayStation "make this my primary console" move. The caller must be a member
// of the household they are moving it to.
//
// Moving premium away from a household never removes anyone: the old household
// simply stops being able to add members once it is over the free limit.
func (s *BillingService) SetPremiumHousehold(ctx context.Context, userID, groupID uuid.UUID) (*models.BillingSubscription, error) {
	if groupID != uuid.Nil {
		if _, err := s.groupRepo.GetMembership(ctx, groupID, userID); err != nil {
			return nil, &api.PermissionDeniedError{Action: "set premium household"}
		}
	}

	sub, err := s.repo.SetPrimaryGroupForUser(ctx, userID, groupID)
	if err != nil {
		return nil, err
	}
	if sub == nil {
		return nil, &api.ValidationError{Message: "you have no active subscription to assign"}
	}
	return sub, nil
}

// EnsureCanAddMember is the gate called before a household grows. It returns a
// PaymentRequiredError when the household is at its free limit and nobody is
// paying.
//
// Households already over the limit are never broken up: this only refuses new
// members, it never evicts existing ones.
func (s *BillingService) EnsureCanAddMember(ctx context.Context, groupID uuid.UUID) error {
	ent, err := s.householdEntitlement(ctx, groupID, uuid.Nil)
	if err != nil {
		return err
	}
	if ent.CanAddMember {
		return nil
	}
	return &api.PaymentRequiredError{
		Message: fmt.Sprintf(
			"households of more than %d members need premium — one member's subscription covers this household",
			s.cfg.FreeMemberLimit,
		),
	}
}

// CheckoutInput describes a checkout the caller wants to start.
type CheckoutInput struct {
	Interval PlanInterval
	// GroupID is the household the subscription will cover once it is paid for.
	// Carried through Polar as checkout metadata and applied when the resulting
	// subscription webhook arrives. May be uuid.Nil, leaving the choice until
	// after payment.
	GroupID uuid.UUID
	// DiscountID optionally auto-applies a specific discount. When empty the
	// configured default (if any) is used. Customers can always type their own
	// code on the checkout page regardless.
	DiscountID string
}

// StartCheckout opens a hosted checkout session for the user and returns the
// URL to send them to.
func (s *BillingService) StartCheckout(ctx context.Context, userID uuid.UUID, in CheckoutInput) (string, error) {
	if !s.Enabled() {
		return "", &api.ValidationError{Message: "billing is not enabled on this server"}
	}

	productID := s.cfg.ProductIDMonthly
	if in.Interval == PlanYearly {
		productID = s.cfg.ProductIDYearly
	}
	if productID == "" {
		return "", &api.ValidationError{Field: "interval", Message: "no product is configured for that billing interval"}
	}

	// Refuse to sell a subscription for a household the buyer is not in — the
	// resulting entitlement would cover nothing.
	if in.GroupID != uuid.Nil {
		if _, err := s.groupRepo.GetMembership(ctx, in.GroupID, userID); err != nil {
			return "", &api.PermissionDeniedError{Action: "buy premium for this household"}
		}
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return "", err
	}

	discountID := in.DiscountID
	if discountID == "" {
		discountID = s.cfg.DefaultDiscountID
	}

	metadata := map[string]string{
		"app":     "mitlist",
		"user_id": userID.String(),
	}
	if in.GroupID != uuid.Nil {
		metadata["group_id"] = in.GroupID.String()
	}

	session, err := s.client.CreateCheckout(ctx, polar.CheckoutRequest{
		ProductID:          productID,
		ExternalCustomerID: userID.String(),
		CustomerEmail:      user.Email,
		SuccessURL:         s.cfg.CheckoutSuccessURL,
		DiscountID:         discountID,
		AllowDiscountCodes: true,
		Metadata:           metadata,
	})
	if err != nil {
		return "", err
	}
	return session.URL, nil
}

// OpenCustomerPortal returns a URL where the user manages their subscription
// (payment method, invoices, cancellation) on Polar.
func (s *BillingService) OpenCustomerPortal(ctx context.Context, userID uuid.UUID) (string, error) {
	if !s.Enabled() {
		return "", &api.ValidationError{Message: "billing is not enabled on this server"}
	}
	session, err := s.client.CreateCustomerSession(ctx, userID.String())
	if err != nil {
		var apiErr *polar.APIError
		if errors.As(err, &apiErr) && apiErr.StatusCode == 404 {
			return "", &api.NotFoundError{Resource: "subscription"}
		}
		return "", err
	}
	return session.CustomerPortalURL, nil
}

// GetUserSubscription returns the user's own live subscription, or nil.
func (s *BillingService) GetUserSubscription(ctx context.Context, userID uuid.UUID) (*models.BillingSubscription, error) {
	return s.repo.GetLiveSubscriptionForUser(ctx, userID)
}

// polarWebhookEvent is the envelope Polar posts for subscription events. Every
// subscription.* event carries a full subscription object, so one code path
// handles them all.
type polarWebhookEvent struct {
	Type string          `json:"type"`
	Data polarSubscriber `json:"data"`
}

type polarSubscriber struct {
	ID                string         `json:"id"`
	Status            string         `json:"status"`
	Amount            int            `json:"amount"`
	Currency          string         `json:"currency"`
	RecurringInterval *string        `json:"recurring_interval"`
	CurrentPeriodEnd  *time.Time     `json:"current_period_end"`
	CancelAtPeriodEnd bool           `json:"cancel_at_period_end"`
	TrialEnd          *time.Time     `json:"trial_end"`
	StartedAt         *time.Time     `json:"started_at"`
	EndsAt            *time.Time     `json:"ends_at"`
	ModifiedAt        *time.Time     `json:"modified_at"`
	CustomerID        string         `json:"customer_id"`
	ProductID         string         `json:"product_id"`
	DiscountID        *string        `json:"discount_id"`
	Metadata          map[string]any `json:"metadata"`
	Customer          struct {
		ExternalID *string `json:"external_id"`
		Email      string  `json:"email"`
	} `json:"customer"`
	Product struct {
		Metadata map[string]any `json:"metadata"`
	} `json:"product"`
}

// ErrEventIgnored reports an event that was understood but deliberately not
// applied — a duplicate delivery, another app's event, or an event type this
// service does not act on. The caller should acknowledge it, not retry.
var ErrEventIgnored = errors.New("billing: event ignored")

// ApplyWebhookEvent applies one verified Polar webhook delivery.
//
// deliveryID is the Standard Webhooks `webhook-id`, used to make redeliveries
// idempotent. The raw payload is parsed here rather than in the handler so the
// provider's wire format stays inside this package.
//
// Events for other applications sharing the same Polar organization are
// ignored, as are event types that carry no subscription state.
func (s *BillingService) ApplyWebhookEvent(ctx context.Context, deliveryID string, payload []byte) error {
	var evt polarWebhookEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return &api.ValidationError{Message: "malformed webhook payload"}
	}

	if !strings.HasPrefix(evt.Type, "subscription.") {
		return ErrEventIgnored
	}
	if !isMitlistEvent(evt.Data.Metadata, evt.Data.Product.Metadata) {
		return ErrEventIgnored
	}

	userID, err := resolveUser(evt.Data)
	if err != nil {
		return err
	}

	// Record the delivery before applying it. A redelivery of an event already
	// applied is dropped here.
	if deliveryID != "" {
		fresh, err := s.repo.MarkWebhookEventProcessed(ctx, deliveryID, "polar", evt.Type)
		if err != nil {
			return err
		}
		if !fresh {
			return ErrEventIgnored
		}
	}

	sub := &models.BillingSubscription{
		UserID:                 userID,
		PrimaryGroupID:         resolveGroup(evt.Data),
		Provider:               "polar",
		ProviderSubscriptionID: evt.Data.ID,
		ProviderCustomerID:     evt.Data.CustomerID,
		ProductID:              evt.Data.ProductID,
		Status:                 evt.Data.Status,
		RecurringInterval:      evt.Data.RecurringInterval,
		AmountCents:            evt.Data.Amount,
		Currency:               evt.Data.Currency,
		DiscountID:             evt.Data.DiscountID,
		CurrentPeriodEnd:       evt.Data.CurrentPeriodEnd,
		CancelAtPeriodEnd:      evt.Data.CancelAtPeriodEnd,
		TrialEnd:               evt.Data.TrialEnd,
		StartedAt:              evt.Data.StartedAt,
		EndsAt:                 evt.Data.EndsAt,
		ProviderModifiedAt:     evt.Data.ModifiedAt,
	}
	if sub.Currency == "" {
		sub.Currency = "eur"
	}

	_, err = s.repo.UpsertSubscription(ctx, sub)
	return err
}

// isMitlistEvent reports whether an event belongs to mitlist. The Polar
// organization is shared with other applications and webhook endpoints cannot
// be filtered by product, so every delivery must be checked.
func isMitlistEvent(eventMetadata, productMetadata map[string]any) bool {
	for _, m := range []map[string]any{eventMetadata, productMetadata} {
		if app, ok := m["app"].(string); ok && app == "mitlist" {
			return true
		}
	}
	return false
}

// resolveGroup reads the household a checkout was started for, which becomes
// the subscription's premium household. Returns nil when the subscription was
// created outside that flow, leaving the owner to choose in the app.
//
// The repository only applies this when no household is set yet, so a stale
// value on a later delivery cannot move a household the owner has since picked.
func resolveGroup(data polarSubscriber) *uuid.UUID {
	raw, ok := data.Metadata["group_id"].(string)
	if !ok {
		return nil
	}
	id, err := uuid.Parse(raw)
	if err != nil {
		return nil
	}
	return &id
}

// resolveUser maps a Polar subscription back to a mitlist account. Checkout
// stamps the user's UUID as the customer's external ID; metadata carries the
// same value as a fallback for subscriptions created outside that flow.
func resolveUser(data polarSubscriber) (uuid.UUID, error) {
	if data.Customer.ExternalID != nil {
		if id, err := uuid.Parse(*data.Customer.ExternalID); err == nil {
			return id, nil
		}
	}
	if raw, ok := data.Metadata["user_id"].(string); ok {
		if id, err := uuid.Parse(raw); err == nil {
			return id, nil
		}
	}
	return uuid.Nil, fmt.Errorf("billing: subscription %s has no resolvable mitlist user", data.ID)
}
