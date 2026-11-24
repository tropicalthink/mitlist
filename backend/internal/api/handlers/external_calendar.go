package handlers

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// ExternalCalendarHandler exposes members' synced calendars: connections,
// device uploads, household shares and event overrides. Every route needs
// an interactive session.
type ExternalCalendarHandler struct {
	service *services.ExternalCalendarService
}

func NewExternalCalendarHandler(service *services.ExternalCalendarService) *ExternalCalendarHandler {
	return &ExternalCalendarHandler{service: service}
}

func (h *ExternalCalendarHandler) RegisterRoutes(r chi.Router) {
	r.Group(func(r chi.Router) {
		r.Use(requireInteractiveSession)
		r.Get("/calendar/external/connections", h.ListConnections)
		r.Post("/calendar/external/connections", h.CreateConnection)
		r.Patch("/calendar/external/connections/{id}", h.RenameConnection)
		r.Delete("/calendar/external/connections/{id}", h.DeleteConnection)
		r.Post("/calendar/external/connections/{id}/sync", h.SyncConnection)
		r.Put("/calendar/external/connections/{id}/device-sync", h.DeviceSync)
		r.Put("/calendar/external/calendars/{id}/shares", h.ReplaceShares)
		r.Get("/calendar/external/events/mine", h.ListMyEvents)
		r.Get("/calendar/external/overrides", h.ListOverrides)
		r.Put("/calendar/external/overrides", h.SetOverride)
	})
}

// requireInteractiveSession refuses widget and integration credentials,
// as the credential-management routes do: a scoped token must never read
// or change someone's private calendars.
func requireInteractiveSession(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if middleware.IsIntegrationCredential(r.Context()) {
			api.RespondError(w, &api.PermissionDeniedError{Message: "calendar sharing requires an interactive session"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

var calendarSyncMessages = map[string]string{
	models.CalendarErrFetchFailed:  "The calendar link could not be fetched.",
	models.CalendarErrNotCalendar:  "That link is not a calendar (iCal) feed.",
	models.CalendarErrTooLarge:     "That calendar is too large to sync.",
	models.CalendarErrUnauthorized: "The calendar link was refused. It may have been reset.",
}

// respondExternalCalendarError adds the feature's two own statuses: 422
// with the sync code, and 429 for a sync too soon after the last one.
func respondExternalCalendarError(w http.ResponseWriter, err error) {
	var se *services.CalendarSyncError
	if errors.As(err, &se) {
		api.RespondJSON(w, http.StatusUnprocessableEntity, api.ErrorResponse{Error: se.Code, Message: calendarSyncMessages[se.Code]})
		return
	}
	if errors.Is(err, services.ErrSyncTooSoon) {
		api.RespondJSON(w, http.StatusTooManyRequests, api.ErrorResponse{Error: "rate_limited", Message: "This calendar synced less than a minute ago."})
		return
	}
	api.RespondError(w, err)
}

func (h *ExternalCalendarHandler) ListConnections(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	conns, err := h.service.ListConnections(r.Context(), user.ID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"connections": conns})
}

type createCalendarConnectionRequest struct {
	Kind     string `json:"kind"`
	Name     string `json:"name"`
	URL      string `json:"url"`
	DeviceID string `json:"device_id"`
}

func (h *ExternalCalendarHandler) CreateConnection(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req createCalendarConnectionRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	switch req.Kind {
	case models.CalendarConnectionICS:
		conn, err := h.service.CreateICSConnection(r.Context(), user.ID, req.Name, req.URL)
		if err != nil {
			respondExternalCalendarError(w, err)
			return
		}
		api.RespondJSON(w, http.StatusCreated, conn)
	case models.CalendarConnectionDevice:
		conn, created, err := h.service.UpsertDeviceConnection(r.Context(), user.ID, req.Name, req.DeviceID)
		if err != nil {
			respondExternalCalendarError(w, err)
			return
		}
		status := http.StatusOK
		if created {
			status = http.StatusCreated
		}
		api.RespondJSON(w, status, conn)
	default:
		api.RespondError(w, &api.ValidationError{Field: "kind", Message: "kind must be ics or device"})
	}
}

type renameCalendarConnectionRequest struct {
	Name string `json:"name"`
}

func (h *ExternalCalendarHandler) RenameConnection(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req renameCalendarConnectionRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	conn, err := h.service.RenameConnection(r.Context(), user.ID, id, req.Name)
	if err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, conn)
}

func (h *ExternalCalendarHandler) DeleteConnection(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if err := h.service.DeleteConnection(r.Context(), user.ID, id); err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ExternalCalendarHandler) SyncConnection(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	conn, err := h.service.SyncNow(r.Context(), user.ID, id)
	if err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, conn)
}

// maxDeviceSyncBody fits 5000 events with titles; the usual 1 MB body
// limit does not.
const maxDeviceSyncBody = 8 << 20

func (h *ExternalCalendarHandler) DeviceSync(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req services.DeviceSyncInput
	defer r.Body.Close()
	dec := json.NewDecoder(io.LimitReader(r.Body, maxDeviceSyncBody))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid JSON body"})
		return
	}
	conn, err := h.service.DeviceSync(r.Context(), user.ID, id, req)
	if err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, conn)
}

type replaceSharesRequest struct {
	Shares []models.CalendarShare `json:"shares"`
}

func (h *ExternalCalendarHandler) ReplaceShares(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	var req replaceSharesRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	cal, err := h.service.ReplaceShares(r.Context(), user.ID, id, req.Shares)
	if err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, cal)
}

// parseCalendarBound reads an RFC 3339 timestamp or a YYYY-MM-DD date.
func parseCalendarBound(raw string) (time.Time, bool) {
	if t, err := time.Parse(time.RFC3339, raw); err == nil {
		return t.UTC(), true
	}
	if t, err := time.Parse("2006-01-02", raw); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func (h *ExternalCalendarHandler) ListMyEvents(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	now := time.Now().UTC()
	from, to := now.Add(-24*time.Hour), now.Add(90*24*time.Hour)
	if raw := r.URL.Query().Get("from"); raw != "" {
		t, ok := parseCalendarBound(raw)
		if !ok {
			api.RespondError(w, &api.ValidationError{Field: "from", Message: "expected RFC 3339 or YYYY-MM-DD"})
			return
		}
		from = t
	}
	if raw := r.URL.Query().Get("to"); raw != "" {
		t, ok := parseCalendarBound(raw)
		if !ok {
			api.RespondError(w, &api.ValidationError{Field: "to", Message: "expected RFC 3339 or YYYY-MM-DD"})
			return
		}
		to = t
		if len(raw) == len("2006-01-02") {
			// A date is the last day shown.
			to = t.AddDate(0, 0, 1)
		}
	}
	events, err := h.service.ListOwnEvents(r.Context(), user.ID, from, to)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"events": events})
}

func (h *ExternalCalendarHandler) ListOverrides(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	overrides, err := h.service.ListOverrides(r.Context(), user.ID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"overrides": overrides})
}

type setOverrideRequest struct {
	CalendarID  uuid.UUID `json:"calendar_id"`
	ExternalUID string    `json:"external_uid"`
	Visibility  *string   `json:"visibility"`
}

func (h *ExternalCalendarHandler) SetOverride(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req setOverrideRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}
	if req.CalendarID == uuid.Nil {
		api.RespondError(w, &api.ValidationError{Field: "calendar_id", Message: "calendar_id is required"})
		return
	}
	if err := h.service.SetOverride(r.Context(), user.ID, req.CalendarID, req.ExternalUID, req.Visibility); err != nil {
		respondExternalCalendarError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
