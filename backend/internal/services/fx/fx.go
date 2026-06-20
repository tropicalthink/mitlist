// Package fx provides opt-in, cached, fail-soft live exchange-rate suggestions
// for multi-currency expenses. It is advisory only — the data model and balance
// math (normalizeBaseAmount / buildSplits) are untouched; the endpoint merely
// prefills the FX-rate field in the add-expense form.
//
// When FX_RATE_API_URL is empty (the default) the feature is disabled and the
// endpoint reports "unavailable" without making any outbound call.
package fx

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"time"

	"github.com/redis/go-redis/v9"
)

// validCurrency matches 3-letter ISO-4217-ish currency codes (uppercase A–Z only).
var validCurrency = regexp.MustCompile(`^[A-Z]{3}$`)

// Provider is the interface satisfied by any FX-rate data source.
// FetchRate returns (rate, available, error).
// When available is false the caller treats the result as "no data" — this is
// the fail-soft path (provider down, timeout, parse failure, etc.).
type Provider interface {
	FetchRate(ctx context.Context, from, to string) (float64, bool, error)
}

// frankfurterProvider fetches from a Frankfurter-compatible endpoint
// (https://api.frankfurter.dev or a compatible self-hosted mirror).
type frankfurterProvider struct {
	baseURL string
	apiKey  string
	client  *http.Client
}

// frankfurterResponse is the minimal subset of Frankfurter's JSON response that
// we need: {"rates":{"EUR":0.92,...}}.
type frankfurterResponse struct {
	Rates map[string]float64 `json:"rates"`
}

// NewFrankfurterProvider builds a provider pointed at baseURL.
// apiKey is forwarded as a Bearer token when non-empty; Frankfurter itself does
// not require one, but a self-hosted mirror may.
func NewFrankfurterProvider(baseURL, apiKey string) Provider {
	return &frankfurterProvider{
		baseURL: baseURL,
		apiKey:  apiKey,
		// Match the push-service timeout convention (push.go:50).
		client: &http.Client{Timeout: 10 * time.Second},
	}
}

// FetchRate fetches the current exchange rate from → to.
// Any network, HTTP, or parse failure is silently swallowed and returns
// (0, false, nil) — the caller degrades to manual entry.
func (p *frankfurterProvider) FetchRate(ctx context.Context, from, to string) (float64, bool, error) {
	url := fmt.Sprintf("%s/latest?from=%s&to=%s", p.baseURL, from, to)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return 0, false, nil // fail-soft
	}
	if p.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+p.apiKey)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := p.client.Do(req)
	if err != nil {
		return 0, false, nil // network / timeout — fail-soft
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, false, nil // non-200 — fail-soft
	}

	var body frankfurterResponse
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return 0, false, nil // parse failure — fail-soft
	}

	rate, ok := body.Rates[to]
	if !ok || rate <= 0 {
		return 0, false, nil // missing rate in response — fail-soft
	}
	return rate, true, nil
}

// RateService wraps the provider with Redis caching and feature-flag gating.
type RateService struct {
	provider Provider
	redis    *redis.Client
	enabled  bool // true iff FX_RATE_API_URL was set
}

// NewRateService constructs the service.
// provider may be nil when enabled is false (disabled path never calls it).
func NewRateService(provider Provider, redisClient *redis.Client, enabled bool) *RateService {
	return &RateService{
		provider: provider,
		redis:    redisClient,
		enabled:  enabled,
	}
}

// GetRate returns the exchange rate from → to.
// Returns (rate, true, nil) on a hit, (0, false, nil) when unavailable or
// disabled, and (0, false, err) only for Redis errors that are non-recoverable
// (callers must still degrade gracefully).
func (s *RateService) GetRate(ctx context.Context, from, to string) (float64, bool, error) {
	// Feature disabled — no outbound call ever.
	if !s.enabled {
		return 0, false, nil
	}

	// Input validation: only 3-letter uppercase codes accepted.
	if !validCurrency.MatchString(from) || !validCurrency.MatchString(to) {
		return 0, false, nil
	}

	// Same currency: trivial.
	if from == to {
		return 1, true, nil
	}

	// Redis cache key: fx:rate:<FROM>:<TO>:<YYYY-MM-DD>
	today := time.Now().UTC().Format("2006-01-02")
	cacheKey := fmt.Sprintf("fx:rate:%s:%s:%s", from, to, today)

	// Cache lookup.
	cached, err := s.redis.Get(ctx, cacheKey).Float64()
	if err == nil && cached > 0 {
		return cached, true, nil
	}
	// redis.Nil means miss; any other error: fall through to provider (fail-soft).

	// Provider fetch.
	rate, available, err := s.provider.FetchRate(ctx, from, to)
	if err != nil || !available || rate <= 0 {
		return 0, false, nil // fail-soft
	}

	// Cache the result for 24 h. Ignore cache-write errors — read path still works.
	_ = s.redis.Set(ctx, cacheKey, rate, 24*time.Hour).Err()

	return rate, true, nil
}
