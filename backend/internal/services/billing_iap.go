package services

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/appstore"
	"github.com/mitlist-app/mitlist/internal/services/playstore"
)

// Provider names for native In-App Purchase subscriptions, stored in
// billing_subscriptions.provider alongside "polar".
const (
	ProviderApple  = "apple"
	ProviderGoogle = "google"
)

// AppleIAPEnabled reports whether Apple purchase verification is wired up.
func (s *BillingService) AppleIAPEnabled() bool {
	return s != nil && s.apple.Enabled()
}

// GoogleIAPEnabled reports whether Google purchase verification is wired up.
func (s *BillingService) GoogleIAPEnabled() bool {
	return s != nil && s.google.Enabled()
}

// VerifyAppleTransaction validates a StoreKit 2 signed transaction the app sent
// after a purchase, and records the resulting subscription against userID,
// covering groupID.
//
// The transaction is Apple-signed, so its contents are trustworthy once the
// signature verifies; this method adds the mitlist-side checks: the buyer is a
// member of the household, the receipt is not another account's, and the user
// does not already pay through a different provider.
func (s *BillingService) VerifyAppleTransaction(ctx context.Context, userID, groupID uuid.UUID, signedTransaction string) (*models.BillingSubscription, error) {
	if !s.AppleIAPEnabled() {
		return nil, &api.ValidationError{Message: "Apple in-app purchases are not enabled on this server"}
	}

	tx, err := s.apple.VerifyTransaction(signedTransaction)
	if err != nil {
		return nil, &api.ValidationError{Message: "this App Store receipt could not be verified"}
	}
	if s.cfg.AppleProductSupporter != "" && tx.ProductID == s.cfg.AppleProductSupporter {
		return nil, &api.ValidationError{Message: "this App Store product is the supporter pack, not a subscription"}
	}

	// A receipt carrying someone else's app account token must not be attachable
	// to the caller's account — that would let a leaked receipt be replayed.
	if err := ensureReceiptOwner(tx.AppAccountToken, userID); err != nil {
		return nil, err
	}
	if err := s.ensureMemberIfSet(ctx, userID, groupID); err != nil {
		return nil, err
	}
	if err := s.guardSingleProvider(ctx, userID, ProviderApple); err != nil {
		return nil, err
	}

	sub := s.subscriptionFromApple(tx, nil, userID, groupID)
	return s.repo.UpsertSubscription(ctx, sub)
}

// VerifyGooglePurchase validates a Google Play purchase token by fetching its
// authoritative state from Google, then records the subscription against userID.
func (s *BillingService) VerifyGooglePurchase(ctx context.Context, userID, groupID uuid.UUID, purchaseToken string) (*models.BillingSubscription, error) {
	if !s.GoogleIAPEnabled() {
		return nil, &api.ValidationError{Message: "Google Play purchases are not enabled on this server"}
	}

	gsub, err := s.google.GetSubscription(ctx, purchaseToken)
	if err != nil {
		return nil, &api.ValidationError{Message: "this Google Play purchase could not be verified"}
	}
	if err := s.google.ValidateSubscription(gsub); err != nil {
		return nil, &api.ValidationError{Message: "this Google Play product is not a mitlist premium plan"}
	}

	if err := ensureReceiptOwner(gsub.AccountToken, userID); err != nil {
		return nil, err
	}
	if err := s.ensureMemberIfSet(ctx, userID, groupID); err != nil {
		return nil, err
	}
	if err := s.guardSingleProvider(ctx, userID, ProviderGoogle); err != nil {
		return nil, err
	}

	sub := s.subscriptionFromGoogle(gsub, purchaseToken, userID, groupID)
	stored, err := s.repo.UpsertSubscription(ctx, sub)
	if err != nil {
		return nil, err
	}
	if err := s.supersedeLinkedGooglePurchase(ctx, gsub, purchaseToken, sub.ProviderModifiedAt); err != nil {
		return nil, err
	}
	return stored, nil
}

