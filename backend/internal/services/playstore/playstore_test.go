package playstore

import (
	"encoding/base64"
	"encoding/json"
	"testing"
	"time"
)

func TestIsLive(t *testing.T) {
	future := time.Now().Add(24 * time.Hour)
	past := time.Now().Add(-24 * time.Hour)

	cases := []struct {
		name   string
		state  string
		expiry time.Time
		live   bool
	}{
		{"active in period", StateActive, future, true},
		{"canceled but still in period", StateCanceled, future, true},
		{"in grace period", StateInGracePeriod, future, true},
		{"active but expired", StateActive, past, false},
		{"on hold", StateOnHold, future, false},
		{"paused", StatePaused, future, false},
		{"expired", StateExpired, past, false},
		{"pending", StatePending, future, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			sub := &Subscription{State: tc.state, ExpiryTime: tc.expiry}
			if got := sub.IsLive(); got != tc.live {
				t.Errorf("IsLive() = %v, want %v", got, tc.live)
			}
		})
	}
}

// parseRaw decodes an API-shaped JSON body into the internal struct, the same
// path GetSubscription's response takes.
func parseRaw(t *testing.T, body string) *subscriptionPurchaseV2 {
	t.Helper()
	var raw subscriptionPurchaseV2
	if err := json.Unmarshal([]byte(body), &raw); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	return &raw
}

func TestFlatten(t *testing.T) {
	raw := parseRaw(t, `{
		"subscriptionState": "SUBSCRIPTION_STATE_ACTIVE",
		"linkedPurchaseToken": "old-token",
		"externalAccountIdentifiers": {"obfuscatedExternalAccountId": "user-uuid"},
		"lineItems": [{
			"productId": "premium",
			"expiryTime": "2030-01-02T15:04:05Z",
			"offerDetails": {"basePlanId": "premium-yearly"},
			"autoRenewingPlan": {"autoRenewEnabled": true}
		}]
	}`)

	sub := flatten(raw)
	if sub.ProductID != "premium" || sub.BasePlanID != "premium-yearly" {
		t.Errorf("product/base plan = %q/%q", sub.ProductID, sub.BasePlanID)
	}
	if !sub.AutoRenewing {
		t.Error("expected auto-renewing")
	}
	if sub.AccountToken != "user-uuid" {
		t.Errorf("account token = %q", sub.AccountToken)
	}
	if sub.LinkedPurchaseToken != "old-token" {
		t.Errorf("linked token = %q", sub.LinkedPurchaseToken)
	}
	if sub.ExpiryTime.Year() != 2030 {
		t.Errorf("expiry = %v", sub.ExpiryTime)
	}
}

func TestFlattenAutoRenewOff(t *testing.T) {
	// No autoRenewingPlan block means renewal is off.
	raw := parseRaw(t, `{
		"subscriptionState": "SUBSCRIPTION_STATE_CANCELED",
		"lineItems": [{"productId": "premium", "offerDetails": {"basePlanId": "premium-monthly"}}]
	}`)
	sub := flatten(raw)
	if sub.AutoRenewing {
		t.Error("expected auto-renew off when no auto-renewing plan is present")
	}
}

func TestDecodeNotification(t *testing.T) {
	inner := map[string]any{
		"packageName":     "dev.mohamad.mitlist",
		"eventTimeMillis": "1700000000000",
		"subscriptionNotification": map[string]any{
			"version":          "1.0",
			"notificationType": NotificationRenewed,
			"purchaseToken":    "token-abc",
			"subscriptionId":   "premium",
		},
	}
	innerJSON, _ := json.Marshal(inner)
	push := map[string]any{
		"message": map[string]any{
			"data":      base64.StdEncoding.EncodeToString(innerJSON),
			"messageId": "msg-42",
		},
		"subscription": "projects/x/subscriptions/y",
	}
	body, _ := json.Marshal(push)

	notif, msgID, err := DecodeNotification(body)
	if err != nil {
		t.Fatalf("DecodeNotification: %v", err)
	}
	if msgID != "msg-42" {
		t.Errorf("message id = %q", msgID)
	}
	if notif.SubscriptionNotification == nil {
		t.Fatal("expected a subscription notification")
	}
	if notif.SubscriptionNotification.PurchaseToken != "token-abc" {
		t.Errorf("purchase token = %q", notif.SubscriptionNotification.PurchaseToken)
	}
	if notif.SubscriptionNotification.NotificationType != NotificationRenewed {
		t.Errorf("notification type = %d", notif.SubscriptionNotification.NotificationType)
	}
}

func TestDecodeNotification_TestPing(t *testing.T) {
	inner := map[string]any{
		"packageName":      "dev.mohamad.mitlist",
		"testNotification": map[string]any{"version": "1.0"},
	}
	innerJSON, _ := json.Marshal(inner)
	push := map[string]any{
		"message": map[string]any{"data": base64.StdEncoding.EncodeToString(innerJSON), "messageId": "m"},
	}
	body, _ := json.Marshal(push)

	notif, _, err := DecodeNotification(body)
	if err != nil {
		t.Fatalf("DecodeNotification: %v", err)
	}
	if notif.SubscriptionNotification != nil {
		t.Error("a test ping should carry no subscription notification")
	}
	if notif.TestNotification == nil {
		t.Error("expected the test notification block")
	}
}

func TestDisabledClient(t *testing.T) {
	c := New(Config{}) // no service account
	if c.Enabled() {
		t.Fatal("client with no service account should be disabled")
	}
}

func TestValidateSubscription(t *testing.T) {
	c := &Client{subscriptionID: "premium", basePlanMonthly: "premium-monthly", basePlanYearly: "premium-yearly"}
	if err := c.ValidateSubscription(&Subscription{ProductID: "premium", BasePlanID: "premium-monthly"}); err != nil {
		t.Fatalf("configured product rejected: %v", err)
	}
	if err := c.ValidateSubscription(&Subscription{ProductID: "coins", BasePlanID: "premium-monthly"}); err == nil {
		t.Fatal("unknown subscription product should be rejected")
	}
	if err := c.ValidateSubscription(&Subscription{ProductID: "premium", BasePlanID: "unknown"}); err == nil {
		t.Fatal("unknown base plan should be rejected")
	}
}
