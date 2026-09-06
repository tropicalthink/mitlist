// Package playstore verifies Google Play subscription purchases. Unlike Apple's
// self-contained signed JWS, a Google purchase token is meaningless on its own:
// trust comes from calling the Play Developer API with a service-account
// credential and reading the authoritative subscription state back.
//
// That shape makes the Real-Time Developer Notifications (RTDN) endpoint safe
// even though a Pub/Sub push is not signed: a notification only carries a
// purchase token, and this package always re-fetches the true state from Google
// before changing any entitlement. A forged notification can, at most, make the
// server re-check a token it will not recognise.
//
// Google IAP is opt-in. A client built with no service account reports itself
// disabled and verifies nothing.
package playstore

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"golang.org/x/oauth2/google"
	"golang.org/x/oauth2/jwt"
)

// androidPublisherScope is the single OAuth scope the Play Developer API needs
// to read subscription state.
const androidPublisherScope = "https://www.googleapis.com/auth/androidpublisher"

// apiBaseURL is the Play Developer API root.
const apiBaseURL = "https://androidpublisher.googleapis.com"

// ErrDisabled is returned by every call when no service account is configured.
var ErrDisabled = errors.New("playstore: Google IAP is not configured")

// Subscription states as reported by purchases.subscriptionsv2. Only Active and
// InGracePeriod grant entitlement; the rest are various stages of lapse.
const (
	StateActive        = "SUBSCRIPTION_STATE_ACTIVE"
	StateCanceled      = "SUBSCRIPTION_STATE_CANCELED"
	StateInGracePeriod = "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"
	StateOnHold        = "SUBSCRIPTION_STATE_ON_HOLD"
	StatePaused        = "SUBSCRIPTION_STATE_PAUSED"
	StateExpired       = "SUBSCRIPTION_STATE_EXPIRED"
	StatePending       = "SUBSCRIPTION_STATE_PENDING"
)

// RTDN subscription notification type codes.
// https://developer.android.com/google/play/billing/rtdn-reference
const (
	NotificationRecovered            = 1
	NotificationRenewed              = 2
	NotificationCanceled             = 3
	NotificationPurchased            = 4
	NotificationOnHold               = 5
	NotificationInGracePeriod        = 6
	NotificationRestarted            = 7
	NotificationPriceChangeConfirmed = 8
	NotificationDeferred             = 9
	NotificationPaused               = 10
	NotificationPauseScheduleChanged = 11
	NotificationRevoked              = 12
	NotificationExpired              = 13
)

// Config is what Google IAP verification needs.
type Config struct {
	// PackageName is the app's Android package; part of every API path.
	PackageName string
	// ServiceAccountJSON is the downloaded service-account key that authorises
	// the Play Developer API.
	ServiceAccountJSON string
	SubscriptionID     string
	BasePlanMonthly    string
	BasePlanYearly     string
}

// Client calls the Play Developer API on behalf of the configured service
// account.
type Client struct {
	packageName     string
	subscriptionID  string
	basePlanMonthly string
	basePlanYearly  string
	jwtConfig       *jwt.Config
	http            *http.Client
}

// New builds a client. An empty ServiceAccountJSON (or one that does not parse)
// yields a disabled client whose calls all return ErrDisabled — billing is
// opt-in, and a malformed key must not crash startup.
func New(cfg Config) *Client {
	c := &Client{
		packageName:     cfg.PackageName,
		subscriptionID:  cfg.SubscriptionID,
		basePlanMonthly: cfg.BasePlanMonthly,
		basePlanYearly:  cfg.BasePlanYearly,
		http:            &http.Client{Timeout: 15 * time.Second},
	}
	if cfg.ServiceAccountJSON == "" || cfg.PackageName == "" {
		return c
	}
	jwtCfg, err := google.JWTConfigFromJSON([]byte(cfg.ServiceAccountJSON), androidPublisherScope)
	if err != nil {
		// Leave the client disabled; the config layer already logs Google IAP as
		// off when credentials are missing, and a bad key should degrade to that.
		return c
	}
	c.jwtConfig = jwtCfg
	return c
}

// Enabled reports whether the client can call Google.
func (c *Client) Enabled() bool {
	return c != nil && c.jwtConfig != nil && c.packageName != "" && c.subscriptionID != "" && c.basePlanMonthly != "" && c.basePlanYearly != ""
}

func (c *Client) PackageName() string    { return c.packageName }
func (c *Client) SubscriptionID() string { return c.subscriptionID }

func (c *Client) ValidateSubscription(sub *Subscription) error {
	if sub == nil || sub.ProductID != c.subscriptionID {
		return fmt.Errorf("playstore: product id %q is not configured", productID(sub))
	}
	if sub.BasePlanID != c.basePlanMonthly && sub.BasePlanID != c.basePlanYearly {
		return fmt.Errorf("playstore: base plan %q is not configured", sub.BasePlanID)
	}
	return nil
}

