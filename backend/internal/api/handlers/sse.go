package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
	userservice "github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
)

// SSEHandler serves Server-Sent Events for real-time group updates.
type SSEHandler struct {
	hub        *sse.Hub
	jwtService *jwtservice.Service
	userSvc    *userservice.UserService
	groupRepo  repositories.GroupRepo
}

// NewSSEHandler creates a new SSEHandler.
func NewSSEHandler(hub *sse.Hub, jwtService *jwtservice.Service, userSvc *userservice.UserService, groupRepo repositories.GroupRepo) *SSEHandler {
	return &SSEHandler{hub: hub, jwtService: jwtService, userSvc: userSvc, groupRepo: groupRepo}
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

	rawGroupID := r.URL.Query().Get("group_id")
	if rawGroupID == "" {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	parsedGroupID, err := uuid.Parse(rawGroupID)
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid group_id"})
		return
	}

	if _, err := h.groupRepo.GetMembership(r.Context(), parsedGroupID, user.ID); err != nil {
		api.RespondError(w, api.ErrPermissionDenied)
		return
	}

	groupID := parsedGroupID.String()

	if _, ok := w.(http.Flusher); !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no") // disable nginx buffering

	rc := http.NewResponseController(w)

	// write emits one SSE frame with a bounded per-write deadline. A half-open
	// connection's stuck write fails after the budget instead of parking this
	// goroutine forever (the global server WriteTimeout doesn't apply here —
	// SSE is long-lived — so we bound each write individually).
	const writeBudget = 15 * time.Second
	write := func(frame string) bool {
		if err := rc.SetWriteDeadline(time.Now().Add(writeBudget)); err != nil {
			return false
		}
		if _, err := fmt.Fprint(w, frame); err != nil {
			return false
		}
		if err := rc.Flush(); err != nil {
			return false
		}
		return true
	}

	ch := h.hub.Subscribe(groupID, user.ID.String())
	defer func() {
		h.hub.Unsubscribe(groupID, ch)
		// Tell everyone still on the board that this viewer left.
		h.hub.BroadcastPresence(groupID)
	}()

	// Send an initial ping so the client knows the stream is live.
	if !write(": ping\n\n") {
		return
	}

	// Announce presence now that this client is subscribed; the broadcast also
	// delivers the current roster to the just-connected viewer.
	h.hub.BroadcastPresence(groupID)

	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-r.Context().Done():
			return
		case <-ticker.C:
			// Keep-alive comment to prevent proxy timeouts.
			if !write(": keep-alive\n\n") {
				return
			}
			if ev, err := h.hub.PresenceEvent(groupID); err == nil {
				if data, err := json.Marshal(ev); err == nil {
					if !write(fmt.Sprintf("data: %s\n\n", data)) {
						return
					}
				}
			}
		case event, open := <-ch:
			if !open {
				return
			}
			data, err := json.Marshal(event)
			if err != nil {
				continue
			}
			if !write(fmt.Sprintf("data: %s\n\n", data)) {
				return
			}
		}
	}
}