// ApplyAppleNotification applies one verified App Store Server Notification V2.
// Renewals, cancellations, and refunds all arrive this way and flow through the
// same idempotent upsert as the initial verify.
func (s *BillingService) ApplyAppleNotification(ctx context.Context, signedPayload string) error {
	if !s.AppleIAPEnabled() {
		return ErrEventIgnored
	}

	notif, err := s.apple.VerifyNotification(signedPayload)
	if err != nil {
		return &api.ValidationError{Message: "malformed App Store notification"}
	}
	if notif.Transaction == nil {
		// Consumption requests and other transaction-less events carry no state
		// mitlist tracks.
		return ErrEventIgnored
	}
	if s.cfg.AppleProductSupporter != "" && notif.Transaction.ProductID == s.cfg.AppleProductSupporter {
		return s.applyAppleSupporterNotification(ctx, notif)
	}

	userID, err := s.resolveAppleUser(ctx, notif.Transaction)
	if err != nil {
		return err
	}

	// Group is left nil: the upsert's COALESCE keeps the household the owner
	// already chose at verify time, so a renewal never unpins it.
	sub := s.subscriptionFromApple(notif.Transaction, notif.Renewal, userID, uuid.Nil)
	if _, err = s.repo.UpsertSubscription(ctx, sub); err != nil {
		return err
	}
	return s.markStoreEventApplied(ctx, ProviderApple, notif.UUID, notif.Type)
}

// ApplyGoogleNotification applies one Real-Time Developer Notification. The
// notification only names a purchase token; the true state is re-fetched from
// Google, so a forged Pub/Sub push cannot grant entitlement.
func (s *BillingService) ApplyGoogleNotification(ctx context.Context, body []byte) error {
	if !s.GoogleIAPEnabled() {
		return ErrEventIgnored
	}

	notif, messageID, err := playstore.DecodeNotification(body)
	if err != nil {
		return &api.ValidationError{Message: "malformed Play notification"}
	}
	if notif.PackageName != s.google.PackageName() {
		return &api.ValidationError{Message: "Play notification is for another app"}
	}
	if notif.OneTimeProductNotification != nil {
		return s.applyGoogleOneTimeNotification(ctx, notif, messageID)
	}
	if notif.SubscriptionNotification == nil {
		// A test notification: nothing to apply.
		return ErrEventIgnored
	}
	if notif.SubscriptionNotification.SubscriptionID != s.google.SubscriptionID() {
		return &api.ValidationError{Message: "Play notification is for another app or subscription"}
	}

	token := notif.SubscriptionNotification.PurchaseToken
	gsub, err := s.google.GetSubscription(ctx, token)
	if err != nil {
		return err
	}
	if err := s.google.ValidateSubscription(gsub); err != nil {
		return &api.ValidationError{Message: "Play notification names an unconfigured product"}
	}

	userID, err := s.resolveGoogleUser(ctx, gsub, token)
	if err != nil {
		return err
	}

	sub := s.subscriptionFromGoogle(gsub, token, userID, uuid.Nil)
	_, err = s.repo.UpsertSubscription(ctx, sub)
	if err != nil {
		return err
	}
	if err := s.supersedeLinkedGooglePurchase(ctx, gsub, token, sub.ProviderModifiedAt); err != nil {
		return err
	}
	eventType := fmt.Sprintf("subscription.%d", notif.SubscriptionNotification.NotificationType)
	return s.markStoreEventApplied(ctx, ProviderGoogle, messageID, eventType)
}

// ensureReceiptOwner rejects a purchase whose embedded account token names a
// different mitlist user. Initial verification requires a valid stamped token;
// otherwise a leaked legacy receipt could be claimed by another account.
func ensureReceiptOwner(accountToken string, userID uuid.UUID) error {
	parsed, err := uuid.Parse(accountToken)
	if err != nil {
		return &api.PermissionDeniedError{Action: "claim an unstamped purchase"}
	}
	if parsed != userID {
		return &api.PermissionDeniedError{Action: "claim this purchase"}
	}
	return nil
}

func (s *BillingService) markStoreEventApplied(ctx context.Context, provider, deliveryID, eventType string) error {
	if deliveryID == "" {
		return nil
	}
	fresh, err := s.repo.MarkWebhookEventProcessed(ctx, provider+":"+deliveryID, provider, eventType)
	if err != nil {
		return err
	}
	if !fresh {
		return ErrEventIgnored
	}
	return nil
}

