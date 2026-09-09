package services

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services/polar"
)

// fakeUserRepo answers the single lookup StartCheckout makes — the buyer's
// email, which Polar prefills on the hosted page.
type fakeUserRepo struct {
	repositories.UserRepo
	user *models.User
}

func (f *fakeUserRepo) GetByID(context.Context, uuid.UUID) (*models.User, error) {
	return f.user, nil
}

// polarStub stands in for Polar's checkout endpoint, recording every request
// body it is sent so a test can assert on what mitlist actually asked for.
type polarStub struct {
	bodies  []map[string]any
	respond func(attempt int, w http.ResponseWriter)
}

func newPolarStub(t *testing.T, respond func(attempt int, w http.ResponseWriter)) (*polarStub, *polar.Client) {
	t.Helper()
	stub := &polarStub{respond: respond}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		stub.bodies = append(stub.bodies, body)
		w.Header().Set("Content-Type", "application/json")
		stub.respond(len(stub.bodies), w)
	}))
	t.Cleanup(srv.Close)
	return stub, polar.New(srv.URL, "polar_oat_test")
}

func checkoutOK(w http.ResponseWriter) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"id":"co_1","url":"https://buy.polar.sh/co_1","status":"open"}`))
}

func newCheckoutService(client *polar.Client, cfg BillingConfig) *BillingService {
	return &BillingService{
		userRepo: &fakeUserRepo{user: &models.User{ID: uuid.New(), Email: "buyer@example.com"}},
		client:   client,
		cfg:      cfg,
	}
}

// A promo *code* pasted into POLAR_DEFAULT_DISCOUNT_ID would be refused by
// Polar on every checkout, taking every sale down with it. Selling at full
// price beats selling nothing.
func TestStartCheckoutIgnoresNonUUIDDiscount(t *testing.T) {
	stub, client := newPolarStub(t, func(_ int, w http.ResponseWriter) { checkoutOK(w) })
	svc := newCheckoutService(client, BillingConfig{
		ProductIDMonthly:  uuid.NewString(),
		DefaultDiscountID: "LAUNCH50",
	})

	url, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly})
	if err != nil {
		t.Fatalf("checkout must survive a malformed discount id: %v", err)
	}
	if url != "https://buy.polar.sh/co_1" {
		t.Fatalf("unexpected checkout url %q", url)
	}
	if len(stub.bodies) != 1 {
		t.Fatalf("expected one call to Polar, got %d", len(stub.bodies))
	}
	if _, ok := stub.bodies[0]["discount_id"]; ok {
		t.Fatal("a non-UUID discount must never reach Polar")
	}
}

// A discount that is a valid UUID but has expired or been deleted only fails
// at Polar. The sale still has to go through.
func TestStartCheckoutRetriesWithoutRejectedDiscount(t *testing.T) {
	discount := uuid.NewString()
	stub, client := newPolarStub(t, func(attempt int, w http.ResponseWriter) {
		if attempt == 1 {
			w.WriteHeader(http.StatusUnprocessableEntity)
			_, _ = w.Write([]byte(`{"detail":[{"loc":["body","discount_id"],"msg":"Discount does not exist."}]}`))
			return
		}
		checkoutOK(w)
	})
	svc := newCheckoutService(client, BillingConfig{
		ProductIDMonthly:  uuid.NewString(),
		DefaultDiscountID: discount,
	})

	if _, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly}); err != nil {
		t.Fatalf("a rejected discount must not fail the checkout: %v", err)
	}
	if len(stub.bodies) != 2 {
		t.Fatalf("expected a retry without the discount, got %d call(s)", len(stub.bodies))
	}
	if stub.bodies[0]["discount_id"] != discount {
		t.Fatalf("first attempt should carry the discount, got %v", stub.bodies[0]["discount_id"])
	}
	if _, ok := stub.bodies[1]["discount_id"]; ok {
		t.Fatal("the retry must drop the discount")
	}
}

// An access token scoped to products:read but not checkouts:write renders
// prices happily and then fails only here. The returned error has to carry
// Polar's own words, or the cause is invisible behind a bare 500.
func TestStartCheckoutSurfacesPolarRefusal(t *testing.T) {
	_, client := newPolarStub(t, func(_ int, w http.ResponseWriter) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"detail":"Missing required scope: checkouts:write"}`))
	})
	productID := uuid.NewString()
	svc := newCheckoutService(client, BillingConfig{ProductIDMonthly: productID})

	_, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly})
	if err == nil {
		t.Fatal("expected the refusal to surface as an error")
	}
	var apiErr *polar.APIError
	if !errors.As(err, &apiErr) || !apiErr.Unauthorized() {
		t.Fatalf("error should unwrap to an unauthorized Polar APIError, got %v", err)
	}
	if !strings.Contains(err.Error(), "checkouts:write") || !strings.Contains(err.Error(), productID) {
		t.Fatalf("error must name Polar's reason and the product: %v", err)
	}
}

