package services

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/appstore"
	"github.com/mitlist-app/mitlist/internal/services/playstore"
	"github.com/mitlist-app/mitlist/internal/services/polar"
)

// The supporter pack is a one-time purchase that thanks the buyer with a badge
// their housemates can see and unlocks look customisation. It gates nothing a
// household needs: it exists so a happy three-person flat has a way to pay
// without touching the free tier.
//
// It is tied to the person, not a household. A premium subscription is pinned
// to one group because the member limit is a property of the group; a theme
// and a badge are personal and follow their owner everywhere.

// PlanOnce marks the supporter pack's price in a Plan: it is charged once.
const PlanOnce PlanInterval = "once"

// SupporterEnabled reports whether any configured provider sells the supporter
// pack. Self-hosted instances leave every product id empty, which hides the
// purchase and — on the client — unlocks the customisation for everyone.
func (s *BillingService) SupporterEnabled() bool {
	return s != nil && (s.WebSupporterEnabled() ||
		(s.AppleIAPEnabled() && s.cfg.AppleProductSupporter != "") ||
		(s.GoogleIAPEnabled() && s.cfg.GoogleProductSupporter != ""))
}

// WebSupporterEnabled reports whether the pack can be bought through Polar.
func (s *BillingService) WebSupporterEnabled() bool {
	return s.WebBillingEnabled() && s.cfg.ProductIDSupporter != ""
}

// IsSupporter reports whether userID holds a paid supporter purchase.
func (s *BillingService) IsSupporter(ctx context.Context, userID uuid.UUID) (bool, error) {
	p, err := s.repo.GetPaidSupporterPurchaseForUser(ctx, userID)
	if err != nil {
		return false, err
	}
	return p.IsPaid(), nil
}

// GetSupporterPurchase returns the purchase that makes the user a supporter,
// or nil.
func (s *BillingService) GetSupporterPurchase(ctx context.Context, userID uuid.UUID) (*models.SupporterPurchase, error) {
	return s.repo.GetPaidSupporterPurchaseForUser(ctx, userID)
}

// supporterPlanCache mirrors the subscription plan cache for the one-time
// product. It lives on the service through a small holder so BillingService's
// zero value in tests stays usable.
type supporterPlanCache struct {
	mu      sync.RWMutex
	plan    *Plan
	fetched time.Time
}

// GetSupporterPlan returns what the pack costs on the web, read from Polar's
// catalog. Nil when the pack is not sold here or the provider is unreachable;
// as with subscriptions, a missing price degrades to "no price shown" rather
// than to an error.
func (s *BillingService) GetSupporterPlan(ctx context.Context) *Plan {
	if !s.WebSupporterEnabled() {
		return nil
	}

	s.supporterCache.mu.RLock()
	if s.supporterCache.plan != nil && time.Since(s.supporterCache.fetched) < planCacheTTL {
		cached := s.supporterCache.plan
		s.supporterCache.mu.RUnlock()
		return cached
	}
	s.supporterCache.mu.RUnlock()

	product, err := s.client.GetProduct(ctx, s.cfg.ProductIDSupporter)
	if err != nil {
		return nil
	}
	price := product.ListedPrice()
	if price == nil {
		return nil
	}
	plan := &Plan{
		Interval:    PlanOnce,
		ProductID:   s.cfg.ProductIDSupporter,
		AmountCents: price.PriceAmount,
		Currency:    strings.ToUpper(price.PriceCurrency),
	}

	s.supporterCache.mu.Lock()
	s.supporterCache.plan = plan
	s.supporterCache.fetched = time.Now()
	s.supporterCache.mu.Unlock()
	return plan
}

