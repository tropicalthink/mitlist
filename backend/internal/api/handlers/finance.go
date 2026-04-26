package handlers

import (
	"encoding/csv"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// FinanceHandler exposes expense, split, settlement and recurring expense endpoints.
type FinanceHandler struct {
	service *services.FinanceService
}

// NewFinanceHandler creates a new FinanceHandler.
func NewFinanceHandler(service *services.FinanceService) *FinanceHandler {
	return &FinanceHandler{service: service}
}

func (h *FinanceHandler) userID(r *http.Request) (uuid.UUID, bool) {
	user, ok := api.UserFromContext(r.Context())
	if !ok {
		return uuid.Nil, false
	}
	return user.ID, true
}

// ------------------------------------------------------------------
// Expenses
// ------------------------------------------------------------------

// CreateExpense POST /api/v1/expenses
func (h *FinanceHandler) CreateExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID      uuid.UUID   `json:"group_id"`
		PayerID      uuid.UUID   `json:"payer_id"`
		Amount       int64       `json:"amount"`
		Description  string      `json:"description"`
		Category     string      `json:"category"`
		Currency     string      `json:"currency"`
		Notes        string      `json:"notes"`
		Date         time.Time   `json:"date"`
		SplitUserIDs []uuid.UUID `json:"split_user_ids"`
		SplitMode    string      `json:"split_mode"`
		Splits       []struct {
			UserID     uuid.UUID `json:"user_id"`
			Amount     int64     `json:"amount"`
			Shares     int64     `json:"shares"`
			Percentage int64     `json:"percentage"`
		} `json:"splits"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	expense := &models.Expense{
		GroupID:     req.GroupID,
		PayerID:     req.PayerID,
		Amount:      req.Amount,
		Description: req.Description,
		Category:    req.Category,
		Currency:    req.Currency,
		Notes:       req.Notes,
		Date:        req.Date,
	}
	splits := make([]services.ExpenseSplitInput, 0, len(req.Splits)+len(req.SplitUserIDs))
	for _, split := range req.Splits {
		splits = append(splits, services.ExpenseSplitInput{
			UserID:     split.UserID,
			Amount:     split.Amount,
			Shares:     split.Shares,
			Percentage: split.Percentage,
		})
	}
	if len(splits) == 0 {
		for _, splitUserID := range req.SplitUserIDs {
			splits = append(splits, services.ExpenseSplitInput{UserID: splitUserID})
		}
	}
	if err := h.service.CreateExpenseWithSplitMode(r.Context(), userID, expense, req.SplitMode, splits); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, expense)
}

// ListExpenses GET /api/v1/expenses
func (h *FinanceHandler) ListExpenses(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	limit, offset := parsePagination(r)

	expenses, err := h.service.ListExpenses(r.Context(), userID, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, expenses)
}

// GetFinanceSummary GET /api/v1/finance/summary
func (h *FinanceHandler) GetFinanceSummary(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	summary, err := h.service.GetFinanceSummary(r.Context(), userID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, summary)
}

// GetExpense GET /api/v1/expenses/{id}
func (h *FinanceHandler) GetExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	expense, err := h.service.GetExpense(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, expense)
}

// UpdateExpense PATCH /api/v1/expenses/{id}
func (h *FinanceHandler) UpdateExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	var req struct {
		PayerID     *uuid.UUID `json:"payer_id,omitempty"`
		Amount      *int64     `json:"amount,omitempty"`
		Description *string    `json:"description,omitempty"`
		Category    *string    `json:"category,omitempty"`
		Currency    *string    `json:"currency,omitempty"`
		Notes       *string    `json:"notes,omitempty"`
		Date        *time.Time `json:"date,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	existing, err := h.service.GetExpense(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if req.PayerID != nil {
		existing.PayerID = *req.PayerID
	}
	if req.Amount != nil {
		existing.Amount = *req.Amount
	}
	if req.Description != nil {
		existing.Description = *req.Description
	}
	if req.Category != nil {
		existing.Category = *req.Category
	}
	if req.Currency != nil {
		existing.Currency = *req.Currency
	}
	if req.Notes != nil {
		existing.Notes = *req.Notes
	}
	if req.Date != nil {
		existing.Date = *req.Date
	}

	if err := h.service.UpdateExpense(r.Context(), userID, existing); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, existing)
}