// Polar prices a draft product normally and then refuses every checkout for
// it, which is what production did for weeks. The refusal must surface with
// Polar's wording and must not be mistaken for a discount problem.
func TestStartCheckoutSurfacesDraftProduct(t *testing.T) {
	stub, client := newPolarStub(t, func(_ int, w http.ResponseWriter) {
		w.WriteHeader(http.StatusUnprocessableEntity)
		_, _ = w.Write([]byte(`{"detail":[{"type":"value_error","loc":["body","products",0],"msg":"Product is a draft.","input":"p"}]}`))
	})
	productID := uuid.NewString()
	svc := newCheckoutService(client, BillingConfig{
		ProductIDMonthly:  productID,
		DefaultDiscountID: uuid.NewString(),
	})

	_, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly})
	if err == nil {
		t.Fatal("expected the refusal to surface as an error")
	}
	var apiErr *polar.APIError
	if !errors.As(err, &apiErr) || !apiErr.Rejected() || !apiErr.Mentions("draft") {
		t.Fatalf("error should unwrap to Polar's draft refusal, got %v", err)
	}
	if !strings.Contains(err.Error(), "Product is a draft") || !strings.Contains(err.Error(), productID) {
		t.Fatalf("error must name Polar's reason and the product: %v", err)
	}
	if len(stub.bodies) != 1 {
		t.Fatalf("a draft refusal is not a discount problem and must not be retried, got %d call(s)", len(stub.bodies))
	}
}

// A 403 over the token must not be mistaken for a discount problem and retried.
func TestStartCheckoutDoesNotRetryOnTokenRefusal(t *testing.T) {
	stub, client := newPolarStub(t, func(_ int, w http.ResponseWriter) {
		w.WriteHeader(http.StatusForbidden)
		_, _ = w.Write([]byte(`{"detail":"Missing required scope: checkouts:write"}`))
	})
	svc := newCheckoutService(client, BillingConfig{
		ProductIDMonthly:  uuid.NewString(),
		DefaultDiscountID: uuid.NewString(),
	})

	if _, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly}); err == nil {
		t.Fatal("expected an error")
	}
	if len(stub.bodies) != 1 {
		t.Fatalf("a token refusal must not be retried, got %d call(s)", len(stub.bodies))
	}
}

// Polar validates the prefilled customer email down to whether its domain can
// receive mail — stricter than mitlist's own sign-up check — and answers 422
// for an address like ll@ll.com. That must not sink the sale: the hosted page
// asks for an email anyway, and the external customer id still links the
// purchase to the account.
func TestStartCheckoutRetriesWithoutRejectedEmail(t *testing.T) {
	stub, client := newPolarStub(t, func(attempt int, w http.ResponseWriter) {
		if attempt == 1 {
			w.WriteHeader(http.StatusUnprocessableEntity)
			_, _ = w.Write([]byte(`{"detail":[{"type":"value_error","loc":["body","function-after[is_complete_configuration(), CheckoutProductsCreate]","customer_email"],"msg":"ll@ll.com is not a valid email address: The domain name ll.com does not accept email.","input":"ll@ll.com"},{"type":"missing","loc":["body","function-after[is_complete_configuration(), CheckoutPriceCreate]","product_price_id"],"msg":"Field required"}]}`))
			return
		}
		checkoutOK(w)
	})
	svc := newCheckoutService(client, BillingConfig{ProductIDMonthly: uuid.NewString()})

	url, err := svc.StartCheckout(context.Background(), uuid.New(), CheckoutInput{Interval: PlanMonthly})
	if err != nil {
		t.Fatalf("a rejected customer email must not fail the checkout: %v", err)
	}
	if url != "https://buy.polar.sh/co_1" {
		t.Fatalf("unexpected checkout url %q", url)
	}
	if len(stub.bodies) != 2 {
		t.Fatalf("expected a retry without the email, got %d call(s)", len(stub.bodies))
	}
	if stub.bodies[0]["customer_email"] != "buyer@example.com" {
		t.Fatalf("first attempt should prefill the email, got %v", stub.bodies[0]["customer_email"])
	}
	if _, ok := stub.bodies[1]["customer_email"]; ok {
		t.Fatal("the retry must drop the email prefill")
	}
	if stub.bodies[1]["external_customer_id"] == nil {
		t.Fatal("the retry must keep the external customer id so the purchase still maps to the account")
	}
}
