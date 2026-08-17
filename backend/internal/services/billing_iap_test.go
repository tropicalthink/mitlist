package services

import (
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/appstore"
	"github.com/mitlist-app/mitlist/internal/services/playstore"
	"github.com/mitlist-app/mitlist/internal/services/polar"
)

func TestEnabledIncludesNativeIAPWithoutPolar(t *testing.T) {
	svc := &BillingService{
		client: polar.New("", ""),
		apple: appstore.New(appstore.Config{
			BundleID: "me.mitlist", Environment: "Both",
			ProductIDMonthly: "me.mitlist.premium.monthly",
			ProductIDYearly:  "me.mitlist.premium.yearly",
		}),
	}
	if !svc.Enabled() {
		t.Fatal("Apple IAP must enable billing even when Polar is disabled")
	}
	if svc.WebBillingEnabled() {
		t.Fatal("native IAP must not make Polar checkout look enabled")
	}
}

func TestAppleRenewalLifecycleMapping(t *testing.T) {
	svc := &BillingService{cfg: BillingConfig{AppleProductMonthly: "monthly"}}
	future := time.Now().Add(24 * time.Hour)
	tx := &appstore.TransactionInfo{
		OriginalTransactionID: "original", ProductID: "monthly",
		ExpiresDate: future.UnixMilli(), PurchaseDate: time.Now().UnixMilli(),
	}
	sub := svc.subscriptionFromApple(tx, &appstore.RenewalInfo{AutoRenewStatus: 0}, uuid.New(), uuid.Nil)
	if !sub.CancelAtPeriodEnd || sub.Status != models.SubscriptionStatusActive {
		t.Fatalf("auto-renew off should remain active through expiry: %+v", sub)
	}
	sub = svc.subscriptionFromApple(tx, &appstore.RenewalInfo{AutoRenewStatus: 1, IsInBillingRetryPeriod: true}, uuid.New(), uuid.Nil)
	if sub.Status != models.SubscriptionStatusPastDue {
		t.Fatalf("billing retry without grace should be past due, got %q", sub.Status)
	}

	expired := time.Now().Add(-time.Hour)
	grace := time.Now().Add(24 * time.Hour)
	tx.ExpiresDate = expired.UnixMilli()
	sub = svc.subscriptionFromApple(tx, &appstore.RenewalInfo{
		AutoRenewStatus:        1,
		IsInBillingRetryPeriod: true,
		GracePeriodExpiresDate: grace.UnixMilli(),
	}, uuid.New(), uuid.Nil)
	if sub.Status != models.SubscriptionStatusActive || sub.CurrentPeriodEnd == nil || sub.CurrentPeriodEnd.Before(grace.Add(-time.Second)) {
		t.Fatalf("Apple grace period should preserve entitlement through grace expiry: %+v", sub)
	}
}

func TestGoogleStatusMapping(t *testing.T) {
	cases := map[string]string{
		playstore.StateActive:        models.SubscriptionStatusActive,
		playstore.StateCanceled:      models.SubscriptionStatusActive, // entitled until expiry
		playstore.StateInGracePeriod: models.SubscriptionStatusActive,
		playstore.StateOnHold:        models.SubscriptionStatusPastDue,
		playstore.StatePaused:        models.SubscriptionStatusPaused,
		playstore.StatePending:       models.SubscriptionStatusUnpaid,
		playstore.StateExpired:       models.SubscriptionStatusCanceled,
		"SOMETHING_NEW":              models.SubscriptionStatusCanceled,
	}
	for state, want := range cases {
		if got := googleStatus(state); got != want {
			t.Errorf("googleStatus(%q) = %q, want %q", state, got, want)
		}
	}
}

func TestIntervalMaps(t *testing.T) {
	svc := &BillingService{cfg: BillingConfig{
		AppleProductMonthly:  "com.app.monthly",
		AppleProductYearly:   "com.app.yearly",
		GoogleProductMonthly: "premium-monthly",
		GoogleProductYearly:  "premium-yearly",
	}}

	if got := svc.intervalForApple("com.app.monthly"); got != "month" {
		t.Errorf("apple monthly = %q", got)
	}
	if got := svc.intervalForApple("com.app.yearly"); got != "year" {
		t.Errorf("apple yearly = %q", got)
	}
	if got := svc.intervalForApple("unknown"); got != "" {
		t.Errorf("apple unknown = %q, want empty", got)
	}
	if got := svc.intervalForGoogle("premium-yearly"); got != "year" {
		t.Errorf("google yearly = %q", got)
	}
	if got := svc.intervalForGoogle("premium-monthly"); got != "month" {
		t.Errorf("google monthly = %q", got)
	}
}

func TestEnsureReceiptOwner(t *testing.T) {
	user := uuid.New()
	other := uuid.New()

	if err := ensureReceiptOwner("", user); err == nil {
		t.Error("empty token should be rejected")
	}
	if err := ensureReceiptOwner("not-a-uuid", user); err == nil {
		t.Error("non-uuid token should be rejected")
	}
	// Matching token: allowed.
	if err := ensureReceiptOwner(user.String(), user); err != nil {
		t.Errorf("matching token should be allowed: %v", err)
	}
	// Another user's token: rejected — a leaked receipt must not be claimable.
	if err := ensureReceiptOwner(other.String(), user); err == nil {
		t.Error("a receipt owned by another user must be rejected")
	}
}

func TestIntervalPtrAndCurrency(t *testing.T) {
	if intervalPtr("") != nil {
		t.Error("empty interval should map to nil")
	}
	if got := intervalPtr("year"); got == nil || *got != "year" {
		t.Errorf("interval pointer = %v", got)
	}
	if got := normaliseCurrency(""); got != "eur" {
		t.Errorf("empty currency = %q, want eur", got)
	}
	if got := normaliseCurrency("USD"); got != "usd" {
		t.Errorf("currency = %q, want usd", got)
	}
}

func TestGroupPtr(t *testing.T) {
	if groupPtr(uuid.Nil) != nil {
		t.Error("uuid.Nil should map to a nil group pointer")
	}
	id := uuid.New()
	if got := groupPtr(id); got == nil || *got != id {
		t.Errorf("group pointer = %v", got)
	}
}
