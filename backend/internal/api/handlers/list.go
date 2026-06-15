package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// userFromContext retrieves the current user from context using the api package key.
func userFromContext(r *http.Request) (*models.User, bool) {
	return api.UserFromContext(r.Context())
}

// ListHandler handles list-related HTTP endpoints.
type ListHandler struct {
	service         *services.ListService
	financeService  *services.FinanceService
}

// NewListHandler creates a new ListHandler.
func NewListHandler(service *services.ListService, financeService *services.FinanceService) *ListHandler {
	return &ListHandler{service: service, financeService: financeService}
}

// RegisterRoutes mounts all list, shopping, and product routes.
func (h *ListHandler) RegisterRoutes(r chi.Router) {
	r.Post("/lists", h.CreateList)
	r.Get("/lists", h.ListLists)
	r.Post("/shopping-locations", h.CreateShoppingLocation)
	r.Get("/shopping-locations", h.ListShoppingLocations)
	r.Post("/products", h.CreateProduct)
	r.Get("/products", h.ListProducts)
	r.Get("/lists/{id}", h.GetList)
	r.Patch("/lists/{id}", h.UpdateList)
	r.Delete("/lists/{id}", h.DeleteList)
	r.Post("/lists/{id}/items", h.CreateItem)
	r.Get("/lists/{id}/items", h.ListItems)
	r.Post("/lists/{id}/items/clear", h.ClearItems)
	r.Post("/lists/{id}/items/add", h.AddItemAmount)
	r.Post("/lists/{id}/items/remove", h.RemoveItemAmount)
	r.Patch("/lists/{id}/items/{item_id}", h.UpdateItem)
	r.Delete("/lists/{id}/items/{item_id}", h.DeleteItem)
	r.Post("/lists/{id}/reorder", h.ReorderItems)
	r.Get("/lists/{id}/cost-summary", h.GetCostSummary)
	r.Post("/lists/{id}/generate-expense", h.GenerateExpense)
	r.Get("/shopping/trip", h.GetShoppingTrip)
	r.Post("/shopping/complete", h.BulkCompleteItems)
	r.Post("/lists/{id}/archive", h.ArchiveList)
	r.Post("/lists/{id}/unarchive", h.UnarchiveList)
	r.Post("/lists/{id}/items/{item_id}/claim", h.ClaimItem)
	r.Post("/lists/{id}/items/{item_id}/unclaim", h.UnclaimItem)
}

// CreateList handles POST /api/v1/lists.
func (h *ListHandler) CreateList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		GroupID uuid.UUID `json:"group_id"`
		Name    string    `json:"name"`
		Type    string    `json:"type"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	list := &models.List{
		GroupID: req.GroupID,
		Name:    req.Name,
		Type:    req.Type,
	}
	if err := h.service.CreateList(r.Context(), user, list); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, list)
}

// ListLists handles GET /api/v1/lists.
func (h *ListHandler) ListLists(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	groupIDStr := r.URL.Query().Get("group_id")
	if groupIDStr == "" {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id is required"})
		return
	}

	groupID, err := uuid.Parse(groupIDStr)
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}

	limit, offset := parsePagination(r)
	lists, err := h.service.ListLists(r.Context(), user, groupID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, lists)
}

func (h *ListHandler) CreateShoppingLocation(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req struct {
		GroupID   uuid.UUID `json:"group_id"`
		Name      string    `json:"name"`
		SortOrder int       `json:"sort_order"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	location := &models.ShoppingLocation{GroupID: req.GroupID, Name: req.Name, SortOrder: req.SortOrder}
	if err := h.service.CreateShoppingLocation(r.Context(), user, location); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, location)
}

func (h *ListHandler) ListShoppingLocations(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}
	locations, err := h.service.ListShoppingLocations(r.Context(), user, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, locations)
}