// StartSupporterCheckout opens a hosted checkout for the supporter pack and
// returns the URL to send the user to. Refused when they already are one: a
// second purchase would change nothing and only cost them money.
func (s *BillingService) StartSupporterCheckout(ctx context.Context, userID uuid.UUID) (string, error) {
	if !s.WebSupporterEnabled() {
		return "", &api.ValidationError{Message: "the supporter pack is not available on this server"}
	}
	already, err := s.IsSupporter(ctx, userID)
	if err != nil {
		return "", err
	}
	if already {
		return "", &api.ConflictError{Message: "you are already a supporter — thank you"}
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return "", err
	}

	session, err := s.client.CreateCheckout(ctx, polar.CheckoutRequest{
		ProductID:          s.cfg.ProductIDSupporter,
		ExternalCustomerID: userID.String(),
		CustomerEmail:      user.Email,
		SuccessURL:         s.cfg.CheckoutSuccessURL,
		AllowDiscountCodes: true,
		Metadata: map[string]string{
			"app":     "mitlist",
			"user_id": userID.String(),
			"kind":    "supporter",
		},
	})
	if err != nil {
		return "", err
	}
	return session.URL, nil
}

// polarOrderEvent is the envelope Polar posts for order.* events. Every order
// event carries the full order, so one path handles paid and refunded alike.
type polarOrderEvent struct {
	Type string     `json:"type"`
	Data polarOrder `json:"data"`
}

type polarOrder struct {
	ID             string         `json:"id"`
	Status         string         `json:"status"`
	Paid           bool           `json:"paid"`
	TotalAmount    int            `json:"total_amount"`
	RefundedAmount int            `json:"refunded_amount"`
	Currency       string         `json:"currency"`
	ProductID      string         `json:"product_id"`
	CustomerID     string         `json:"customer_id"`
	SubscriptionID *string        `json:"subscription_id"`
	CreatedAt      *time.Time     `json:"created_at"`
	ModifiedAt     *time.Time     `json:"modified_at"`
	Metadata       map[string]any `json:"metadata"`
	Customer       struct {
		ExternalID *string `json:"external_id"`
	} `json:"customer"`
	Product struct {
		Metadata map[string]any `json:"metadata"`
	} `json:"product"`
}

// applyPolarOrderEvent records a supporter purchase from an order.* webhook.
// Orders for any other product — including the invoices a subscription raises
// every period — are ignored; subscriptions are tracked by subscription.* events.
func (s *BillingService) applyPolarOrderEvent(ctx context.Context, deliveryID string, payload []byte) error {
	var evt polarOrderEvent
	if err := json.Unmarshal(payload, &evt); err != nil {
		return &api.ValidationError{Message: "malformed webhook payload"}
	}
	if !isMitlistEvent(evt.Data.Metadata, evt.Data.Product.Metadata) {
		return ErrEventIgnored
	}
	if s.cfg.ProductIDSupporter == "" || evt.Data.ProductID != s.cfg.ProductIDSupporter {
		return ErrEventIgnored
	}

	// resolveUser reads the same two places an order carries: the customer's
	// external id (stamped at checkout) and the checkout metadata.
	subscriber := polarSubscriber{ID: evt.Data.ID, Metadata: evt.Data.Metadata}
	subscriber.Customer.ExternalID = evt.Data.Customer.ExternalID
	userID, err := resolveUser(subscriber)
	if err != nil {
		return err
	}

	purchase := &models.SupporterPurchase{
		UserID:             userID,
		Provider:           "polar",
		ProviderOrderID:    evt.Data.ID,
		ProviderCustomerID: evt.Data.CustomerID,
		ProductID:          evt.Data.ProductID,
		Status:             polarOrderStatus(evt.Data),
		AmountCents:        evt.Data.TotalAmount,
		Currency:           evt.Data.Currency,
		ProviderModifiedAt: evt.Data.ModifiedAt,
	}
	if purchase.Currency == "" {
		purchase.Currency = "eur"
	}
	if purchase.Status == models.SupporterStatusPaid {
		purchase.PurchasedAt = firstTime(evt.Data.ModifiedAt, evt.Data.CreatedAt)
	}
	if purchase.Status == models.SupporterStatusRefunded {
		purchase.RefundedAt = firstTime(evt.Data.ModifiedAt)
	}

	if _, err := s.repo.UpsertSupporterPurchase(ctx, purchase); err != nil {
		return err
	}
	if deliveryID != "" {
		fresh, markErr := s.repo.MarkWebhookEventProcessed(ctx, deliveryID, "polar", evt.Type)
		if markErr != nil {
			return markErr
		}
		if !fresh {
			return ErrEventIgnored
		}
	}
	return nil
}