// ensureMemberIfSet checks group membership when a household is named, mirroring
// the web checkout's refusal to sell premium for a household the buyer is not in.
func (s *BillingService) ensureMemberIfSet(ctx context.Context, userID, groupID uuid.UUID) error {
	if groupID == uuid.Nil {
		return nil
	}
	if _, err := s.groupRepo.GetMembership(ctx, groupID, userID); err != nil {
		return &api.PermissionDeniedError{Action: "buy premium for this household"}
	}
	return nil
}

// guardSingleProvider refuses a new purchase when the user already holds a live
// subscription through a different provider, so a user who pays on the web is
// never charged again in the app (or vice versa). A re-verify of the same
// provider is allowed — it just refreshes the existing row.
func (s *BillingService) guardSingleProvider(ctx context.Context, userID uuid.UUID, provider string) error {
	existing, err := s.repo.GetLiveSubscriptionForUser(ctx, userID)
	if err != nil {
		return err
	}
	if existing != nil && existing.Provider != provider {
		return &api.ConflictError{Message: "you already have an active subscription; manage it where you started it"}
	}
	return nil
}

// resolveAppleUser maps an Apple transaction to a mitlist account: the app
// account token first, then an existing subscription keyed on the original
// transaction id (for renewals that carry no token).
func (s *BillingService) resolveAppleUser(ctx context.Context, tx *appstore.TransactionInfo) (uuid.UUID, error) {
	if tx.AppAccountToken != "" {
		if id, err := uuid.Parse(tx.AppAccountToken); err == nil {
			return id, nil
		}
	}
	if existing, err := s.repo.GetSubscriptionByProviderID(ctx, ProviderApple, tx.OriginalTransactionID); err == nil && existing != nil {
		return existing.UserID, nil
	}
	return uuid.Nil, fmt.Errorf("billing: apple transaction %s has no resolvable mitlist user", tx.OriginalTransactionID)
}

// resolveGoogleUser maps a Google purchase to a mitlist account: the obfuscated
// account id first, then an existing subscription keyed on the purchase token.
func (s *BillingService) resolveGoogleUser(ctx context.Context, gsub *playstore.Subscription, token string) (uuid.UUID, error) {
	if gsub.AccountToken != "" {
		if id, err := uuid.Parse(gsub.AccountToken); err == nil {
			return id, nil
		}
	}
	if existing, err := s.repo.GetSubscriptionByProviderID(ctx, ProviderGoogle, token); err == nil && existing != nil {
		return existing.UserID, nil
	}
	if gsub.LinkedPurchaseToken != "" {
		if existing, err := s.repo.GetSubscriptionByProviderID(ctx, ProviderGoogle, gsub.LinkedPurchaseToken); err == nil && existing != nil {
			return existing.UserID, nil
		}
	}
	return uuid.Nil, fmt.Errorf("billing: google purchase has no resolvable mitlist user")
}

// subscriptionFromApple turns a verified transaction into a storable
// subscription. It keys on the original transaction id, stable across renewals.
func (s *BillingService) subscriptionFromApple(tx *appstore.TransactionInfo, renewal *appstore.RenewalInfo, userID, groupID uuid.UUID) *models.BillingSubscription {
	now := time.Now().UTC()
	periodEnd := tx.Expiry()
	status := models.SubscriptionStatusActive
	if tx.Revoked() || (!periodEnd.IsZero() && periodEnd.Before(now)) {
		status = models.SubscriptionStatusCanceled
	}
	if renewal != nil && renewal.IsInBillingRetryPeriod {
		grace := renewal.GracePeriodExpiry()
		if grace.IsZero() || grace.Before(now) {
			status = models.SubscriptionStatusPastDue
		} else {
			// Access continues through Apple's grace period, even though the
			// transaction's original expiration is already in the past.
			status = models.SubscriptionStatusActive
			if grace.After(periodEnd) {
				periodEnd = grace
			}
		}
	}

	modified := tx.ModifiedAt()
	if renewal != nil && renewal.ModifiedAt().After(modified) {
		modified = renewal.ModifiedAt()
	}
	if modified.IsZero() {
		modified = now
	}
	sub := &models.BillingSubscription{
		UserID:                 userID,
		PrimaryGroupID:         groupPtr(groupID),
		Provider:               ProviderApple,
		ProviderSubscriptionID: tx.OriginalTransactionID,
		ProviderCustomerID:     tx.AppAccountToken,
		ProductID:              tx.ProductID,
		Status:                 status,
		RecurringInterval:      intervalPtr(s.intervalForApple(tx.ProductID)),
		// Amount is deliberately not read from the receipt: StoreKit reports
		// price in milliunits and its presence varies by SDK, so a wrong number
		// is worse than none. Revenue for IAP comes from store reporting.
		AmountCents:        0,
		Currency:           normaliseCurrency(tx.Currency),
		CancelAtPeriodEnd:  renewal != nil && renewal.AutoRenewStatus == 0,
		ProviderModifiedAt: &modified,
	}
	if !periodEnd.IsZero() {
		sub.CurrentPeriodEnd = &periodEnd
	}
	return sub
}