// ExportExpensesJSON GET /api/v1/finance/export/json
func (h *FinanceHandler) ExportExpensesJSON(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	expenses, err := h.service.ListAllExpenses(r.Context(), userID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, expenses)
}

// ExportExpensesCSV GET /api/v1/finance/export/csv
func (h *FinanceHandler) ExportExpensesCSV(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	expenses, err := h.service.ListAllExpenses(r.Context(), userID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="expenses.csv"`)
	writer := csv.NewWriter(w)
	_ = writer.Write([]string{"id", "group_id", "payer_id", "amount", "description", "category", "currency", "notes", "date", "created_at"})
	for _, expense := range expenses {
		_ = writer.Write([]string{
			expense.ID.String(),
			expense.GroupID.String(),
			expense.PayerID.String(),
			strconv.FormatInt(expense.Amount, 10),
			expense.Description,
			expense.Category,
			expense.Currency,
			expense.Notes,
			expense.Date.Format(time.RFC3339),
			expense.CreatedAt.Format(time.RFC3339),
		})
	}
	writer.Flush()
}

// DeleteExpense DELETE /api/v1/expenses/{id}
func (h *FinanceHandler) DeleteExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	if err := h.service.DeleteExpense(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// ------------------------------------------------------------------
// Splits
// ------------------------------------------------------------------

// CreateSplit POST /api/v1/expenses/{id}/splits
func (h *FinanceHandler) CreateSplit(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
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
		UserID uuid.UUID `json:"user_id"`
		Amount int64     `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	split := &models.Split{
		ExpenseID: expenseID,
		UserID:    req.UserID,
		Amount:    req.Amount,
	}
	if err := h.service.CreateSplit(r.Context(), userID, split); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, split)
}

// UpdateSplit PATCH /api/v1/expenses/{id}/splits/{split_id}
func (h *FinanceHandler) UpdateSplit(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	splitID, err := uuid.Parse(chi.URLParam(r, "split_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "split_id", Message: "invalid split id"})
		return
	}

	var req struct {
		UserID *uuid.UUID `json:"user_id,omitempty"`
		Amount *int64     `json:"amount,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	existing, err := h.service.GetSplit(r.Context(), userID, splitID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if req.UserID != nil {
		existing.UserID = *req.UserID
	}
	if req.Amount != nil {
		existing.Amount = *req.Amount
	}

	if err := h.service.UpdateSplit(r.Context(), userID, existing); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, existing)
}

// DeleteSplit DELETE /api/v1/expenses/{id}/splits/{split_id}
func (h *FinanceHandler) DeleteSplit(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	_, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}
	splitID, err := uuid.Parse(chi.URLParam(r, "split_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "split_id", Message: "invalid split id"})
		return
	}

	if err := h.service.DeleteSplit(r.Context(), userID, splitID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// ------------------------------------------------------------------
// Settlements
// ------------------------------------------------------------------

// CreateGroupSettlement POST /api/v1/finance/settlements
func (h *FinanceHandler) CreateGroupSettlement(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID    uuid.UUID `json:"group_id"`
		FromUserID uuid.UUID `json:"from_user_id"`
		ToUserID   uuid.UUID `json:"to_user_id"`
		Amount     int64     `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	settlement := &models.Settlement{
		GroupID:    req.GroupID,
		FromUserID: req.FromUserID,
		ToUserID:   req.ToUserID,
		Amount:     req.Amount,
	}
	if err := h.service.CreateSettlement(r.Context(), userID, settlement); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, settlement)
}

// CreateSettlement POST /api/v1/expenses/{id}/settle
func (h *FinanceHandler) CreateSettlement(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	expenseID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}

	// Resolve group_id from the expense for REST consistency.
	expense, err := h.service.GetExpense(r.Context(), userID, expenseID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	var req struct {
		FromUserID uuid.UUID `json:"from_user_id"`
		ToUserID   uuid.UUID `json:"to_user_id"`
		Amount     int64     `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	settlement := &models.Settlement{
		GroupID:    expense.GroupID,
		FromUserID: req.FromUserID,
		ToUserID:   req.ToUserID,
		Amount:     req.Amount,
	}
	if err := h.service.CreateSettlement(r.Context(), userID, settlement); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, settlement)
}

// DeleteSettlement DELETE /api/v1/expenses/{id}/settle/{settlement_id}
func (h *FinanceHandler) DeleteSettlement(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	_, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid expense id"})
		return
	}
	settlementID, err := uuid.Parse(chi.URLParam(r, "settlement_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "settlement_id", Message: "invalid settlement id"})
		return
	}

	if err := h.service.DeleteSettlement(r.Context(), userID, settlementID); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}

// ------------------------------------------------------------------
// Recurring Expenses
// ------------------------------------------------------------------

// CreateRecurringExpense POST /api/v1/recurring-expenses
func (h *FinanceHandler) CreateRecurringExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID     uuid.UUID `json:"group_id"`
		PayerID     uuid.UUID `json:"payer_id"`
		Amount      int64     `json:"amount"`
		Description string    `json:"description"`
		Category    string    `json:"category"`
		Frequency   string    `json:"frequency"`
		NextDue     time.Time `json:"next_due"`
		IsActive    bool      `json:"is_active"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	re := &models.RecurringExpense{
		GroupID:     req.GroupID,
		PayerID:     req.PayerID,
		Amount:      req.Amount,
		Description: req.Description,
		Category:    req.Category,
		Frequency:   req.Frequency,
		NextDue:     req.NextDue,
		IsActive:    req.IsActive,
	}
	if err := h.service.CreateRecurringExpense(r.Context(), userID, re); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, re)
}

// ListRecurringExpenses GET /api/v1/recurring-expenses
func (h *FinanceHandler) ListRecurringExpenses(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "valid group_id required"})
		return
	}

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 {
		limit = 50
	}
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	expenses, err := h.service.ListRecurringExpenses(r.Context(), userID, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, expenses)
}

