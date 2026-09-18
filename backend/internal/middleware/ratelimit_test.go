package middleware

import (
	"strconv"
	"sync"
	"testing"
)

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

func TestLimiterEvictsLeastRecentlyUsedBucket(t *testing.T) {
	limiter := NewLimiter()
	limiter.Allow("kept", 2, 1, 100)
	limiter.Allow("evicted", 2, 1, 100)
	for i := 0; i < maxRateLimitBuckets-2; i++ {
		limiter.Allow("filler-"+strconv.Itoa(i), 2, 1, 100)
	}

	// Refresh the oldest bucket, leaving "evicted" as least recently used.
	limiter.Allow("kept", 2, 1, 100)
	limiter.Allow("new", 2, 1, 100)

	if _, ok := limiter.buckets["kept"]; !ok {
		t.Fatal("recently used bucket was evicted")
	}
	if _, ok := limiter.buckets["evicted"]; ok {
		t.Fatal("least recently used bucket was retained")
	}
	if _, ok := limiter.buckets["new"]; !ok {
		t.Fatal("new bucket was not retained")
	}
}

func TestLimiterConcurrentChurnKeepsIndexConsistent(t *testing.T) {
	limiter := NewLimiter()
	var wg sync.WaitGroup
	for worker := 0; worker < 16; worker++ {
		wg.Add(1)
		go func(worker int) {
			defer wg.Done()
			for i := 0; i < 2_000; i++ {
				key := "worker-" + strconv.Itoa(worker) + "-" + strconv.Itoa(i)
				limiter.Allow(key, 2, 1, float64(i))
				limiter.Allow("shared", 2, 1, float64(i))
				if i%17 == 0 {
					limiter.Reset(key)
				}
			}
		}(worker)
	}
	wg.Wait()

	if got := len(limiter.buckets); got > maxRateLimitBuckets {
		t.Fatalf("bucket count = %d, want at most %d", got, maxRateLimitBuckets)
	}
	seen := make(map[*bucketState]bool, len(limiter.buckets))
	var newer *bucketState
	for state := limiter.mostRecent; state != nil; state = state.older {
		if seen[state] {
			t.Fatal("recency list contains a cycle")
		}
		seen[state] = true
		if state.newer != newer {
			t.Fatal("recency list has inconsistent links")
		}
		if limiter.buckets[state.key] != state {
			t.Fatal("recency list contains a bucket missing from the index")
		}
		newer = state
	}
	if newer != limiter.leastRecent {
		t.Fatal("least-recent pointer does not match the recency list")
	}
	if len(seen) != len(limiter.buckets) {
		t.Fatalf("recency list has %d entries for %d indexed buckets", len(seen), len(limiter.buckets))
	}
}

func BenchmarkLimiterUniqueKeyChurn(b *testing.B) {
	limiter := NewLimiter()
	for i := 0; i < maxRateLimitBuckets; i++ {
		limiter.Allow("seed-"+strconv.Itoa(i), 1, 1, 100)
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		limiter.Allow("spray-"+strconv.Itoa(i), 1, 1, 100)
	}
}
