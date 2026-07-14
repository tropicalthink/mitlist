package middleware

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
)

// Metrics holds Prometheus metric collectors.
type Metrics struct {
	requestsTotal   *prometheus.CounterVec
	requestDuration *prometheus.HistogramVec
	dbConnections   *prometheus.GaugeVec
}

var (
	metricsOnce sync.Once
	metricsInst *Metrics
)

// GetMetrics returns the singleton Metrics instance.
func GetMetrics() *Metrics {
	metricsOnce.Do(func() {
		m := &Metrics{
			requestsTotal: prometheus.NewCounterVec(prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests.",
			}, []string{"method", "status"}),
			requestDuration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "HTTP request duration in seconds.",
				Buckets: prometheus.DefBuckets,
			}, []string{"method", "status"}),
			dbConnections: prometheus.NewGaugeVec(prometheus.GaugeOpts{
				Name: "db_connections_active",
				Help: "Active database connections.",
			}, []string{"state"}),
		}
		prometheus.MustRegister(m.requestsTotal, m.requestDuration, m.dbConnections)
		metricsInst = m
	})
	return metricsInst
}

// MetricsMiddleware records request metrics and exposes infrastructure stats.
func MetricsMiddleware(db *pgxpool.Pool) func(next http.Handler) http.Handler {
	m := GetMetrics()
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
			next.ServeHTTP(rec, r)
			duration := time.Since(start).Seconds()
			status := strconv.Itoa(rec.statusCode)

			m.requestsTotal.WithLabelValues(r.Method, status).Inc()
			m.requestDuration.WithLabelValues(r.Method, status).Observe(duration)

			if db != nil {
				stats := db.Stat()
				m.dbConnections.WithLabelValues("acquired").Set(float64(stats.AcquiredConns()))
				m.dbConnections.WithLabelValues("idle").Set(float64(stats.IdleConns()))
				m.dbConnections.WithLabelValues("total").Set(float64(stats.TotalConns()))
			}
		})
	}
}

type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (sr *statusRecorder) WriteHeader(code int) {
	sr.statusCode = code
	sr.ResponseWriter.WriteHeader(code)
}

func (sr *statusRecorder) Flush() {
	if f, ok := sr.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

func (sr *statusRecorder) Unwrap() http.ResponseWriter {
	return sr.ResponseWriter
}
