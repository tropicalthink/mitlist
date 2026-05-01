package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// CalendarHandler exposes calendar aggregation endpoints.
type CalendarHandler struct {
	service *services.CalendarService
}

// NewCalendarHandler creates a new CalendarHandler.
func NewCalendarHandler(service *services.CalendarService) *CalendarHandler {
	return &CalendarHandler{service: service}
}

// RegisterRoutes mounts calendar routes.
func (h *CalendarHandler) RegisterRoutes(r chi.Router) {
	r.Get("/calendar", h.GetCalendar)
	r.Get("/calendar/ical", h.ExportICal)
}

func (h *CalendarHandler) GetCalendar(w http.ResponseWriter, r *http.Request) {
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

	events, err := h.service.GetCalendar(r.Context(), user, groupID, from, to)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, map[string]any{"events": events})
}

func (h *CalendarHandler) ExportICal(w http.ResponseWriter, r *http.Request) {
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

	// Default to current month if no range provided
	now := time.Now()
	from, _ := time.Parse("2006-01-02", r.URL.Query().Get("from"))
	if from.IsZero() {
		from = time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
	to, _ := time.Parse("2006-01-02", r.URL.Query().Get("to"))
	if to.IsZero() {
		to = from.AddDate(0, 1, 0)
	}

	events, err := h.service.GetCalendar(r.Context(), user, groupID, from, to)
	if err != nil {
		respondError(w, err)
		return
	}

	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\r\n")
	b.WriteString("VERSION:2.0\r\n")
	b.WriteString("PRODID:-//mitlist//mitlist//EN\r\n")
	b.WriteString("CALSCALE:GREGORIAN\r\n")
	b.WriteString("METHOD:PUBLISH\r\n")

	for _, e := range events {
		uid := fmt.Sprintf("%s@mitlist", e.ID)
		start := e.Date.UTC().Format("20060102T150405Z")
		summary := e.Title
		if summary == "" {
			summary = string(e.Type)
		}
		b.WriteString("BEGIN:VEVENT\r\n")
		b.WriteString(fmt.Sprintf("UID:%s\r\n", uid))
		b.WriteString(fmt.Sprintf("DTSTART:%s\r\n", start))
		b.WriteString(fmt.Sprintf("SUMMARY:%s\r\n", icalEscape(summary)))
		b.WriteString(fmt.Sprintf("DESCRIPTION:%s\r\n", icalEscape(string(e.Type))))
		b.WriteString("END:VEVENT\r\n")
	}

	b.WriteString("END:VCALENDAR\r\n")

	w.Header().Set("Content-Type", "text/calendar; charset=utf-8")
	w.Header().Set("Content-Disposition", "attachment; filename=mitlist.ics")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(b.String()))
}

func icalEscape(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}