// polarOrderStatus maps an order's state onto a supporter status. A partial
// refund still counts as refunded: the pack is one indivisible thing.
func polarOrderStatus(o polarOrder) string {
	switch o.Status {
	case "refunded", "partially_refunded":
		return models.SupporterStatusRefunded
	case "paid":
		return models.SupporterStatusPaid
	}
	if o.Paid && o.RefundedAmount == 0 {
		return models.SupporterStatusPaid
	}
	return models.SupporterStatusPending
}

// VerifyAppleSupporter validates a StoreKit 2 signed transaction for the
// non-consumable supporter product and records it against userID.
func (s *BillingService) VerifyAppleSupporter(ctx context.Context, userID uuid.UUID, signedTransaction string) (*models.SupporterPurchase, error) {
	if !s.AppleIAPEnabled() || s.cfg.AppleProductSupporter == "" {
		return nil, &api.ValidationError{Message: "the supporter pack is not available on this server"}
	}
	tx, err := s.apple.VerifyTransaction(signedTransaction)
	if err != nil {
		return nil, &api.ValidationError{Message: "this App Store receipt could not be verified"}
	}
	if tx.ProductID != s.cfg.AppleProductSupporter {
		return nil, &api.ValidationError{Message: "this App Store product is not the supporter pack"}
	}
	if err := ensureReceiptOwner(tx.AppAccountToken, userID); err != nil {
		return nil, err
	}
	return s.repo.UpsertSupporterPurchase(ctx, s.supporterFromApple(tx, userID))
}

// VerifyGoogleSupporter validates a Play purchase token for the one-time
// supporter product, re-fetching its state from Google, and records it.
func (s *BillingService) VerifyGoogleSupporter(ctx context.Context, userID uuid.UUID, purchaseToken string) (*models.SupporterPurchase, error) {
	if !s.GoogleIAPEnabled() || s.cfg.GoogleProductSupporter == "" {
		return nil, &api.ValidationError{Message: "the supporter pack is not available on this server"}
	}
	gp, err := s.google.GetProduct(ctx, s.cfg.GoogleProductSupporter, purchaseToken)
	if err != nil {
		return nil, &api.ValidationError{Message: "this Google Play purchase could not be verified"}
	}
	if err := ensureReceiptOwner(gp.AccountToken, userID); err != nil {
		return nil, err
	}
	return s.repo.UpsertSupporterPurchase(ctx, s.supporterFromGoogle(gp, purchaseToken, userID))
}

// applyAppleSupporterNotification handles a notification whose transaction is
// the supporter product — a refund, in practice. Called from
// ApplyAppleNotification once the product is known.
func (s *BillingService) applyAppleSupporterNotification(ctx context.Context, notif *appstore.VerifiedNotification) error {
	tx := notif.Transaction
	userID := uuid.Nil
	if tx.AppAccountToken != "" {
		if id, err := uuid.Parse(tx.AppAccountToken); err == nil {
			userID = id
		}
	}
	if userID == uuid.Nil {
		existing, err := s.repo.GetSupporterPurchaseByProviderID(ctx, ProviderApple, tx.OriginalTransactionID)
		if err != nil {
			return err
		}
		if existing == nil {
			// A refund for a purchase this server never recorded: nothing to
			// revoke, and no account to attach it to.
			return ErrEventIgnored
		}
		userID = existing.UserID
	}
	if _, err := s.repo.UpsertSupporterPurchase(ctx, s.supporterFromApple(tx, userID)); err != nil {
		return err
	}
	return s.markStoreEventApplied(ctx, ProviderApple, notif.UUID, notif.Type)
}

