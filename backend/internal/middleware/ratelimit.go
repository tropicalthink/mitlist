package middleware

import (
	"context"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	maxRateLimitBuckets = 10_000
	ipCapacity          = 100
	ipRefillRate        = 100.0 / 60.0
	userCapacity        = 1000
	userRefillRate      = 1000.0 / 3600.0
	authIPCapacity      = 10
	authIPRefillRate    = 10.0 / 60.0
)

type userContextKey struct{}

func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userContextKey{}, userID)
}

func UserIDFromContext(ctx context.Context) string {
	id, _ := ctx.Value(userContextKey{}).(string)
	return id
}

type bucketState struct {
	tokens     float64
	lastRefill float64
	lastSeen   time.Time
}

// Limiter is a bounded in-process token-bucket store. Cloudflare remains the
// first line of IP abuse protection; this protects the Go process without an
// additional datastore.
type Limiter struct {
	mu      sync.Mutex
	buckets map[string]bucketState
}

func NewLimiter() *Limiter { return &Limiter{buckets: make(map[string]bucketState)} }

var defaultLimiter = NewLimiter()

func (l *Limiter) Allow(key string, capacity int, refillRate float64, now float64) bool {
	if capacity <= 0 || refillRate <= 0 {
		return true
	}
	l.mu.Lock()
	defer l.mu.Unlock()

	state, ok := l.buckets[key]
	if !ok {
		state = bucketState{tokens: float64(capacity), lastRefill: now}
	}
	elapsed := now - state.lastRefill
	if elapsed < 0 {
		elapsed = 0
	}
	state.tokens = min(float64(capacity), state.tokens+elapsed*refillRate)
	state.lastRefill = now
	state.lastSeen = time.Now()
	if state.tokens < 1 {
		l.buckets[key] = state
		return false
	}
	state.tokens--
	l.buckets[key] = state

	if len(l.buckets) > maxRateLimitBuckets {
		cutoff := time.Now().Add(-2 * time.Hour)
		for bucketKey, bucket := range l.buckets {
			if bucket.lastSeen.Before(cutoff) {
				delete(l.buckets, bucketKey)
			}
		}
		// Under a spray of unique identifiers, recent buckets can still exceed
		// the cap. Evict arbitrary entries; rate limiting is best-effort state.
		for bucketKey := range l.buckets {
			if len(l.buckets) <= maxRateLimitBuckets {
				break
			}
			delete(l.buckets, bucketKey)
		}
	}
	return true
}

func (l *Limiter) Reset(key string) {
	l.mu.Lock()
	delete(l.buckets, key)
	l.mu.Unlock()
}

func RateLimit(apiPrefix string) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if shouldSkip(r.URL.Path, apiPrefix) {
				next.ServeHTTP(w, r)
				return
			}
			ip := ExtractIP(r)
			now := float64(time.Now().UnixNano()) / 1e9
			key, capacity, refill := "ratelimit:ip:"+ip, ipCapacity, ipRefillRate
			if isAuthEndpoint(r.URL.Path, apiPrefix) {
				key, capacity, refill = "ratelimit:auth:ip:"+ip, authIPCapacity, authIPRefillRate
			}
			if !defaultLimiter.Allow(key, capacity, refill, now) {
				writeRateLimitError(w)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func UserRateLimit() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := UserIDFromContext(r.Context())
			if userID != "" && !defaultLimiter.Allow(
				"ratelimit:user:"+userID, userCapacity, userRefillRate,
				float64(time.Now().UnixNano())/1e9,
			) {
				writeRateLimitError(w)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func CheckLimit(key string, capacity int, refillRate float64, now ...float64) bool {
	t := float64(time.Now().UnixNano()) / 1e9
	if len(now) > 0 {
		t = now[0]
	}
	return defaultLimiter.Allow(key, capacity, refillRate, t)
}

func ResetLimit(key string) { defaultLimiter.Reset(key) }

func writeRateLimitError(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusTooManyRequests)
	_, _ = w.Write([]byte(`{"error":"rate limit exceeded"}`))
}

func isAuthEndpoint(path, apiPrefix string) bool {
	for _, p := range []string{
		apiPrefix + "/v1/auth/login", apiPrefix + "/v1/auth/register",
		apiPrefix + "/v1/auth/password-reset", apiPrefix + "/v1/auth/guest",
		apiPrefix + "/v1/auth/token/refresh",
	} {
		if strings.HasPrefix(path, p) {
			return true
		}
	}
	return false
}

func shouldSkip(path, apiPrefix string) bool {
	return path == "/healthz" || path == "/readyz" || strings.HasPrefix(path, "/internal/health")
}