func productID(sub *Subscription) string {
	if sub == nil {
		return ""
	}
	return sub.ProductID
}

// Subscription is the subset of a SubscriptionPurchaseV2 mitlist reads, flattened
// to the one line item a mitlist subscription ever has.
//
// https://developer.android.com/google/play/billing/subscriptions
type Subscription struct {
	// State is one of the StateXxx constants; IsLive derives entitlement from it.
	State string
	// ProductID and BasePlanID identify what was bought; BasePlanID maps to a
	// billing interval via config.
	ProductID  string
	BasePlanID string
	// ExpiryTime is when the current billing period ends.
	ExpiryTime time.Time
	// AutoRenewing is false once the user has turned off renewal; the sub still
	// grants entitlement until ExpiryTime, so it maps to cancel-at-period-end.
	AutoRenewing bool
	// AccountToken is the obfuscatedExternalAccountId the app stamped at purchase
	// — the mitlist user id — so a purchase resolves to an account server-side.
	AccountToken string
	// LinkedPurchaseToken points at the previous token when an upgrade/downgrade
	// replaced it; the old token should be treated as superseded.
	LinkedPurchaseToken string
}

// IsLive reports whether the subscription currently grants entitlement.
//
// CANCELED counts as live: Google reports that state the moment the user turns
// off auto-renew, but access continues until ExpiryTime. IN_GRACE_PERIOD also
// keeps access while Google retries payment.
func (s *Subscription) IsLive() bool {
	switch s.State {
	case StateActive, StateCanceled, StateInGracePeriod:
		return s.ExpiryTime.IsZero() || s.ExpiryTime.After(time.Now())
	default:
		return false
	}
}

// subscriptionPurchaseV2 is the raw API response, decoded only as far as mitlist
// needs. https://developer.android.com/google/play/billing/subscriptions
type subscriptionPurchaseV2 struct {
	SubscriptionState          string `json:"subscriptionState"`
	LatestOrderID              string `json:"latestOrderId"`
	LinkedPurchaseToken        string `json:"linkedPurchaseToken"`
	ExternalAccountIdentifiers struct {
		ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	} `json:"externalAccountIdentifiers"`
	LineItems []struct {
		ProductID    string `json:"productId"`
		ExpiryTime   string `json:"expiryTime"`
		OfferDetails struct {
			BasePlanID string `json:"basePlanId"`
			OfferID    string `json:"offerId"`
		} `json:"offerDetails"`
		// AutoRenewingPlan is present (and non-empty) while renewal is on.
		AutoRenewingPlan *struct {
			AutoRenewEnabled bool `json:"autoRenewEnabled"`
		} `json:"autoRenewingPlan"`
	} `json:"lineItems"`
}

// GetSubscription fetches the authoritative state of one purchase token. This is
// the trust boundary for Google IAP: nothing downstream acts on a token until
// this call has confirmed it against Google.
func (c *Client) GetSubscription(ctx context.Context, purchaseToken string) (*Subscription, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}
	if purchaseToken == "" {
		return nil, errors.New("playstore: purchase token is required")
	}

	path := fmt.Sprintf(
		"%s/androidpublisher/v3/applications/%s/purchases/subscriptionsv2/tokens/%s",
		apiBaseURL, url.PathEscape(c.packageName), url.PathEscape(purchaseToken),
	)

	var raw subscriptionPurchaseV2
	if err := c.get(ctx, path, &raw); err != nil {
		return nil, err
	}
	sub := flatten(&raw)
	if err := c.ValidateSubscription(sub); err != nil {
		return nil, err
	}
	return sub, nil
}

// flatten reduces the API response to the single line item mitlist sells. A
// mitlist subscription is one base plan, so the first line item is the one.
func flatten(raw *subscriptionPurchaseV2) *Subscription {
	sub := &Subscription{
		State:               raw.SubscriptionState,
		AccountToken:        raw.ExternalAccountIdentifiers.ObfuscatedExternalAccountID,
		LinkedPurchaseToken: raw.LinkedPurchaseToken,
	}
	if len(raw.LineItems) > 0 {
		item := raw.LineItems[0]
		sub.ProductID = item.ProductID
		sub.BasePlanID = item.OfferDetails.BasePlanID
		sub.AutoRenewing = item.AutoRenewingPlan != nil && item.AutoRenewingPlan.AutoRenewEnabled
		if item.ExpiryTime != "" {
			if t, err := time.Parse(time.RFC3339, item.ExpiryTime); err == nil {
				sub.ExpiryTime = t.UTC()
			}
		}
	}
	return sub
}

// APIError is a non-2xx response from the Play Developer API.
type APIError struct {
	StatusCode int
	Body       string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("playstore: api returned %d: %s", e.StatusCode, e.Body)
}