func (h *ListHandler) CreateProduct(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	var req struct {
		GroupID  uuid.UUID  `json:"group_id"`
		Name     string     `json:"name"`
		Barcode  string     `json:"barcode"`
		Unit     string     `json:"unit"`
		StoreID  *uuid.UUID `json:"store_id"`
		MinStock float64    `json:"min_stock"`
		InStock  float64    `json:"in_stock"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}
	product := &models.Product{
		GroupID: req.GroupID, Name: req.Name, Barcode: req.Barcode, Unit: req.Unit,
		StoreID: req.StoreID, MinStock: req.MinStock, InStock: req.InStock,
	}
	if err := h.service.CreateProduct(r.Context(), user, product); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, product)
}

func (h *ListHandler) ListProducts(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	groupID, err := uuid.Parse(r.URL.Query().Get("group_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "invalid UUID"})
		return
	}
	searchQuery := r.URL.Query().Get("search")
	var products []models.Product
	if searchQuery != "" {
		products, err = h.service.SearchProducts(r.Context(), user, groupID, searchQuery)
	} else {
		products, err = h.service.ListProducts(r.Context(), user, groupID)
	}
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, products)
}

// GetList handles GET /api/v1/lists/{id}.
func (h *ListHandler) GetList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	list, err := h.service.GetList(r.Context(), user, id)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, list)
}

// UpdateList handles PATCH /api/v1/lists/{id}.
func (h *ListHandler) UpdateList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Name string `json:"name"`
		Type string `json:"type"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	list, err := h.service.UpdateList(r.Context(), user, id, req.Name, req.Type)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, list)
}

// DeleteList handles DELETE /api/v1/lists/{id}.
func (h *ListHandler) DeleteList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	if err := h.service.DeleteList(r.Context(), user, id); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// CreateItem handles POST /api/v1/lists/{id}/items.
func (h *ListHandler) CreateItem(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Name            string     `json:"name"`
		Quantity        float64    `json:"quantity"`
		Unit            string     `json:"unit"`
		Note            string     `json:"note"`
		PriceCents      *int       `json:"price_cents"`
		ProductID       *uuid.UUID `json:"product_id"`
		StoreID         *uuid.UUID `json:"store_id"`
		CanonicalItemID *uuid.UUID `json:"canonical_item_id"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	item := &models.ListItem{
		ListID:          listID,
		Name:            req.Name,
		Quantity:        req.Quantity,
		Unit:            req.Unit,
		Note:            req.Note,
		PriceCents:      req.PriceCents,
		ProductID:       req.ProductID,
		StoreID:         req.StoreID,
		CanonicalItemID: req.CanonicalItemID,
		AddedBy:         &user.ID,
	}
	if err := h.service.CreateItem(r.Context(), user, item); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusCreated, item)
}

// ListItems handles GET /api/v1/lists/{id}/items.
func (h *ListHandler) ListItems(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	limit, offset := parsePagination(r)
	items, err := h.service.ListItems(r.Context(), user, listID, limit, offset)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, items)
}

// UpdateItem handles PATCH /api/v1/lists/{id}/items/{item_id}.
func (h *ListHandler) UpdateItem(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "item_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "item_id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Name       *string    `json:"name,omitempty"`
		Quantity   *float64   `json:"quantity,omitempty"`
		Unit       *string    `json:"unit,omitempty"`
		Note       *string    `json:"note,omitempty"`
		PriceCents *int       `json:"price_cents,omitempty"`
		ProductID  *uuid.UUID `json:"product_id,omitempty"`
		StoreID    *uuid.UUID `json:"store_id,omitempty"`
		Checked    *bool      `json:"checked,omitempty"`
		Position   *int       `json:"position,omitempty"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	existing, err := h.service.GetItem(r.Context(), user, itemID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}
	if req.Quantity != nil {
		existing.Quantity = *req.Quantity
	}
	if req.Unit != nil {
		existing.Unit = *req.Unit
	}
	if req.Note != nil {
		existing.Note = *req.Note
	}
	if req.PriceCents != nil {
		existing.PriceCents = req.PriceCents
	}
	if req.ProductID != nil {
		existing.ProductID = req.ProductID
	}
	if req.StoreID != nil {
		existing.StoreID = req.StoreID
	}
	if req.Checked != nil {
		existing.Checked = *req.Checked
	}
	if req.Position != nil {
		existing.Position = *req.Position
	}

	if err := h.service.UpdateItem(r.Context(), user, existing); err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, existing)
}

// ClearItems handles POST /api/v1/lists/{id}/items/clear.
func (h *ListHandler) ClearItems(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		OnlyChecked bool `json:"only_checked"`
	}
	if r.Body != nil {
		_ = decodeJSON(r, &req)
	}

	deleted, err := h.service.ClearItems(r.Context(), user, listID, req.OnlyChecked)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"deleted": deleted})
}

