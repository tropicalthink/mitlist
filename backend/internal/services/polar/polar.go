// Package polar is a minimal client for the Polar billing API, covering the
// calls mitlist makes server-side: creating a checkout session and opening the
// customer portal. Webhook delivery is handled elsewhere; this package only
// speaks outbound.
//
// Billing is opt-in. When POLAR_ACCESS_TOKEN is empty the client reports itself
// disabled and every call fails fast rather than reaching the network.
package polar

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// DefaultBaseURL is Polar's production API. The sandbox lives at
// https://sandbox-api.polar.sh and is selected by setting POLAR_BASE_URL.
const DefaultBaseURL = "https://api.polar.sh"

// ErrDisabled is returned by every call when no access token is configured.
var ErrDisabled = errors.New("polar: billing is not configured")

// Client talks to the Polar REST API.
type Client struct {
	baseURL     string
	accessToken string
	http        *http.Client
}

// New builds a client. An empty accessToken yields a disabled client whose
// calls all return ErrDisabled.
func New(baseURL, accessToken string) *Client {
	if baseURL == "" {
		baseURL = DefaultBaseURL
	}
	return &Client{
		baseURL:     strings.TrimRight(baseURL, "/"),
		accessToken: accessToken,
		http:        &http.Client{Timeout: 15 * time.Second},
	}
}

// Enabled reports whether the client has credentials to call Polar.
func (c *Client) Enabled() bool {
	return c != nil && c.accessToken != ""
}

// CheckoutRequest describes a checkout session to create.
type CheckoutRequest struct {
	// ProductID is the Polar product being purchased.
	ProductID string
	// ExternalCustomerID ties the resulting customer to a mitlist user, so
	// webhooks can be resolved back to an account without an email match.
	ExternalCustomerID string
	CustomerEmail      string
	SuccessURL         string
	// Metadata is copied onto the checkout, order, and subscription. mitlist
	// always stamps app=mitlist here so a shared Polar organization can route
	// events to the right application.
	Metadata map[string]string
	// DiscountID auto-applies a specific discount without the customer typing
	// anything. Optional; leave empty for no preset discount.
	DiscountID string
	// AllowDiscountCodes lets the customer enter a promo code on the hosted
	// checkout page. Enabled by default at the service layer.
	AllowDiscountCodes bool
}

// CheckoutSession is the subset of Polar's checkout response mitlist needs.
type CheckoutSession struct {
	ID         string    `json:"id"`
	URL        string    `json:"url"`
	Status     string    `json:"status"`
	ExpiresAt  time.Time `json:"expires_at"`
	ClientID   string    `json:"client_secret"`
	CustomerID *string   `json:"customer_id"`
}

