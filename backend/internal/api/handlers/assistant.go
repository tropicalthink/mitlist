package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// AssistantHandler exposes AI assistant endpoints.
type AssistantHandler struct {
	service *services.AssistantService
}

// NewAssistantHandler creates a new AssistantHandler.
func NewAssistantHandler(service *services.AssistantService) *AssistantHandler {
	return &AssistantHandler{service: service}
}

func (h *AssistantHandler) Routes(r chi.Router) {
	r.Post("/assistant/sessions", h.CreateSession)
	r.Get("/assistant/sessions", h.ListSessions)
	r.Get("/assistant/sessions/{id}", h.GetSession)
	r.Patch("/assistant/sessions/{id}", h.UpdateSession)
	r.Delete("/assistant/sessions/{id}", h.DeleteSession)
	r.Post("/assistant/sessions/{id}/messages", h.SendMessage)
	r.Get("/assistant/sessions/{id}/messages", h.ListMessages)
}

// ---------------------------------------------------------------------------
// Request / Response DTOs
// ---------------------------------------------------------------------------

type createSessionRequest struct {
	Title string `json:"title"`
}

type updateSessionRequest struct {
	Title string `json:"title"`
}

type sendMessageRequest struct {
	Content string `json:"content"`
}

// ---------------------------------------------------------------------------
// Session handlers
// ---------------------------------------------------------------------------

func (h *AssistantHandler) CreateSession(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	var req createSessionRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if req.Title == "" {
		req.Title = "New Chat"
	}

	session, err := h.service.CreateSession(r.Context(), userID, req.Title)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, session)
}

func (h *AssistantHandler) ListSessions(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	limit, offset := parsePagination(r)
	sessions, err := h.service.ListSessions(r.Context(), userID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, sessions)
}

func (h *AssistantHandler) GetSession(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	session, err := h.service.GetSession(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, session)
}

func (h *AssistantHandler) UpdateSession(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateSessionRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if req.Title == "" {
		respondError(w, &api.ValidationError{Field: "title", Message: "title is required"})
		return
	}

	session, err := h.service.UpdateSession(r.Context(), userID, id, req.Title)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, session)
}

func (h *AssistantHandler) DeleteSession(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteSession(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// Message handlers
// ---------------------------------------------------------------------------

func (h *AssistantHandler) SendMessage(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req sendMessageRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if req.Content == "" {
		respondError(w, &api.ValidationError{Field: "content", Message: "content is required"})
		return
	}

	msg, err := h.service.SendMessage(r.Context(), userID, id, req.Content)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, msg)
}

func (h *AssistantHandler) ListMessages(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	messages, err := h.service.ListMessages(r.Context(), userID, id, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, messages)
}
