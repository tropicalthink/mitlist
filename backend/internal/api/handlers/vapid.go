package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/mitlist-app/mitlist/internal/config"
)

// VAPIDHandler returns the VAPID public key.
type VAPIDHandler struct {
	cfg *config.Config
}

// NewVAPIDHandler creates a new VAPIDHandler.
func NewVAPIDHandler(cfg *config.Config) *VAPIDHandler {
	return &VAPIDHandler{cfg: cfg}
}

func (h *VAPIDHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"public_key": h.cfg.VapidPublicKey,
	})
}
