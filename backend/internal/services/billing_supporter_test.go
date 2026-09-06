package services

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services/appstore"
	"github.com/mitlist-app/mitlist/internal/services/playstore"
)

// fakeBillingRepo records supporter purchases and webhook ids in memory. Only
// the methods the supporter path touches are implemented; the rest fail loudly
// so a test that wanders into subscription territory is noticed.
type fakeBillingRepo struct {
	purchases map[string]*models.SupporterPurchase // keyed provider:order id
	events    map[string]bool
}

func newFakeBillingRepo() *fakeBillingRepo {
	return &fakeBillingRepo{purchases: map[string]*models.SupporterPurchase{}, events: map[string]bool{}}
}

func (f *fakeBillingRepo) UpsertSupporterPurchase(_ context.Context, p *models.SupporterPurchase) (*models.SupporterPurchase, error) {
	key := p.Provider + ":" + p.ProviderOrderID
	if existing, ok := f.purchases[key]; ok && existing.ProviderModifiedAt != nil && p.ProviderModifiedAt != nil &&
		p.ProviderModifiedAt.Before(*existing.ProviderModifiedAt) {
		return existing, nil
	}
	cp := *p
	if cp.ID == uuid.Nil {
		cp.ID = uuid.New()
	}
	f.purchases[key] = &cp
	return &cp, nil
}

func (f *fakeBillingRepo) GetSupporterPurchaseByProviderID(_ context.Context, provider, id string) (*models.SupporterPurchase, error) {
	return f.purchases[provider+":"+id], nil
}

func (f *fakeBillingRepo) GetPaidSupporterPurchaseForUser(_ context.Context, userID uuid.UUID) (*models.SupporterPurchase, error) {
	for _, p := range f.purchases {
		if p.UserID == userID && p.Status == models.SupporterStatusPaid {
			return p, nil
		}
	}
	return nil, nil
}

func (f *fakeBillingRepo) ListSupporterUserIDs(_ context.Context, ids []uuid.UUID) (map[uuid.UUID]bool, error) {
	out := map[uuid.UUID]bool{}
	for _, id := range ids {
		if p, _ := f.GetPaidSupporterPurchaseForUser(context.Background(), id); p != nil {
			out[id] = true
		}
	}
	return out, nil
}

func (f *fakeBillingRepo) MarkWebhookEventProcessed(_ context.Context, id, _, _ string) (bool, error) {
	if f.events[id] {
		return false, nil
	}
	f.events[id] = true
	return true, nil
}

var errNotImplemented = errors.New("not implemented in fake")

func (f *fakeBillingRepo) UpsertSubscription(context.Context, *models.BillingSubscription) (*models.BillingSubscription, error) {
	return nil, errNotImplemented
}
func (f *fakeBillingRepo) SupersedeSubscription(context.Context, string, string, time.Time) error {
	return errNotImplemented
}
func (f *fakeBillingRepo) GetSubscriptionByProviderID(context.Context, string, string) (*models.BillingSubscription, error) {
	return nil, errNotImplemented
}
func (f *fakeBillingRepo) ListSubscriptionsByUser(context.Context, uuid.UUID) ([]models.BillingSubscription, error) {
	return nil, errNotImplemented
}
func (f *fakeBillingRepo) GetLiveSubscriptionForUser(context.Context, uuid.UUID) (*models.BillingSubscription, error) {
	return nil, errNotImplemented
}
func (f *fakeBillingRepo) SetPrimaryGroupForUser(context.Context, uuid.UUID, uuid.UUID) (*models.BillingSubscription, error) {
	return nil, errNotImplemented
}
func (f *fakeBillingRepo) GetGroupCoverage(context.Context, uuid.UUID) (bool, *string, error) {
	return false, nil, errNotImplemented
}
func (f *fakeBillingRepo) CountGroupMembers(context.Context, uuid.UUID) (int, error) {
	return 0, errNotImplemented
}
func (f *fakeBillingRepo) DeleteWebhookEventsBefore(context.Context, time.Time) (int64, error) {
	return 0, errNotImplemented
}