// GetRecurringExpense GET /api/v1/recurring-expenses/{id}
func (h *FinanceHandler) GetRecurringExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid recurring expense id"})
		return
	}

	re, err := h.service.GetRecurringExpense(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, re)
}

// UpdateRecurringExpense PATCH /api/v1/recurring-expenses/{id}
func (h *FinanceHandler) UpdateRecurringExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid recurring expense id"})
		return
	}

	var req struct {
		PayerID     *uuid.UUID `json:"payer_id,omitempty"`
		Amount      *int64     `json:"amount,omitempty"`
		Description *string    `json:"description,omitempty"`
		Category    *string    `json:"category,omitempty"`
		Frequency   *string    `json:"frequency,omitempty"`
		NextDue     *time.Time `json:"next_due,omitempty"`
		IsActive    *bool      `json:"is_active,omitempty"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	existing, err := h.service.GetRecurringExpense(r.Context(), userID, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if req.PayerID != nil {
		existing.PayerID = *req.PayerID
	}
	if req.Amount != nil {
		existing.Amount = *req.Amount
	}
	if req.Description != nil {
		existing.Description = *req.Description
	}
	if req.Category != nil {
		existing.Category = *req.Category
	}
	if req.Frequency != nil {
		existing.Frequency = *req.Frequency
	}
	if req.NextDue != nil {
		existing.NextDue = *req.NextDue
	}
	if req.IsActive != nil {
		existing.IsActive = *req.IsActive
	}

	re := &models.RecurringExpense{
		ID:          id,
		PayerID:     existing.PayerID,
		Amount:      existing.Amount,
		Description: existing.Description,
		Category:    existing.Category,
		Frequency:   existing.Frequency,
		NextDue:     existing.NextDue,
		IsActive:    existing.IsActive,
	}
	if err := h.service.UpdateRecurringExpense(r.Context(), userID, re); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, re)
}

// DeleteRecurringExpense DELETE /api/v1/recurring-expenses/{id}
func (h *FinanceHandler) DeleteRecurringExpense(w http.ResponseWriter, r *http.Request) {
	userID, ok := h.userID(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid recurring expense id"})
		return
	}

	if err := h.service.DeleteRecurringExpense(r.Context(), userID, id); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusNoContent, nil)
}