// CreateCheckout opens a hosted checkout session and returns the URL to send
// the customer to.
func (c *Client) CreateCheckout(ctx context.Context, req CheckoutRequest) (*CheckoutSession, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}
	if req.ProductID == "" {
		return nil, errors.New("polar: product id is required")
	}

	body := map[string]any{
		"products":             []string{req.ProductID},
		"allow_discount_codes": req.AllowDiscountCodes,
	}
	if req.ExternalCustomerID != "" {
		body["external_customer_id"] = req.ExternalCustomerID
	}
	if req.CustomerEmail != "" {
		body["customer_email"] = req.CustomerEmail
	}
	if req.SuccessURL != "" {
		body["success_url"] = req.SuccessURL
	}
	if req.DiscountID != "" {
		body["discount_id"] = req.DiscountID
	}
	if len(req.Metadata) > 0 {
		body["metadata"] = req.Metadata
		// Copy the same tags onto the customer record so a shared organization
		// stays attributable per app.
		body["customer_metadata"] = req.Metadata
	}

	var out CheckoutSession
	if err := c.do(ctx, http.MethodPost, "/v1/checkouts/", body, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// CustomerSession is a short-lived token for the Polar customer portal, where
// a subscriber manages payment methods, invoices, and cancellation.
type CustomerSession struct {
	Token             string    `json:"token"`
	CustomerPortalURL string    `json:"customer_portal_url"`
	ExpiresAt         time.Time `json:"expires_at"`
}

// CreateCustomerSession opens a customer portal session for a mitlist user,
// addressed by the external ID stamped at checkout.
func (c *Client) CreateCustomerSession(ctx context.Context, externalCustomerID string) (*CustomerSession, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}
	if externalCustomerID == "" {
		return nil, errors.New("polar: external customer id is required")
	}

	body := map[string]any{"external_customer_id": externalCustomerID}
	var out CustomerSession
	if err := c.do(ctx, http.MethodPost, "/v1/customer-sessions/", body, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// ProductPrice is one price attached to a product. Polar models several kinds
// (fixed, free, custom, seat-based); only AmountTypeFixed carries a usable
// number in PriceAmount.
type ProductPrice struct {
	ID         string `json:"id"`
	AmountType string `json:"amount_type"`
	// PriceAmount is in minor units (cents), and is meaningless unless
	// AmountType is AmountTypeFixed.
	PriceAmount       int     `json:"price_amount"`
	PriceCurrency     string  `json:"price_currency"`
	IsArchived        bool    `json:"is_archived"`
	Type              string  `json:"type"`
	RecurringInterval *string `json:"recurring_interval"`
}

// AmountTypeFixed is the only amount type mitlist sells.
const AmountTypeFixed = "fixed"

// Product is the subset of a Polar product mitlist reads, which is only ever
// to display what a plan costs before the customer commits.
type Product struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	IsRecurring bool   `json:"is_recurring"`
	// RecurringInterval is "month" or "year" for subscription products.
	RecurringInterval *string        `json:"recurring_interval"`
	Prices            []ProductPrice `json:"prices"`
	IsArchived        bool           `json:"is_archived"`
}

// ListedPrice returns the product's sellable fixed price — the one a customer
// would actually be charged — or nil when the product has none (archived,
// free, or priced in a model mitlist does not sell).
func (p *Product) ListedPrice() *ProductPrice {
	if p == nil {
		return nil
	}
	for i := range p.Prices {
		price := &p.Prices[i]
		if price.IsArchived || price.AmountType != AmountTypeFixed {
			continue
		}
		return price
	}
	return nil
}

// GetProduct fetches one product, used to show the customer what a plan costs
// before sending them to checkout.
func (c *Client) GetProduct(ctx context.Context, productID string) (*Product, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}
	if productID == "" {
		return nil, errors.New("polar: product id is required")
	}

	var out Product
	if err := c.do(ctx, http.MethodGet, "/v1/products/"+productID, nil, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// APIError is a non-2xx response from Polar. Body is kept verbatim because it
// is the only place Polar says *why* a call was refused, and that reason is
// what turns an opaque 500 in mitlist into an actionable fix.
type APIError struct {
	StatusCode int
	Body       string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("polar: api returned %d: %s", e.StatusCode, e.Body)
}

// Unauthorized reports whether Polar rejected the access token itself, or the
// token's scopes. A token with products:read but not checkouts:write reads the
// catalog happily and then fails here — so prices render while checkout does
// not, which is otherwise a baffling pair of symptoms.
func (e *APIError) Unauthorized() bool {
	return e != nil && (e.StatusCode == http.StatusUnauthorized || e.StatusCode == http.StatusForbidden)
}

// Rejected reports whether Polar refused the request body rather than the
// caller: a field it would not accept, or an object that does not exist.
func (e *APIError) Rejected() bool {
	return e != nil && (e.StatusCode == http.StatusUnprocessableEntity ||
		e.StatusCode == http.StatusBadRequest ||
		e.StatusCode == http.StatusNotFound)
}

// Mentions reports whether Polar's error body names the given request field.
// Polar answers a rejected body with FastAPI's validation shape, whose "loc"
// entries carry the offending field name, so a plain substring match over the
// body is enough to tell "this discount is no good" from every other refusal.
func (e *APIError) Mentions(field string) bool {
	return e != nil && strings.Contains(e.Body, field)
}

func (c *Client) do(ctx context.Context, method, path string, body any, out any) error {
	var reader io.Reader
	if body != nil {
		encoded, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(encoded)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.accessToken)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

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
	if out == nil {
		return nil
	}
	return json.Unmarshal(payload, out)
}