func polarOrderPayload(t *testing.T, eventType, orderID, productID, status string, userID uuid.UUID, modified time.Time) []byte {
	t.Helper()
	ext := userID.String()
	payload, err := json.Marshal(map[string]any{
		"type": eventType,
		"data": map[string]any{
			"id":           orderID,
			"status":       status,
			"paid":         status == "paid",
			"total_amount": 499,
			"currency":     "eur",
			"product_id":   productID,
			"customer_id":  "cust_1",
			"modified_at":  modified.UTC().Format(time.RFC3339Nano),
			"created_at":   modified.Add(-time.Minute).UTC().Format(time.RFC3339Nano),
			"metadata":     map[string]any{"app": "mitlist", "user_id": ext, "kind": "supporter"},
			"customer":     map[string]any{"external_id": ext},
			"product":      map[string]any{"metadata": map[string]any{"app": "mitlist"}},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	return payload
}

func TestPolarOrderPaidMakesSupporter(t *testing.T) {
	repo := newFakeBillingRepo()
	svc := &BillingService{repo: repo, cfg: BillingConfig{ProductIDSupporter: "prod_supporter"}}
	user := uuid.New()
	now := time.Now()

	if err := svc.ApplyWebhookEvent(context.Background(), "wh_1",
		polarOrderPayload(t, "order.paid", "order_1", "prod_supporter", "paid", user, now)); err != nil {
		t.Fatalf("order.paid: %v", err)
	}
	if ok, _ := svc.IsSupporter(context.Background(), user); !ok {
		t.Fatal("a paid supporter order should make the user a supporter")
	}
	p := repo.purchases["polar:order_1"]
	if p.AmountCents != 499 || p.Currency != "eur" || p.PurchasedAt == nil {
		t.Fatalf("stored purchase = %+v", p)
	}

	// A redelivery is acknowledged without being applied twice.
	err := svc.ApplyWebhookEvent(context.Background(), "wh_1",
		polarOrderPayload(t, "order.paid", "order_1", "prod_supporter", "paid", user, now))
	if !errors.Is(err, ErrEventIgnored) {
		t.Fatalf("redelivery should be ignored, got %v", err)
	}

	// A refund revokes the perks.
	if err := svc.ApplyWebhookEvent(context.Background(), "wh_2",
		polarOrderPayload(t, "order.refunded", "order_1", "prod_supporter", "refunded", user, now.Add(time.Hour))); err != nil {
		t.Fatalf("order.refunded: %v", err)
	}
	if ok, _ := svc.IsSupporter(context.Background(), user); ok {
		t.Fatal("a refunded order must not leave the user a supporter")
	}
	if repo.purchases["polar:order_1"].RefundedAt == nil {
		t.Fatal("refund time should be recorded")
	}
}

func TestPolarOrderForOtherProductIgnored(t *testing.T) {
	repo := newFakeBillingRepo()
	svc := &BillingService{repo: repo, cfg: BillingConfig{ProductIDSupporter: "prod_supporter"}}
	user := uuid.New()

	// Subscription invoices arrive as orders too; they belong to the
	// subscription.* path and must not create a supporter purchase.
	err := svc.ApplyWebhookEvent(context.Background(), "wh_sub",
		polarOrderPayload(t, "order.paid", "order_sub", "prod_yearly", "paid", user, time.Now()))
	if !errors.Is(err, ErrEventIgnored) {
		t.Fatalf("expected ErrEventIgnored, got %v", err)
	}
	if len(repo.purchases) != 0 {
		t.Fatal("no purchase should be recorded for a subscription invoice")
	}

	// With no supporter product configured every order is ignored.
	svc.cfg.ProductIDSupporter = ""
	err = svc.ApplyWebhookEvent(context.Background(), "wh_x",
		polarOrderPayload(t, "order.paid", "order_2", "prod_supporter", "paid", user, time.Now()))
	if !errors.Is(err, ErrEventIgnored) {
		t.Fatalf("expected ErrEventIgnored when unconfigured, got %v", err)
	}
}

func TestPolarOrderStatusMapping(t *testing.T) {
	cases := []struct {
		order polarOrder
		want  string
	}{
		{polarOrder{Status: "paid", Paid: true}, models.SupporterStatusPaid},
		{polarOrder{Status: "refunded", Paid: true}, models.SupporterStatusRefunded},
		{polarOrder{Status: "partially_refunded", Paid: true}, models.SupporterStatusRefunded},
		{polarOrder{Status: "pending"}, models.SupporterStatusPending},
		{polarOrder{Status: "something_new", Paid: true}, models.SupporterStatusPaid},
		{polarOrder{Status: "something_new", Paid: true, RefundedAmount: 100}, models.SupporterStatusPending},
	}
	for _, c := range cases {
		if got := polarOrderStatus(c.order); got != c.want {
			t.Errorf("polarOrderStatus(%+v) = %q, want %q", c.order, got, c.want)
		}
	}
}

func TestSupporterFromAppleRevocation(t *testing.T) {
	svc := &BillingService{}
	user := uuid.New()
	purchased := time.Now().Add(-48 * time.Hour).Truncate(time.Millisecond)
	tx := &appstore.TransactionInfo{
		OriginalTransactionID: "orig-1", ProductID: "me.mitlist.supporter",
		AppAccountToken: user.String(), Type: "Non-Consumable",
		PurchaseDate: purchased.UnixMilli(),
	}
	p := svc.supporterFromApple(tx, user)
	if p.Status != models.SupporterStatusPaid || p.PurchasedAt == nil || !p.PurchasedAt.Equal(purchased) {
		t.Fatalf("fresh purchase = %+v", p)
	}
	if p.ProviderOrderID != "orig-1" || p.Provider != ProviderApple {
		t.Fatalf("purchase should be keyed on the original transaction id: %+v", p)
	}

	tx.RevocationDate = time.Now().UnixMilli()
	p = svc.supporterFromApple(tx, user)
	if p.Status != models.SupporterStatusRefunded || p.RefundedAt == nil {
		t.Fatalf("revoked purchase = %+v", p)
	}
}

func TestSupporterFromGoogleStates(t *testing.T) {
	svc := &BillingService{}
	user := uuid.New()
	at := time.Now().Truncate(time.Millisecond)
	for state, want := range map[int]string{
		playstore.ProductPurchased: models.SupporterStatusPaid,
		playstore.ProductCanceled:  models.SupporterStatusRefunded,
		playstore.ProductPending:   models.SupporterStatusPending,
		99:                         models.SupporterStatusPending,
	} {
		p := svc.supporterFromGoogle(&playstore.ProductPurchase{
			ProductID: "supporter", State: state, AccountToken: user.String(), PurchaseTime: at,
		}, "token-1", user)
		if p.Status != want {
			t.Errorf("state %d -> %q, want %q", state, p.Status, want)
		}
		if p.ProviderOrderID != "token-1" {
			t.Errorf("purchase should be keyed on the purchase token, got %q", p.ProviderOrderID)
		}
	}
}

func TestSupporterEnabledNeedsAProduct(t *testing.T) {
	svc := &BillingService{
		apple: appstore.New(appstore.Config{
			BundleID: "me.mitlist", ProductIDMonthly: "m", ProductIDYearly: "y",
		}),
	}
	if svc.SupporterEnabled() {
		t.Fatal("Apple IAP without a supporter product must not advertise the pack")
	}
	svc.cfg.AppleProductSupporter = "me.mitlist.supporter"
	if !svc.SupporterEnabled() {
		t.Fatal("a configured Apple supporter product should enable the pack")
	}
}