// get performs an authenticated GET and decodes the JSON body into out. The
// service-account token source refreshes itself, so each call carries a valid
// bearer token without any caching here.
func (c *Client) get(ctx context.Context, fullURL string, out any) error {
	token, err := c.jwtConfig.TokenSource(ctx).Token()
	if err != nil {
		return fmt.Errorf("playstore: cannot obtain access token: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fullURL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	token.SetAuthHeader(req)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	payload, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return &APIError{StatusCode: resp.StatusCode, Body: string(payload)}
	}
	return json.Unmarshal(payload, out)
}

// DeveloperNotification is the decoded inner payload of an RTDN Pub/Sub message.
// https://developer.android.com/google/play/billing/rtdn-reference
type DeveloperNotification struct {
	PackageName              string `json:"packageName"`
	EventTimeMillis          string `json:"eventTimeMillis"`
	SubscriptionNotification *struct {
		Version          string `json:"version"`
		NotificationType int    `json:"notificationType"`
		PurchaseToken    string `json:"purchaseToken"`
		SubscriptionID   string `json:"subscriptionId"`
	} `json:"subscriptionNotification"`
	OneTimeProductNotification *struct {
		Version          string `json:"version"`
		NotificationType int    `json:"notificationType"`
		PurchaseToken    string `json:"purchaseToken"`
		SKU              string `json:"sku"`
	} `json:"oneTimeProductNotification"`
	TestNotification *struct {
		Version string `json:"version"`
	} `json:"testNotification"`
}

// One-time product purchase states as reported by purchases.products.
// https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products
const (
	ProductPurchased = 0
	ProductCanceled  = 1
	ProductPending   = 2
)

// ProductPurchase is the subset of a Play one-time product purchase mitlist
// reads. A refunded or voided purchase comes back as ProductCanceled.
type ProductPurchase struct {
	ProductID    string
	State        int
	AccountToken string
	OrderID      string
	PurchaseTime time.Time
	Acknowledged bool
}

type productPurchaseV1 struct {
	PurchaseState               int    `json:"purchaseState"`
	ConsumptionState            int    `json:"consumptionState"`
	OrderID                     string `json:"orderId"`
	PurchaseTimeMillis          string `json:"purchaseTimeMillis"`
	ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	AcknowledgementState        int    `json:"acknowledgementState"`
	ProductID                   string `json:"productId"`
}

// GetProduct fetches the authoritative state of a one-time product purchase
// token. This is the trust boundary for one-time Play purchases, exactly as
// GetSubscription is for subscriptions.
func (c *Client) GetProduct(ctx context.Context, productID, purchaseToken string) (*ProductPurchase, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}
	if productID == "" || purchaseToken == "" {
		return nil, errors.New("playstore: product id and purchase token are required")
	}

	path := fmt.Sprintf(
		"%s/androidpublisher/v3/applications/%s/purchases/products/%s/tokens/%s",
		apiBaseURL, url.PathEscape(c.packageName), url.PathEscape(productID), url.PathEscape(purchaseToken),
	)
	var raw productPurchaseV1
	if err := c.get(ctx, path, &raw); err != nil {
		return nil, err
	}
	p := &ProductPurchase{
		ProductID:    raw.ProductID,
		State:        raw.PurchaseState,
		AccountToken: raw.ObfuscatedExternalAccountID,
		OrderID:      raw.OrderID,
		Acknowledged: raw.AcknowledgementState == 1,
	}
	if p.ProductID == "" {
		p.ProductID = productID
	}
	if raw.PurchaseTimeMillis != "" {
		if ms, err := strconv.ParseInt(raw.PurchaseTimeMillis, 10, 64); err == nil {
			p.PurchaseTime = time.UnixMilli(ms).UTC()
		}
	}
	return p, nil
}

// pubSubPush is the envelope Google Pub/Sub posts to a push endpoint. The real
// notification is base64 inside message.data.
type pubSubPush struct {
	Message struct {
		Data      string `json:"data"`
		MessageID string `json:"messageId"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

// DecodeNotification unwraps a Pub/Sub push body into the developer
// notification and the Pub/Sub message id (used for idempotency). It performs no
// trust check — callers must re-fetch the token via GetSubscription before
// acting, which is where authenticity is established.
func DecodeNotification(body []byte) (*DeveloperNotification, string, error) {
	var push pubSubPush
	if err := json.Unmarshal(body, &push); err != nil {
		return nil, "", fmt.Errorf("playstore: malformed pub/sub envelope: %w", err)
	}
	decoded, err := base64.StdEncoding.DecodeString(push.Message.Data)
	if err != nil {
		return nil, "", fmt.Errorf("playstore: message data is not base64: %w", err)
	}
	var notif DeveloperNotification
	if err := json.Unmarshal(decoded, &notif); err != nil {
		return nil, "", fmt.Errorf("playstore: malformed developer notification: %w", err)
	}
	return &notif, push.Message.MessageID, nil
}
