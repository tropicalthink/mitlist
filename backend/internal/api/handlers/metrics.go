package handlers

import (
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// NewMetricsHandler returns the Prometheus metrics HTTP handler.
func NewMetricsHandler() http.Handler {
	return promhttp.Handler()
}
