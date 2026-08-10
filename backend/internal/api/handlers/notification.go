package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// NotificationHandler exposes notification endpoints.
type NotificationHandler struct {
	service *services.NotificationService
}

type updateNotificationPreferencesRequest struct {
	GroupID         *uuid.UUID `json:"group_id"`
	ChoreDue        *bool      `json:"chore_due"`
	ChoreDueDayOf   *bool      `json:"chore_due_day_of"`
	ListItemAdded   *bool      `json:"list_item_added"`
	ExpenseCreated  *bool      `json:"expense_created"`
	MealPlanChanged *bool      `json:"meal_plan_changed"`
	WeeklyDigest    *bool      `json:"weekly_digest"`
	PinwallReminder *bool      `json:"pinwall_reminder"`
	PushEnabled     *bool      `json:"push_enabled"`
	EmailEnabled    *bool      `json:"email_enabled"`
}

// NewNotificationHandler creates a new NotificationHandler.
func NewNotificationHandler(service *services.NotificationService) *NotificationHandler {
	return &NotificationHandler{service: service}
}

func (h *NotificationHandler) RegisterRoutes(r chi.Router) {
	r.Get("/notifications", h.ListNotifications)
	r.Get("/notifications/unread-count", h.CountUnreadNotifications)
	r.Get("/notifications/{id}", h.GetNotification)
	r.Patch("/notifications/{id}/read", h.MarkAsRead)
	r.Patch("/notifications/read-all", h.MarkAllAsRead)
	r.Delete("/notifications/{id}", h.DeleteNotification)
	r.Get("/notifications/preferences", h.GetPreferences)
	r.Patch("/notifications/preferences", h.UpdatePreferences)
}

func (h *NotificationHandler) CountUnreadNotifications(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	count, err := h.service.CountUnreadNotifications(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]int{"count": count})
}

func (h *NotificationHandler) ListNotifications(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	beforeCreatedAt := r.URL.Query().Get("before_created_at")
	beforeIDRaw := r.URL.Query().Get("before_id")
	var notifications []models.Notification
	if beforeCreatedAt != "" || beforeIDRaw != "" {
		if beforeCreatedAt == "" || beforeIDRaw == "" {
			api.RespondError(w, &api.ValidationError{Field: "cursor", Message: "before_created_at and before_id must be provided together"})
			return
		}
		before, parseErr := time.Parse(time.RFC3339Nano, beforeCreatedAt)
		if parseErr != nil {
			api.RespondError(w, &api.ValidationError{Field: "before_created_at", Message: "invalid timestamp"})
			return
		}
		beforeID, parseErr := uuid.Parse(beforeIDRaw)
		if parseErr != nil {
			api.RespondError(w, &api.ValidationError{Field: "before_id", Message: "invalid UUID"})
			return
		}
		notifications, err = h.service.ListNotificationsBefore(r.Context(), userID, before, beforeID, limit)
	} else {
		notifications, err = h.service.ListNotifications(r.Context(), userID, limit, offset)
	}
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, notifications)
}

func (h *NotificationHandler) GetNotification(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	n, err := h.service.GetNotification(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, n)
}

func (h *NotificationHandler) MarkAsRead(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if err := h.service.MarkAsRead(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *NotificationHandler) MarkAllAsRead(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if err := h.service.MarkAllAsRead(r.Context(), userID); err != nil {
		api.RespondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *NotificationHandler) DeleteNotification(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if err := h.service.DeleteNotification(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *NotificationHandler) GetPreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr != "" {
		groupID, err := uuid.Parse(groupIDStr)
		if err != nil {
			api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid group_id"})
			return
		}
		pref, err := h.service.GetGroupPreference(r.Context(), userID, groupID)
		if err != nil {
			api.RespondError(w, err)
			return
		}
		api.RespondJSON(w, http.StatusOK, pref)
		return
	}

	prefs, err := h.service.GetPreferences(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, prefs)
}

func (h *NotificationHandler) UpdatePreferences(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req updateNotificationPreferencesRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	if req.GroupID == nil || *req.GroupID == uuid.Nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	pref, err := h.service.GetGroupPreference(r.Context(), userID, *req.GroupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	applyBool := func(value *bool, target *bool) {
		if value != nil {
			*target = *value
		}
	}
	applyBool(req.ChoreDue, &pref.ChoreDue)
	applyBool(req.ChoreDueDayOf, &pref.ChoreDueDayOf)
	applyBool(req.ListItemAdded, &pref.ListItemAdded)
	applyBool(req.ExpenseCreated, &pref.ExpenseCreated)
	applyBool(req.MealPlanChanged, &pref.MealPlanChanged)
	applyBool(req.WeeklyDigest, &pref.WeeklyDigest)
	applyBool(req.PinwallReminder, &pref.PinwallReminder)
	applyBool(req.PushEnabled, &pref.PushEnabled)
	applyBool(req.EmailEnabled, &pref.EmailEnabled)

	if err := h.service.UpdatePreferences(r.Context(), userID, pref); err != nil {
		api.RespondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
