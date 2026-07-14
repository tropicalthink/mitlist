package fx

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

// frankfurterJSON returns a minimal Frankfurter JSON payload for the given rate.
func frankfurterJSON(to string, rate float64) string {
	return fmt.Sprintf(`{"rates":{%q:%g}}`, to, rate)
}

// TestGetRate_HappyPath verifies that a successful provider response is returned
// and cached so a subsequent call (with the stub torn down) still returns a rate.
func TestGetRate_HappyPath(t *testing.T) {
	const from, to = "USD", "EUR"
	const wantRate = 0.92

	// Stub provider: returns a valid Frankfurter response once.
	var callCount int32
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, frankfurterJSON(to, wantRate))
	}))
	defer stub.Close()

	svc := NewRateService(NewFrankfurterProvider(stub.URL, ""), true)

	// First call — hits the stub.
	rate, available, err := svc.GetRate(context.Background(), from, to)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !available {
		t.Fatal("expected available=true")
	}
	if rate != wantRate {
		t.Fatalf("rate: got %v, want %v", rate, wantRate)
	}
	if atomic.LoadInt32(&callCount) != 1 {
		t.Fatalf("expected 1 provider call, got %d", atomic.LoadInt32(&callCount))
	}
}

// TestGetRate_CacheHit verifies that the second call uses the local cache and
// does not make a second outbound call to the provider.
func TestGetRate_CacheHit(t *testing.T) {
	const from, to = "GBP", "JPY"
	const wantRate = 197.5

	var callCount int32
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, frankfurterJSON(to, wantRate))
	}))

	svc := NewRateService(NewFrankfurterProvider(stub.URL, ""), true)

	ctx := context.Background()

	// First call — populates cache via the stub.
	_, _, _ = svc.GetRate(ctx, from, to)

	// Tear down the stub so any second outbound call would fail.
	stub.Close()

	// Second call — must come from cache.
	rate, available, err := svc.GetRate(ctx, from, to)
	if err != nil {
		t.Fatalf("unexpected error on cached call: %v", err)
	}
	if !available {
		t.Fatal("expected available=true on cache hit")
	}
	if rate != wantRate {
		t.Fatalf("cached rate: got %v, want %v", rate, wantRate)
	}
	// Provider was only called once (the cache was written after the first call).
	if atomic.LoadInt32(&callCount) != 1 {
		t.Fatalf("expected exactly 1 provider call, got %d", atomic.LoadInt32(&callCount))
	}
}

// TestGetRate_ProviderReturns500 confirms fail-soft: a 500 from the provider
// results in available=false with no error surfaced.
func TestGetRate_ProviderReturns500(t *testing.T) {
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "internal server error", http.StatusInternalServerError)
	}))
	defer stub.Close()

	svc := NewRateService(NewFrankfurterProvider(stub.URL, ""), true)

	rate, available, err := svc.GetRate(context.Background(), "USD", "EUR")
	if err != nil {
		t.Fatalf("expected nil error on provider 500, got: %v", err)
	}
	if available {
		t.Fatal("expected available=false on provider 500")
	}
	if rate != 0 {
		t.Fatalf("expected rate=0 on provider 500, got %v", rate)
	}
}

// TestGetRate_ProviderHangs confirms fail-soft: a provider that hangs past the
// client timeout results in available=false with no error surfaced.
func TestGetRate_ProviderHangs(t *testing.T) {
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Hang until the request context is cancelled.
		select {
		case <-r.Context().Done():
		case <-time.After(30 * time.Second):
		}
	}))
	defer stub.Close()

	// Use a provider with a very short timeout so the test completes quickly.
	p := &frankfurterProvider{
		baseURL: stub.URL,
		client:  &http.Client{Timeout: 100 * time.Millisecond},
	}
	svc := NewRateService(p, true)

	rate, available, err := svc.GetRate(context.Background(), "USD", "CHF")
	if err != nil {
		t.Fatalf("expected nil error on timeout, got: %v", err)
	}
	if available {
		t.Fatal("expected available=false on timeout")
	}
	if rate != 0 {
		t.Fatalf("expected rate=0 on timeout, got %v", rate)
	}
}

