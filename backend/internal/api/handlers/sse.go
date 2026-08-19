package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/repositories"
	userservice "github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	"github.com/mitlist-app/mitlist/internal/sse"
)

// SSEHandler serves Server-Sent Events for real-time group updates.
type SSEHandler struct {
	hub               *sse.Hub
	jwtService        *jwtservice.Service
	userSvc           *userservice.UserService
	groupRepo         repositories.GroupRepo
	credentialService *userservice.IntegrationCredentialService
}

// NewSSEHandler creates a new SSEHandler.
func NewSSEHandler(hub *sse.Hub, jwtService *jwtservice.Service, userSvc *userservice.UserService, groupRepo repositories.GroupRepo, credentialService ...*userservice.IntegrationCredentialService) *SSEHandler {
	var credentials *userservice.IntegrationCredentialService
	if len(credentialService) > 0 {
		credentials = credentialService[0]
	}
	return &SSEHandler{
		hub:               hub,
		jwtService:        jwtService,
		userSvc:           userSvc,
		groupRepo:         groupRepo,
		credentialService: credentials,
	}
}

// RegisterRoutes mounts the SSE endpoint.
func (h *SSEHandler) RegisterRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(middleware.AuthWithCredentials(h.jwtService, h.userSvc, h.credentialService))
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
	lastEventID := r.Header.Get("Last-Event-ID")
	if lastEventID != "" {
		if cursor, parseErr := strconv.ParseInt(lastEventID, 10, 64); parseErr != nil || cursor < 0 {
			api.RespondError(w, &api.ValidationError{Field: "Last-Event-ID", Message: "invalid event cursor"})
			return
		}
	}

	if _, ok := w.(http.Flusher); !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}

	// Reserve the stream before writing any bytes. The hub tracks both the
	// authenticated user and the client address, so reconnect storms and a
	// single browser opening many tabs cannot consume unbounded goroutines.
	ch, accepted := h.hub.TrySubscribe(groupID, user.ID.String(), middleware.ExtractIP(r))
	if !accepted {
		w.Header().Set("Retry-After", "30")
		api.RespondJSON(w, http.StatusTooManyRequests, map[string]string{
			"error":   "too many active event streams",
			"message": "close another live connection and try again shortly",
		})
		return
	}

	// Subscribe before loading the replay. Events arriving while the query is
	// running are buffered in ch; the sent-ID set below removes the overlap and
	// guarantees that no mutation falls between the replay and live stream.
	replay, replayErr := h.hub.Replay(r.Context(), groupID, lastEventID, 1000)
	if replayErr != nil {
		h.hub.Unsubscribe(groupID, ch)
		if errors.Is(replayErr, sse.ErrCursorExpired) {
			w.Header().Set("X-SSE-Cursor-Reset", "true")
			api.RespondJSON(w, http.StatusConflict, map[string]any{
				"error":          "cursor_expired",
				"reset_required": true,
			})
			return
		}
		api.RespondError(w, replayErr)
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

	defer func() {
		h.hub.Unsubscribe(groupID, ch)
		// Tell everyone still on the board that this viewer left.
		h.hub.BroadcastPresence(groupID)
	}()
	sentIDs := make(map[string]struct{}, len(replay))
	for _, event := range replay {
		if event.ID != "" {
			sentIDs[event.ID] = struct{}{}
		}
	}

	// Send an initial ping so the client knows the stream is live.
	if !write(": ping\n\n") {
		return
	}
	for _, event := range replay {
		if !integrationMayReceiveEvent(r, event.Type) {
			continue
		}
		data, marshalErr := json.Marshal(event)
		if marshalErr != nil || !write(sseFrame(event.ID, data)) {
			return
		}
	}

	// Announce presence now that this client is subscribed; the broadcast also
	// delivers the current roster to the just-connected viewer.
	h.hub.BroadcastPresence(groupID)

	ticker := time.NewTicker(25 * time.Second)
	defer ticker.Stop()

	// recheckEveryNTicks controls how often we re-validate group membership on a
	// live stream. ticker is 25s → every 4th tick ≈ every 100s.
	const recheckEveryNTicks = 4
	tickCount := 0

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
			tickCount++
			if tickCount%recheckEveryNTicks == 0 {
				if _, err := h.groupRepo.GetMembership(r.Context(), parsedGroupID, user.ID); err != nil {
					if errors.Is(err, pgx.ErrNoRows) {
						return // membership revoked — close the stream
					}
					// transient error: keep the connection, try again next cycle
				}
			}
		case event, open := <-ch:
			if !open {
				return
			}
			var envelope struct {
				ID   string `json:"id"`
				Type string `json:"type"`
			}
			_ = json.Unmarshal(event, &envelope)
			if !integrationMayReceiveEvent(r, envelope.Type) {
				continue
			}
			if envelope.ID != "" {
				if _, duplicate := sentIDs[envelope.ID]; duplicate {
					continue
				}
				sentIDs[envelope.ID] = struct{}{}
			}
			if !write(sseFrame(envelope.ID, event)) {
				return
			}
		}
	}
}

// integrationMayReceiveEvent applies the same least-privilege domain scopes
// to the shared event stream as to REST reads. Interactive app sessions are
// unrestricted; integration credentials fail closed for unknown event types.
func integrationMayReceiveEvent(r *http.Request, eventType string) bool {
	if !middleware.IsIntegrationCredential(r.Context()) {
		return true
	}
	domain := eventScopeDomain(eventType)
	if domain == "" {
		return false
	}
	return middleware.CredentialHasScope(r.Context(), domain+":read")
}

func eventScopeDomain(eventType string) string {
	prefix, _, _ := strings.Cut(eventType, ":")
	switch prefix {
	case "list", "shopping", "product", "store", "template":
		return "lists"
	case "chore", "subtask", "chore_template":
		return "chores"
	case "settlement", "expense", "split", "recurring_expense":
		return "finance"
	case "recipe", "collection", "meal_plan":
		return "recipes"
	case "pinwall":
		return "pinwall"
	case "notification":
		return "notifications"
	case "grocery":
		return "groceries"
	case "attachment":
		return "attachments"
	case "group", "member", "presence":
		return "groups"
	default:
		return ""
	}
}

// sseFrame keeps the old data-only wire shape for transient and legacy
// events, while adding the standard id field for durable events. Existing
// clients ignore the additional line and continue parsing data as before.
func sseFrame(id string, data []byte) string {
	if id == "" {
		return fmt.Sprintf("data: %s\n\n", data)
	}
	return fmt.Sprintf("id: %s\ndata: %s\n\n", id, data)
}