// applyGoogleOneTimeNotification handles a Play one-time-product RTDN. As with
// subscriptions the notification is only a hint: the state is re-fetched.
func (s *BillingService) applyGoogleOneTimeNotification(ctx context.Context, notif *playstore.DeveloperNotification, messageID string) error {
	otp := notif.OneTimeProductNotification
	if s.cfg.GoogleProductSupporter == "" || otp.SKU != s.cfg.GoogleProductSupporter {
		return ErrEventIgnored
	}
	gp, err := s.google.GetProduct(ctx, otp.SKU, otp.PurchaseToken)
	if err != nil {
		return err
	}
	userID := uuid.Nil
	if id, parseErr := uuid.Parse(gp.AccountToken); parseErr == nil {
		userID = id
	}
	if userID == uuid.Nil {
		existing, err := s.repo.GetSupporterPurchaseByProviderID(ctx, ProviderGoogle, otp.PurchaseToken)
		if err != nil {
			return err
		}
		if existing == nil {
			return ErrEventIgnored
		}
		userID = existing.UserID
	}
	if _, err := s.repo.UpsertSupporterPurchase(ctx, s.supporterFromGoogle(gp, otp.PurchaseToken, userID)); err != nil {
		return err
	}
	return s.markStoreEventApplied(ctx, ProviderGoogle, messageID, "one_time."+strconv.Itoa(otp.NotificationType))
}

// supporterFromApple turns a verified non-consumable transaction into a
// storable purchase. Non-consumables never expire; the only later state Apple
// reports is a revocation (refund).
func (s *BillingService) supporterFromApple(tx *appstore.TransactionInfo, userID uuid.UUID) *models.SupporterPurchase {
	modified := tx.ModifiedAt()
	if modified.IsZero() {
		modified = time.Now().UTC()
	}
	p := &models.SupporterPurchase{
		UserID:             userID,
		Provider:           ProviderApple,
		ProviderOrderID:    tx.OriginalTransactionID,
		ProviderCustomerID: tx.AppAccountToken,
		ProductID:          tx.ProductID,
		Status:             models.SupporterStatusPaid,
		// Price is deliberately not read from the receipt, matching the
		// subscription path: store revenue comes from store reporting.
		AmountCents:        0,
		Currency:           normaliseCurrency(tx.Currency),
		ProviderModifiedAt: &modified,
	}
	if tx.PurchaseDate > 0 {
		at := time.UnixMilli(tx.PurchaseDate).UTC()
		p.PurchasedAt = &at
	}
	if tx.Revoked() {
		p.Status = models.SupporterStatusRefunded
		at := time.UnixMilli(tx.RevocationDate).UTC()
		p.RefundedAt = &at
	}
	return p
}

// supporterFromGoogle turns an authoritative Play product purchase into a
// storable purchase, keyed on the purchase token.
func (s *BillingService) supporterFromGoogle(gp *playstore.ProductPurchase, token string, userID uuid.UUID) *models.SupporterPurchase {
	now := time.Now().UTC()
	p := &models.SupporterPurchase{
		UserID:             userID,
		Provider:           ProviderGoogle,
		ProviderOrderID:    token,
		ProviderCustomerID: gp.AccountToken,
		ProductID:          gp.ProductID,
		Status:             googleProductStatus(gp.State),
		AmountCents:        0,
		Currency:           "eur",
		ProviderModifiedAt: &now,
	}
	if !gp.PurchaseTime.IsZero() {
		at := gp.PurchaseTime
		p.PurchasedAt = &at
	}
	if p.Status == models.SupporterStatusRefunded {
		p.RefundedAt = &now
	}
	return p
}

// googleProductStatus maps a Play one-time purchase state to a supporter
// status. Google reports a refunded or voided purchase as canceled.
func googleProductStatus(state int) string {
	switch state {
	case playstore.ProductPurchased:
		return models.SupporterStatusPaid
	case playstore.ProductCanceled:
		return models.SupporterStatusRefunded
	default:
		return models.SupporterStatusPending
	}
}

// firstTime returns the first non-nil time, or nil.
func firstTime(candidates ...*time.Time) *time.Time {
	for _, c := range candidates {
		if c != nil {
			return c
		}
	}
	return nil
}

