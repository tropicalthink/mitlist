package middleware

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/rs/zerolog/log"
)

const (
	ipCapacity   = 100
	ipRefillRate = 100.0 / 60.0 // tokens per second

	userCapacity   = 1000
	userRefillRate = 1000.0 / 3600.0 // tokens per second
)

type userContextKey struct{}

// WithUserID injects a user ID into the request context for per-user rate limiting.
func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userContextKey{}, userID)
}

// UserIDFromContext retrieves the user ID from the request context.
func UserIDFromContext(ctx context.Context) string {
	if id, ok := ctx.Value(userContextKey{}).(string); ok {
		return id
	}
	return ""
}

var tokenBucketScript = redis.NewScript(`
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refillRate = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local cost = tonumber(ARGV[4])

local state = redis.call('HMGET', key, 'tokens', 'last_refill')
local tokens = tonumber(state[1])
local last_refill = tonumber(state[2])

if tokens == nil then
	tokens = capacity
	last_refill = now
end

local elapsed = now - last_refill
local new_tokens = math.min(capacity, tokens + elapsed * refillRate)

if new_tokens < cost then
	redis.call('HMSET', key, 'tokens', new_tokens, 'last_refill', now)
	redis.call('EXPIRE', key, math.ceil(capacity / refillRate) + 1)
	return 0
else
	new_tokens = new_tokens - cost
	redis.call('HMSET', key, 'tokens', new_tokens, 'last_refill', now)
	redis.call('EXPIRE', key, math.ceil(capacity / refillRate) + 1)
	return 1
end
`)

// RateLimit returns a chi-compatible HTTP middleware that enforces per-IP
// (100 req/min) and per-user (1000 req/hr) rate limits using a Redis token
// bucket. Routes /health and /api/v1/auth/token are excluded.
func RateLimit(client *redis.Client, apiPrefix string) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if client == nil {
				next.ServeHTTP(w, r)
				return
			}

			if shouldSkip(r.URL.Path, apiPrefix) {
				next.ServeHTTP(w, r)
				return
			}

			ip := ExtractIP(r)
			now := float64(time.Now().UnixNano()) / 1e9

			allowed, err := checkLimit(r.Context(), client, "ratelimit:ip:"+ip, ipCapacity, ipRefillRate, now)
			if err != nil {
				log.Warn().Err(err).Str("ip", ip).Msg("ip rate limit check failed, allowing")
			}
			if !allowed {
				http.Error(w, `{"error":"rate limit exceeded"}`, http.StatusTooManyRequests)
				return
			}

			if userID := UserIDFromContext(r.Context()); userID != "" {
				allowed, err := checkLimit(r.Context(), client, "ratelimit:user:"+userID, userCapacity, userRefillRate, now)
				if err != nil {
					log.Warn().Err(err).Str("user_id", userID).Msg("user rate limit check failed, allowing")
				}
				if !allowed {
					http.Error(w, `{"error":"rate limit exceeded"}`, http.StatusTooManyRequests)
					return
				}
			}

			next.ServeHTTP(w, r)
		})
	}
}

func shouldSkip(path string, apiPrefix string) bool {
	if path == "/health" {
		return true
	}
	return strings.HasPrefix(path, apiPrefix+"/v1/auth/token")
}

func checkLimit(ctx context.Context, client *redis.Client, key string, capacity int, refillRate float64, now float64) (bool, error) {
	result, err := tokenBucketScript.Run(ctx, client, []string{key}, capacity, refillRate, now, 1).Result()
	if err != nil {
		return false, err
	}
	allowed, _ := result.(int64)
	return allowed == 1, nil
}
