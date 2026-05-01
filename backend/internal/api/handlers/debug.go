package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/mitlist-app/mitlist/internal/config"
)

// DebugHandler exposes administrative debug endpoints.
type DebugHandler struct {
	cfg    *config.Config
	router chi.Router
}

// NewDebugHandler creates a new DebugHandler.
func NewDebugHandler(cfg *config.Config, router chi.Router) *DebugHandler {
	return &DebugHandler{cfg: cfg, router: router}
}

// Routes returns the debug sub-router guarded by AdminGuard.
func (h *DebugHandler) Routes() http.Handler {
	r := chi.NewRouter()
	r.Use(AdminGuard)
	r.Get("/routes", h.listRoutes)
	r.Get("/config", h.getConfig)
	return r
}

func (h *DebugHandler) listRoutes(w http.ResponseWriter, r *http.Request) {
	routes := []map[string]string{}
	_ = chi.Walk(h.router, func(method, route string, handler http.Handler, middlewares ...func(http.Handler) http.Handler) error {
		routes = append(routes, map[string]string{
			"method": method,
			"path":   route,
		})
		return nil
	})
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{"routes": routes})
}

func (h *DebugHandler) getConfig(w http.ResponseWriter, r *http.Request) {
	masked := h.cfg.MaskSecrets()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(masked)
}
