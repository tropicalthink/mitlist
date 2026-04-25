package db

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/pkg/logger"
)

const (
	defaultMaxConns            int32 = 20
	defaultMinConns            int32 = 1
	defaultConnectTimeout            = 30 * time.Second
	defaultMaxConnLifetime           = time.Hour
	defaultMaxConnIdleTime           = 30 * time.Minute
	defaultHealthCheckPeriod         = time.Minute
	defaultStatementTimeoutMS        = "10000"
	defaultRetryAttempts             = 5
	defaultRetryInitialBackoff       = 500 * time.Millisecond
	defaultRetryMaxBackoff           = 8 * time.Second
	defaultStatsLogPeriod            = time.Minute
)

var poolLoggers sync.Map

type poolLogger struct {
	stop chan struct{}
	done chan struct{}
}

// New creates a PostgreSQL connection pool from application config.
// It retries initial connectivity with exponential backoff and starts a
// periodic pool-stat logger for operational visibility.
func New(cfg *config.Config) (*pgxpool.Pool, error) {
	log := logger.New(cfg.Environment)

	poolCfg, err := pgxpool.ParseConfig(cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("invalid database url: %w", err)
	}

	applyDefaults(poolCfg)

	pool, err := connectWithRetry(context.Background(), poolCfg, log)
	if err != nil {
		return nil, err
	}

	startStatsLogger(pool, log)
	log.Info().Msg("postgres connected")

	return pool, nil
}

// Close stops db package background work for the pool, then closes it.
// Calling pool.Close directly is safe, but this helper also terminates the
// periodic stats logger started by New.
func Close(pool *pgxpool.Pool) {
	if pool == nil {
		return
	}

	if raw, ok := poolLoggers.LoadAndDelete(pool); ok {
		pl := raw.(*poolLogger)
		close(pl.stop)
		<-pl.done
	}

	pool.Close()
}

func applyDefaults(poolCfg *pgxpool.Config) {
	poolCfg.MaxConns = defaultMaxConns
	poolCfg.MinConns = defaultMinConns
	poolCfg.MaxConnLifetime = defaultMaxConnLifetime
	poolCfg.MaxConnIdleTime = defaultMaxConnIdleTime
	poolCfg.HealthCheckPeriod = defaultHealthCheckPeriod
	poolCfg.ConnConfig.ConnectTimeout = defaultConnectTimeout

	if poolCfg.ConnConfig.RuntimeParams == nil {
		poolCfg.ConnConfig.RuntimeParams = make(map[string]string)
	}
	poolCfg.ConnConfig.RuntimeParams["statement_timeout"] = defaultStatementTimeoutMS
	poolCfg.ConnConfig.RuntimeParams["jit"] = "off"
}

func connectWithRetry(ctx context.Context, cfg *pgxpool.Config, log *logger.Logger) (*pgxpool.Pool, error) {
	backoff := defaultRetryInitialBackoff
	var lastErr error

	for attempt := 1; attempt <= defaultRetryAttempts; attempt++ {
		attemptCtx, cancel := context.WithTimeout(ctx, defaultConnectTimeout)
		pool, err := pgxpool.NewWithConfig(attemptCtx, cfg)
		if err == nil {
			err = pool.Ping(attemptCtx)
		}
		cancel()

		if err == nil {
			return pool, nil
		}

		if pool != nil {
			pool.Close()
		}

		lastErr = err
		if attempt == defaultRetryAttempts {
			break
		}

		log.WithError(err).Warn().
			Int("attempt", attempt).
			Dur("backoff", backoff).
			Msg("postgres connection attempt failed")

		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("postgres connection cancelled: %w", ctx.Err())
		case <-time.After(backoff):
		}

		backoff *= 2
		if backoff > defaultRetryMaxBackoff {
			backoff = defaultRetryMaxBackoff
		}
	}

	return nil, fmt.Errorf("postgres connection failed after %d attempts: %w", defaultRetryAttempts, lastErr)
}

func startStatsLogger(pool *pgxpool.Pool, log *logger.Logger) {
	pl := &poolLogger{
		stop: make(chan struct{}),
		done: make(chan struct{}),
	}
	poolLoggers.Store(pool, pl)

	go func() {
		defer close(pl.done)

		ticker := time.NewTicker(defaultStatsLogPeriod)
		defer ticker.Stop()

		for {
			select {
			case <-ticker.C:
				stats := pool.Stat()
				log.Info().
					Int32("acquired_conns", stats.AcquiredConns()).
					Int32("idle_conns", stats.IdleConns()).
					Int32("total_conns", stats.TotalConns()).
					Int64("acquire_count", stats.AcquireCount()).
					Int64("canceled_acquire_count", stats.CanceledAcquireCount()).
					Int64("empty_acquire_count", stats.EmptyAcquireCount()).
					Int64("new_conns_count", stats.NewConnsCount()).
					Int64("max_lifetime_destroy_count", stats.MaxLifetimeDestroyCount()).
					Int64("max_idle_destroy_count", stats.MaxIdleDestroyCount()).
					Msg("postgres pool stats")
			case <-pl.stop:
				return
			}
		}
	}()
}
