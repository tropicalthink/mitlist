package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// MealPlanHandler exposes meal plan endpoints.
type MealPlanHandler struct {
	service *services.MealPlanService
}

// NewMealPlanHandler creates a new MealPlanHandler.
func NewMealPlanHandler(service *services.MealPlanService) *MealPlanHandler {
	return &MealPlanHandler{service: service}
}

func (h *MealPlanHandler) RegisterRoutes(r chi.Router) {
	r.Post("/meal-plans", h.CreateMealPlan)
	r.Get("/meal-plans", h.ListMealPlans)
	r.Get("/meal-plans/{id}", h.GetMealPlan)
	r.Patch("/meal-plans/{id}", h.UpdateMealPlan)
	r.Delete("/meal-plans/{id}", h.DeleteMealPlan)
}

type createMealPlanRequest struct {
	GroupID    uuid.UUID  `json:"group_id"`
	Date       string     `json:"date"`
	Slot       string     `json:"slot"`
	RecipeID   uuid.UUID  `json:"recipe_id"`
	Servings   int        `json:"servings"`
	CookUserID *uuid.UUID `json:"cook_user_id"`
}

func (h *MealPlanHandler) CreateMealPlan(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	var req createMealPlanRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "date", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}

	mp := &models.MealPlan{
		GroupID:    req.GroupID,
		Date:       date,
		Slot:       req.Slot,
		RecipeID:   req.RecipeID,
		Servings:   req.Servings,
		CookUserID: req.CookUserID,
	}

	if err := h.service.CreateMealPlan(r.Context(), user, mp); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, mp)
}

func (h *MealPlanHandler) ListMealPlans(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		respondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	fromStr := r.URL.Query().Get("from")
	toStr := r.URL.Query().Get("to")
	if fromStr == "" || toStr == "" {
		respondError(w, &api.ValidationError{Field: "from,to", Message: "from and to dates are required"})
		return
	}

	from, err := time.Parse("2006-01-02", fromStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "from", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}
	to, err := time.Parse("2006-01-02", toStr)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "to", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}

	plans, err := h.service.ListMealPlans(r.Context(), user, groupID, from, to)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, plans)
}

func (h *MealPlanHandler) GetMealPlan(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	mp, err := h.service.GetMealPlan(r.Context(), user, id)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, mp)
}

type updateMealPlanRequest struct {
	Date       *string    `json:"date,omitempty"`
	Slot       *string    `json:"slot,omitempty"`
	RecipeID   *uuid.UUID `json:"recipe_id,omitempty"`
	Servings   *int       `json:"servings,omitempty"`
	CookUserID *uuid.UUID `json:"cook_user_id,omitempty"`
}

func (h *MealPlanHandler) UpdateMealPlan(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateMealPlanRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetMealPlan(r.Context(), user, id)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.Date != nil {
		date, err := time.Parse("2006-01-02", *req.Date)
		if err != nil {
			respondError(w, &api.ValidationError{Field: "date", Message: "invalid date format"})
			return
		}
		existing.Date = date
	}
	if req.Slot != nil {
		existing.Slot = *req.Slot
	}
	if req.RecipeID != nil {
		existing.RecipeID = *req.RecipeID
	}
	if req.Servings != nil {
		existing.Servings = *req.Servings
	}
	if req.CookUserID != nil {
		existing.CookUserID = req.CookUserID
	}

	if err := h.service.UpdateMealPlan(r.Context(), user, existing); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, existing)
}

func (h *MealPlanHandler) DeleteMealPlan(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteMealPlan(r.Context(), user, id); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// GenerateShoppingList handles POST /api/v1/meal-plans/generate-shopping-list.
func (h *MealPlanHandler) GenerateShoppingList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID uuid.UUID  `json:"group_id"`
		From    string     `json:"from"`
		To      string     `json:"to"`
		ListID  *uuid.UUID `json:"list_id,omitempty"`
	}
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	from, err := time.Parse("2006-01-02", req.From)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "from", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}
	to, err := time.Parse("2006-01-02", req.To)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "to", Message: "invalid date format, expected YYYY-MM-DD"})
		return
	}

	list, items, err := h.service.GenerateShoppingList(r.Context(), user, req.GroupID, from, to, req.ListID)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{
		"list":  list,
		"items": items,
	})
}
