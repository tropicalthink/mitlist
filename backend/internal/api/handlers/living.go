package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// LivingHandler exposes living-things endpoints.
type LivingHandler struct {
	service *services.LivingService
}

// NewLivingHandler creates a new LivingHandler.
func NewLivingHandler(service *services.LivingService) *LivingHandler {
	return &LivingHandler{service: service}
}

func (h *LivingHandler) Routes(r chi.Router) {
	r.Post("/living-things", h.CreateLivingThing)
	r.Get("/living-things", h.ListLivingThings)
	r.Get("/living-things/{id}", h.GetLivingThing)
	r.Patch("/living-things/{id}", h.UpdateLivingThing)
	r.Delete("/living-things/{id}", h.DeleteLivingThing)
	r.Post("/living-things/{id}/care-schedule", h.CreateCareSchedule)
	r.Get("/living-things/{id}/care-schedule", h.GetCareSchedule)
	r.Patch("/living-things/{id}/care-schedule", h.UpdateCareSchedule)
	r.Post("/living-things/{id}/care-logs", h.LogCare)
	r.Get("/living-things/{id}/care-logs", h.ListCareLogs)
}

func (h *LivingHandler) RegisterRoutes(r chi.Router) {
	h.Routes(r)
}

// ---------------------------------------------------------------------------
// Request / Response DTOs
// ---------------------------------------------------------------------------

type createLivingThingRequest struct {
	GroupID  string `json:"group_id"`
	Name     string `json:"name"`
	Species  string `json:"species"`
	Location string `json:"location,omitempty"`
	ImageURL string `json:"image_url,omitempty"`
}

type updateLivingThingRequest struct {
	Name     *string `json:"name,omitempty"`
	Species  *string `json:"species,omitempty"`
	Location *string `json:"location,omitempty"`
	ImageURL *string `json:"image_url,omitempty"`
}

type createCareScheduleRequest struct {
	FrequencyValue int       `json:"frequency_value"`
	FrequencyUnit  string    `json:"frequency_unit"`
	NextDue        time.Time `json:"next_due"`
}

type updateCareScheduleRequest struct {
	FrequencyValue *int        `json:"frequency_value,omitempty"`
	FrequencyUnit  *string     `json:"frequency_unit,omitempty"`
	NextDue       *time.Time   `json:"next_due,omitempty"`
}

type logCareRequest struct {
	Notes string `json:"notes,omitempty"`
}

// ---------------------------------------------------------------------------
// LivingThing handlers
// ---------------------------------------------------------------------------

func (h *LivingHandler) CreateLivingThing(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	var req createLivingThingRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	groupID, err := uuid.Parse(req.GroupID)
	if err != nil {
		respondError(w, err)
		return
	}

	lt := &models.LivingThing{
		GroupID:  groupID,
		Name:     req.Name,
		Species:  req.Species,
		Location: req.Location,
		ImageURL: req.ImageURL,
	}

	created, err := h.service.CreateLivingThing(r.Context(), userID, lt)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, created)
}

func (h *LivingHandler) ListLivingThings(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		respondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	items, err := h.service.ListLivingThings(r.Context(), userID, groupID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, items)
}

func (h *LivingHandler) GetLivingThing(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	lt, err := h.service.GetLivingThing(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, lt)
}

func (h *LivingHandler) UpdateLivingThing(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateLivingThingRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetLivingThing(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Species != nil {
		existing.Species = *req.Species
	}
	if req.Location != nil {
		existing.Location = *req.Location
	}
	if req.ImageURL != nil {
		existing.ImageURL = *req.ImageURL
	}

	updated, err := h.service.UpdateLivingThing(r.Context(), userID, existing)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, updated)
}

func (h *LivingHandler) DeleteLivingThing(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteLivingThing(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---------------------------------------------------------------------------
// CareSchedule handlers
// ---------------------------------------------------------------------------

func (h *LivingHandler) CreateCareSchedule(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	livingThingID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req createCareScheduleRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	cs := &models.CareSchedule{
		LivingThingID:  livingThingID,
		FrequencyValue: req.FrequencyValue,
		FrequencyUnit:  req.FrequencyUnit,
		NextDue:        req.NextDue,
	}

	created, err := h.service.CreateCareSchedule(r.Context(), userID, cs)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, created)
}

func (h *LivingHandler) GetCareSchedule(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	livingThingID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	cs, err := h.service.GetCareScheduleByLivingThing(r.Context(), userID, livingThingID)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, cs)
}

func (h *LivingHandler) UpdateCareSchedule(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	livingThingID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateCareScheduleRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetCareScheduleByLivingThing(r.Context(), userID, livingThingID)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.FrequencyValue != nil {
		existing.FrequencyValue = *req.FrequencyValue
	}
	if req.FrequencyUnit != nil {
		existing.FrequencyUnit = *req.FrequencyUnit
	}
	if req.NextDue != nil {
		existing.NextDue = *req.NextDue
	}

	updated, err := h.service.UpdateCareScheduleByLivingThing(r.Context(), userID, livingThingID, existing)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, updated)
}

// ---------------------------------------------------------------------------
// CareLog handlers
// ---------------------------------------------------------------------------

func (h *LivingHandler) LogCare(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	livingThingID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req logCareRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	// Find the care schedule for this living thing.
	cs, err := h.service.GetCareScheduleByLivingThing(r.Context(), userID, livingThingID)
	if err != nil {
		respondError(w, err)
		return
	}

	cl := &models.CareLog{
		CareScheduleID: cs.ID,
		UserID:         userID,
		Notes:          req.Notes,
	}

	created, err := h.service.LogCare(r.Context(), userID, cl)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusCreated, created)
}

func (h *LivingHandler) ListCareLogs(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	livingThingID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	logs, err := h.service.ListCareLogsByLivingThing(r.Context(), userID, livingThingID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}
	respondJSON(w, http.StatusOK, logs)
}
