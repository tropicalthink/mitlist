package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

type ExpenseReceiptHandler struct {
	service *services.ExpenseReceiptService
}

func NewExpenseReceiptHandler(service *services.ExpenseReceiptService) *ExpenseReceiptHandler {
	return &ExpenseReceiptHandler{service: service}
}

func (h *ExpenseReceiptHandler) RegisterRoutes(r chi.Router) {
	r.Post("/expenses/{id}/receipts", h.AttachReceipt)
	r.Get("/expenses/{id}/receipts", h.ListReceipts)
	r.Delete("/expenses/{id}/receipts/{attachment_id}", h.DetachReceipt)
}

func (h *ExpenseReceiptHandler) AttachReceipt(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	expenseID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	var req struct {
		GroupID      uuid.UUID `json:"group_id"`
		AttachmentID uuid.UUID `json:"attachment_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.Attach(r.Context(), user.ID, req.GroupID, expenseID, req.AttachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

func (h *ExpenseReceiptHandler) ListReceipts(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	expenseID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	out, err := h.service.List(r.Context(), user.ID, groupID, expenseID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, out)
}

func (h *ExpenseReceiptHandler) DetachReceipt(w http.ResponseWriter, r *http.Request) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	expenseID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	attachmentID, err := uuid.Parse(chi.URLParam(r, "attachment_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "attachment_id", Message: "invalid attachment id"})
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	if err := h.service.Detach(r.Context(), user.ID, groupID, expenseID, attachmentID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

