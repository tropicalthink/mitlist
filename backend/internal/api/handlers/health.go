package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/yourorg/mitlist/internal/redis"
)

// HealthHandler provides the health check endpoint.
type HealthHandler struct {
	db    *pgxpool.Pool
	redis *redis.RedisClient
}

// NewHealthHandler creates a new HealthHandler.
func NewHealthHandler(db *pgxpool.Pool, redis *redis.RedisClient) *HealthHandler {
	return &HealthHandler{db: db, redis: redis}
}

type healthResponse struct {
	Status string            `json:"status"`
	Checks map[string]string `json:"checks"`
}

func (h *HealthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	checks := make(map[string]string)
	overall := "ok"

	if h.db != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		if err := h.db.Ping(ctx); err != nil {
			checks["db"] = "unreachable"
			overall = "error"
		} else {
			checks["db"] = "ok"
		}
	} else {
		checks["db"] = "not configured"
	}

	if h.redis != nil {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		if err := h.redis.Ping(ctx); err != nil {
			checks["redis"] = "unreachable"
			overall = "error"
		} else {
			checks["redis"] = "ok"
		}
	} else {
		checks["redis"] = "not configured"
	}

	w.Header().Set("Content-Type", "application/json")
	if overall != "ok" {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	_ = json.NewEncoder(w).Encode(healthResponse{Status: overall, Checks: checks})
}