// AddItemAmount handles POST /api/v1/lists/{id}/items/add.
func (h *ListHandler) AddItemAmount(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Name   string  `json:"name"`
		Amount float64 `json:"amount"`
		Unit   string  `json:"unit"`
		Note   string  `json:"note"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	item, err := h.service.AddItemAmount(r.Context(), user, listID, req.Name, req.Amount, req.Unit, req.Note)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, item)
}

// RemoveItemAmount handles POST /api/v1/lists/{id}/items/remove.
func (h *ListHandler) RemoveItemAmount(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Name   string  `json:"name"`
		Amount float64 `json:"amount"`
		Unit   string  `json:"unit"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	item, removed, err := h.service.RemoveItemAmount(r.Context(), user, listID, req.Name, req.Amount, req.Unit)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if item == nil {
		api.RespondJSON(w, http.StatusOK, map[string]any{"removed": false, "item": nil})
		return
	}
	api.RespondJSON(w, http.StatusOK, map[string]any{"removed": removed, "item": item})
}

// DeleteItem handles DELETE /api/v1/lists/{id}/items/{item_id}.
func (h *ListHandler) DeleteItem(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "item_id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "item_id", Message: "invalid UUID"})
		return
	}

	if err := h.service.DeleteItem(r.Context(), user, itemID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ReorderItems handles POST /api/v1/lists/{id}/reorder.
func (h *ListHandler) ReorderItems(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		ItemIDs []uuid.UUID `json:"item_ids"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if err := h.service.ReorderItems(r.Context(), user, listID, req.ItemIDs); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// GetCostSummary handles GET /api/v1/lists/{id}/cost-summary.
func (h *ListHandler) GetCostSummary(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	summary, err := h.service.GetCostSummary(r.Context(), user, listID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, summary)
}

// GenerateExpense handles POST /api/v1/lists/{id}/generate-expense.
func (h *ListHandler) GenerateExpense(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "id", Message: "invalid UUID"})
		return
	}

	var req struct {
		Description string `json:"description"`
	}
	_ = decodeJSON(r, &req)

	expense, err := h.service.GenerateExpenseFromList(r.Context(), user, listID, req.Description)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusCreated, expense)
}

// GetShoppingTrip handles GET /api/v1/shopping/trip.
func (h *ListHandler) GetShoppingTrip(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	listIDsStr := r.URL.Query()["list_id"]
	if len(listIDsStr) == 0 {
		api.RespondError(w, &api.ValidationError{Field: "list_id", Message: "at least one list_id is required"})
		return
	}

	listIDs := make([]uuid.UUID, 0, len(listIDsStr))
	for _, idStr := range listIDsStr {
		id, err := uuid.Parse(idStr)
		if err != nil {
			api.RespondError(w, &api.ValidationError{Field: "list_id", Message: "invalid UUID: " + idStr})
			return
		}
		listIDs = append(listIDs, id)
	}

	trip, err := h.service.GetShoppingTrip(r.Context(), user, listIDs)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{"lists": trip})
}

// BulkCompleteItems handles POST /api/v1/shopping/complete.
func (h *ListHandler) BulkCompleteItems(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}

	var req struct {
		ItemIDs []uuid.UUID `json:"item_ids"`
	}
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, &api.ValidationError{Message: "invalid request body"})
		return
	}

	if len(req.ItemIDs) == 0 {
		api.RespondError(w, &api.ValidationError{Field: "item_ids", Message: "item_ids is required"})
		return
	}

	completed, err := h.service.BulkCompleteItems(r.Context(), user, req.ItemIDs)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, map[string]any{"completed": completed})
}

func (h *ListHandler) ArchiveList(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	_, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	if err := h.service.SetListArchived(r.Context(), id, true); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ListHandler) UnarchiveList(w http.ResponseWriter, r *http.Request) {
	id, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	_, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	if err := h.service.SetListArchived(r.Context(), id, false); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ListHandler) ClaimItem(w http.ResponseWriter, r *http.Request) {
	itemID, err := parseUUIDParam(r, "item_id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	user, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	listID, err := parseUUIDParam(r, "id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	_, err = h.service.GetList(r.Context(), user, listID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	if err := h.service.ListRepo().ClaimItem(r.Context(), itemID, user.ID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *ListHandler) UnclaimItem(w http.ResponseWriter, r *http.Request) {
	itemID, err := parseUUIDParam(r, "item_id")
	if err != nil {
		api.RespondError(w, err)
		return
	}
	_, ok := userFromContext(r)
	if !ok {
		api.RespondError(w, api.ErrUnauthorized)
		return
	}
	if err := h.service.ListRepo().UnclaimItem(r.Context(), itemID); err != nil {
		api.RespondError(w, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
