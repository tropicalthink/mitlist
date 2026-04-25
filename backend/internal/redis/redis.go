package redis

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/pkg/logger"
)

// RedisClient wraps go-redis/v9 with application-level conveniences.
type RedisClient struct {
	client *redis.Client
	log    *logger.Logger
}

// New creates a RedisClient from application config. It parses the Redis URL,
// applies the optional standalone password override, and verifies connectivity
// with a Ping before returning.
func New(cfg *config.Config) (*RedisClient, error) {
	log := logger.New(cfg.Environment)

	opts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		return nil, fmt.Errorf("invalid redis url: %w", err)
	}

	if cfg.RedisPassword != "" {
		opts.Password = cfg.RedisPassword
	}

	client := redis.NewClient(opts)

	rc := &RedisClient{
		client: client,
		log:    log,
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rc.Ping(ctx); err != nil {
		_ = client.Close()
		return nil, fmt.Errorf("redis ping failed: %w", err)
	}

	log.Info().Str("addr", opts.Addr).Msg("redis connected")
	return rc, nil
}

// Ping performs a health-check ping against Redis.
func (rc *RedisClient) Ping(ctx context.Context) error {
	return rc.client.Ping(ctx).Err()
}

// Close gracefully shuts down the Redis client.
func (rc *RedisClient) Close() error {
	rc.log.Info().Msg("redis connection closing")
	return rc.client.Close()
}

// Client exposes the underlying go-redis client for advanced usage.
func (rc *RedisClient) Client() *redis.Client {
	return rc.client
}
