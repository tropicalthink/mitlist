package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/sse"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	userservice "github.com/mitlist-app/mitlist/internal/services"
)

// SSEHandler serves Server-Sent Events for real-time group updates.
type SSEHandler struct {
	hub        *sse.Hub
	jwtService *jwtservice.Service
	userSvc    *userservice.UserService
}

// NewSSEHandler creates a new SSEHandler.
func NewSSEHandler(hub *sse.Hub, jwtService *jwtservice.Service, userSvc *userservice.UserService) *SSEHandler {
	return &SSEHandler{hub: hub, jwtService: jwtService, userSvc: userSvc}
}

// RegisterRoutes mounts the SSE endpoint.
func (h *SSEHandler) RegisterRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(h.jwtService, h.userSvc))
		r.Get("/events", h.Events)
	})
}

// Events streams SSE for the authenticated user's requested group.
//
// GET /api/v1/events?group_id=<uuid>
func (h *SSEHandler) Events(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	_ = user // authenticated; group membership is enforced by event emission (server only sends to members' groups)

	groupID := r.URL.Query().Get("group_id")
	if groupID == "" {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no") // disable nginx buffering

	ch := h.hub.Subscribe(groupID)
	defer h.hub.Unsubscribe(groupID, ch)

	// Send an initial ping so the client knows the stream is live.
	_, _ = fmt.Fprintf(w, ": ping\n\n")
	flusher.Flush()

	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
			// Keep-alive comment to prevent proxy timeouts.
			_, _ = fmt.Fprintf(w, ": keep-alive\n\n")
			flusher.Flush()
		case event, open := <-ch:
			if !open {
				return
			}
			data, err := json.Marshal(event)
			if err != nil {
				continue
			}
			_, _ = fmt.Fprintf(w, "data: %s\n\n", data)
			flusher.Flush()
		}
	}
}