// TestGetRate_ProviderGarbage confirms fail-soft: an unparseable body results
// in available=false.
func TestGetRate_ProviderGarbage(t *testing.T) {
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `this is not json {{{{`)
	}))
	defer stub.Close()

	svc := NewRateService(NewFrankfurterProvider(stub.URL, ""), true)

	rate, available, err := svc.GetRate(context.Background(), "USD", "EUR")
	if err != nil {
		t.Fatalf("expected nil error on garbage body, got: %v", err)
	}
	if available {
		t.Fatal("expected available=false on garbage body")
	}
	if rate != 0 {
		t.Fatalf("expected rate=0 on garbage body, got %v", rate)
	}
}

// TestGetRate_Disabled confirms that with the feature disabled (empty URL),
// GetRate returns available=false and the provider is never called.
func TestGetRate_Disabled(t *testing.T) {
	var callCount int32
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// This must never be reached.
		atomic.AddInt32(&callCount, 1)
		fmt.Fprint(w, frankfurterJSON("EUR", 0.92))
	}))
	defer stub.Close()

	// enabled=false — provider is nil (as it would be in production when URL is unset)
	svc := NewRateService(nil, false)

	rate, available, err := svc.GetRate(context.Background(), "USD", "EUR")
	if err != nil {
		t.Fatalf("unexpected error when disabled: %v", err)
	}
	if available {
		t.Fatal("expected available=false when feature is disabled")
	}
	if rate != 0 {
		t.Fatalf("expected rate=0 when disabled, got %v", rate)
	}
	if atomic.LoadInt32(&callCount) != 0 {
		t.Fatalf("provider must not be called when disabled, got %d calls", atomic.LoadInt32(&callCount))
	}
}

// TestGetRate_InvalidCurrencyCode verifies that non-3-letter / lowercase codes
// are rejected without calling the provider.
func TestGetRate_InvalidCurrencyCode(t *testing.T) {
	var callCount int32
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&callCount, 1)
		fmt.Fprint(w, frankfurterJSON("EUR", 0.92))
	}))
	defer stub.Close()

	svc := NewRateService(NewFrankfurterProvider(stub.URL, ""), true)

	cases := []struct{ from, to string }{
		{"usd", "EUR"},  // lowercase
		{"US", "EUR"},   // too short
		{"USDD", "EUR"}, // too long
		{"USD", "eu"},   // too short
		{"USD", ""},     // empty
	}
	for _, c := range cases {
		rate, available, err := svc.GetRate(context.Background(), c.from, c.to)
		if err != nil {
			t.Errorf("(%s→%s): unexpected error: %v", c.from, c.to, err)
		}
		if available {
			t.Errorf("(%s→%s): expected available=false for invalid code", c.from, c.to)
		}
		if rate != 0 {
			t.Errorf("(%s→%s): expected rate=0, got %v", c.from, c.to, rate)
		}
	}
	if atomic.LoadInt32(&callCount) != 0 {
		t.Fatalf("provider must not be called for invalid codes, got %d calls", atomic.LoadInt32(&callCount))
	}
}

// TestGetRate_SameCurrency confirms a trivial 1:1 rate for same-currency pairs.
func TestGetRate_SameCurrency(t *testing.T) {
	// Provider should never be called for same-currency pairs.
	svc := NewRateService(nil, true)

	rate, available, err := svc.GetRate(context.Background(), "EUR", "EUR")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !available {
		t.Fatal("expected available=true for same currency")
	}
	if rate != 1 {
		t.Fatalf("expected rate=1, got %v", rate)
	}
}

// TestFrankfurterProvider_MissingRateKey verifies that a response without the
// expected currency key returns available=false.
func TestFrankfurterProvider_MissingRateKey(t *testing.T) {
	stub := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Returns rates for a different currency than requested.
		body, _ := json.Marshal(map[string]any{"rates": map[string]float64{"GBP": 0.8}})
		w.Header().Set("Content-Type", "application/json")
		w.Write(body)
	}))
	defer stub.Close()

	p := NewFrankfurterProvider(stub.URL, "")
	rate, available, err := p.FetchRate(context.Background(), "USD", "EUR")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if available {
		t.Fatal("expected available=false when key is missing from rates")
	}
	if rate != 0 {
		t.Fatalf("expected rate=0, got %v", rate)
	}
}
