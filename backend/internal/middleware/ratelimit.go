package middleware

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	maxRateLimitBuckets      = 10_000
	ipCapacity               = 100
	ipRefillRate             = 100.0 / 60.0
	userCapacity             = 1000
	userRefillRate           = 1000.0 / 3600.0
	authIPCapacity           = 10
	authIPRefillRate         = 10.0 / 60.0
	authIdentifierCapacity   = 5
	authIdentifierRefillRate = 5.0 / 300.0
	guestIPCapacity          = 3
	guestIPRefillRate        = 3.0 / 600.0
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
	key        string
	tokens     float64
	lastRefill float64
	newer      *bucketState
	older      *bucketState
}

// Limiter is a bounded in-process token-bucket store. Cloudflare remains the
// first line of IP abuse protection; this protects the Go process without an
// additional datastore.
type Limiter struct {
	mu          sync.Mutex
	buckets     map[string]*bucketState
	mostRecent  *bucketState
	leastRecent *bucketState
}

func NewLimiter() *Limiter {
	return &Limiter{buckets: make(map[string]*bucketState)}
}

var defaultLimiter = NewLimiter()

func (l *Limiter) Allow(key string, capacity int, refillRate float64, now float64) bool {
	if capacity <= 0 || refillRate <= 0 {
		return true
	}
	l.mu.Lock()
	defer l.mu.Unlock()

	state, ok := l.buckets[key]
	if !ok {
		if len(l.buckets) >= maxRateLimitBuckets {
			oldest := l.leastRecent
			if oldest != nil {
				l.remove(oldest)
				delete(l.buckets, oldest.key)
			}
		}
		state = &bucketState{key: key, tokens: float64(capacity), lastRefill: now}
		l.markMostRecent(state)
		l.buckets[key] = state
	} else {
		l.markMostRecent(state)
	}
	elapsed := now - state.lastRefill
	if elapsed < 0 {
		elapsed = 0
	}
	state.tokens = min(float64(capacity), state.tokens+elapsed*refillRate)
	state.lastRefill = now
	if state.tokens < 1 {
		return false
	}
	state.tokens--
	return true
}

func (l *Limiter) Reset(key string) {
	l.mu.Lock()
	if state, ok := l.buckets[key]; ok {
		l.remove(state)
		delete(l.buckets, key)
	}
	l.mu.Unlock()
}

func (l *Limiter) markMostRecent(state *bucketState) {
	if l.mostRecent == state {
		return
	}
	if state.newer != nil || state.older != nil || l.leastRecent == state {
		l.remove(state)
	}
	state.older = l.mostRecent
	if l.mostRecent != nil {
		l.mostRecent.newer = state
	} else {
		l.leastRecent = state
	}
	l.mostRecent = state
}

func (l *Limiter) remove(state *bucketState) {
	if state.newer != nil {
		state.newer.older = state.older
	} else {
		l.mostRecent = state.older
	}
	if state.older != nil {
		state.older.newer = state.newer
	} else {
		l.leastRecent = state.newer
	}
	state.newer = nil
	state.older = nil
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
			if isAuthEndpoint(r.URL.Path, apiPrefix) {
				if identifier := authIdentifier(r); identifier != "" {
					identifierKey := "ratelimit:auth:identifier:" + endpointName(r.URL.Path, apiPrefix) + ":" + identifier
					if !defaultLimiter.Allow(identifierKey, authIdentifierCapacity, authIdentifierRefillRate, now) {
						writeRateLimitError(w)
						return
					}
				}
			}
			if isGuestCreationEndpoint(r.URL.Path, apiPrefix) {
				guestKey := "ratelimit:guest:ip:" + ip
				if !defaultLimiter.Allow(guestKey, guestIPCapacity, guestIPRefillRate, now) {
					writeRateLimitError(w)
					return
				}
				// Do not rate-limit guest creation by X-Mitlist-Install-ID. It is a
				// caller-controlled header and can be rotated or spoofed. The handler
				// applies the durable identity budget using verified App Check claims.
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
		apiPrefix + "/v1/auth/verify-email", apiPrefix + "/v1/auth/password-reset",
		apiPrefix + "/v1/auth/password-reset/confirm", apiPrefix + "/v1/auth/guest",
		apiPrefix + "/v1/auth/token/refresh",
	} {
		if strings.HasPrefix(path, p) {
			return true
		}
	}
	return false
}

func isGuestCreationEndpoint(path, apiPrefix string) bool {
	return path == apiPrefix+"/v1/auth/guest"
}

func endpointName(path, apiPrefix string) string {
	name := strings.TrimPrefix(path, apiPrefix+"/v1/auth/")
	return strings.ReplaceAll(name, "/", ":")
}

// authIdentifier extracts and hashes an email from an auth request. Hashing
// keeps raw addresses out of in-process limiter keys while combining a stable
// account-level budget with the IP budget above. The body is restored for the
// downstream handler.
func authIdentifier(r *http.Request) string {
	if r.Body == nil || r.Method == http.MethodGet {
		return ""
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 8<<10))
	if err != nil {
		return ""
	}
	r.Body = io.NopCloser(bytes.NewReader(body))
	var payload struct {
		Email string `json:"email"`
	}
	if json.Unmarshal(body, &payload) != nil {
		return ""
	}
	email := strings.ToLower(strings.TrimSpace(payload.Email))
	if email == "" {
		return ""
	}
	digest := sha256.Sum256([]byte(email))
	return hex.EncodeToString(digest[:])
}

func shouldSkip(path, apiPrefix string) bool {
	return path == "/healthz" || path == "/readyz" || strings.HasPrefix(path, "/internal/health")
}
