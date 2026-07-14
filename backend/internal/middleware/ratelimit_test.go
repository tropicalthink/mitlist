package middleware

import "testing"

func TestLimiterTokenBucket(t *testing.T) {
	limiter := NewLimiter()
	if !limiter.Allow("household", 2, 1, 100) {
		t.Fatal("first request should be allowed")
	}
	if !limiter.Allow("household", 2, 1, 100) {
		t.Fatal("second request should be allowed")
	}
	if limiter.Allow("household", 2, 1, 100) {
		t.Fatal("third request should be limited")
	}
	if !limiter.Allow("household", 2, 1, 101) {
		t.Fatal("one token should refill after one second")
	}
}

func TestLimiterReset(t *testing.T) {
	limiter := NewLimiter()
	if !limiter.Allow("login", 1, 1, 100) || limiter.Allow("login", 1, 1, 100) {
		t.Fatal("expected the bucket to become exhausted")
	}
	limiter.Reset("login")
	if !limiter.Allow("login", 1, 1, 100) {
		t.Fatal("reset should restore a fresh bucket")
	}
}

func TestLimiterBoundsUniqueKeys(t *testing.T) {
	limiter := NewLimiter()
	for i := 0; i <= maxRateLimitBuckets; i++ {
		limiter.Allow(string(rune(i)), 1, 1, 100)
	}
	if got := len(limiter.buckets); got > maxRateLimitBuckets {
		t.Fatalf("bucket count = %d, want at most %d", got, maxRateLimitBuckets)
	}
}