func (s *BillingService) supersedeLinkedGooglePurchase(ctx context.Context, gsub *playstore.Subscription, currentToken string, modifiedAt *time.Time) error {
	if gsub.LinkedPurchaseToken == "" || gsub.LinkedPurchaseToken == currentToken {
		return nil
	}
	at := time.Now().UTC()
	if modifiedAt != nil {
		at = *modifiedAt
	}
	return s.repo.SupersedeSubscription(ctx, ProviderGoogle, gsub.LinkedPurchaseToken, at)
}

// subscriptionFromGoogle turns an authoritative Play subscription into a
// storable subscription, keyed on the purchase token.
func (s *BillingService) subscriptionFromGoogle(gsub *playstore.Subscription, token string, userID, groupID uuid.UUID) *models.BillingSubscription {
	now := time.Now().UTC()
	sub := &models.BillingSubscription{
		UserID:                 userID,
		PrimaryGroupID:         groupPtr(groupID),
		Provider:               ProviderGoogle,
		ProviderSubscriptionID: token,
		ProviderCustomerID:     gsub.AccountToken,
		ProductID:              gsub.ProductID,
		Status:                 googleStatus(gsub.State),
		RecurringInterval:      intervalPtr(s.intervalForGoogle(gsub.BasePlanID)),
		AmountCents:            0,
		Currency:               "eur",
		CancelAtPeriodEnd:      !gsub.AutoRenewing,
		ProviderModifiedAt:     &now,
	}
	if !gsub.ExpiryTime.IsZero() {
		sub.CurrentPeriodEnd = &gsub.ExpiryTime
	}
	return sub
}

// googleStatus maps a Play subscription state to a mitlist status. Only 'active'
// (and 'trialing') grant entitlement; the SQL live check additionally requires
// the period end to be in the future, so a lapsed row can never be live even if
// its status is stale.
func googleStatus(state string) string {
	switch state {
	case playstore.StateActive, playstore.StateCanceled, playstore.StateInGracePeriod:
		return models.SubscriptionStatusActive
	case playstore.StateOnHold:
		return models.SubscriptionStatusPastDue
	case playstore.StatePaused:
		return models.SubscriptionStatusPaused
	case playstore.StatePending:
		return models.SubscriptionStatusUnpaid
	default: // expired, or an unrecognised future state
		return models.SubscriptionStatusCanceled
	}
}

// intervalForApple maps an App Store product id to a billing cadence, or "" when
// it matches neither configured product.
func (s *BillingService) intervalForApple(productID string) string {
	switch productID {
	case s.cfg.AppleProductMonthly:
		return "month"
	case s.cfg.AppleProductYearly:
		return "year"
	default:
		return ""
	}
}

// intervalForGoogle maps a Play base-plan id to a billing cadence.
func (s *BillingService) intervalForGoogle(basePlanID string) string {
	switch basePlanID {
	case s.cfg.GoogleProductMonthly:
		return "month"
	case s.cfg.GoogleProductYearly:
		return "year"
	default:
		return ""
	}
}

// groupPtr returns a pointer to groupID, or nil for uuid.Nil so the upsert's
// COALESCE leaves an already-chosen household untouched.
func groupPtr(groupID uuid.UUID) *uuid.UUID {
	if groupID == uuid.Nil {
		return nil
	}
	return &groupID
}

// intervalPtr returns nil for an empty interval, matching Polar's optional
// recurring_interval.
func intervalPtr(interval string) *string {
	if interval == "" {
		return nil
	}
	return &interval
}

// normaliseCurrency lower-cases the currency to match the column's convention,
// defaulting to eur when the receipt omits it.
func normaliseCurrency(currency string) string {
	if currency == "" {
		return "eur"
	}
	return strings.ToLower(currency)
}
