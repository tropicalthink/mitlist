package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/services"
)

// RecipeHandler exposes recipe and collection endpoints.
type RecipeHandler struct {
	service   *services.RecipeService
	scrapeSvc *services.RecipeScrapingService
	listSvc   *services.ListService
}

// NewRecipeHandler creates a new RecipeHandler.
func NewRecipeHandler(service *services.RecipeService, scrapeSvc *services.RecipeScrapingService, listSvc ...*services.ListService) *RecipeHandler {
	h := &RecipeHandler{service: service, scrapeSvc: scrapeSvc}
	if len(listSvc) > 0 {
		h.listSvc = listSvc[0]
	}
	return h
}

func (h *RecipeHandler) RegisterRoutes(r chi.Router) {
	r.Post("/recipes", h.CreateRecipe)
	r.Get("/recipes", h.ListRecipes)
	r.Get("/recipes/{id}", h.GetRecipe)
	r.Patch("/recipes/{id}", h.UpdateRecipe)
	r.Delete("/recipes/{id}", h.DeleteRecipe)
	r.Post("/recipes/{id}/share", h.ShareRecipe)
	r.Post("/recipes/{id}/add-to-list", h.AddToList)
	r.Post("/recipes/{id}/add-missing-to-list", h.AddMissingToList)
	r.Post("/recipes/clip", h.ClipRecipe)

	r.Post("/collections", h.CreateCollection)
	r.Get("/collections", h.ListCollections)
	r.Get("/collections/{id}", h.GetCollection)
	r.Patch("/collections/{id}", h.UpdateCollection)
	r.Delete("/collections/{id}", h.DeleteCollection)
	r.Post("/collections/{id}/recipes", h.AddToCollection)
	r.Delete("/collections/{id}/recipes/{recipe_id}", h.RemoveFromCollection)
}

// ------------------------------------------------------------------
// Recipes
// ------------------------------------------------------------------

type createRecipeRequest struct {
	Title            string   `json:"title"`
	Description      string   `json:"description"`
	DescriptionShort string   `json:"description_short"`
	Author           string   `json:"author"`
	RatingValue      float64  `json:"rating_value"`
	RatingCount      int      `json:"rating_count"`
	NutritionJSON    string   `json:"nutrition_json"`
	VideoURL         string   `json:"video_url"`
	EquipmentJSON    string   `json:"equipment_json"`
	SourceURL        string   `json:"source_url"`
	ImageURL         string   `json:"image_url"`
	ImageOptions     []string `json:"image_options"`
	Tags             []string `json:"tags"`
	PrepTime         int      `json:"prep_time"`
	CookTime         int      `json:"cook_time"`
	Servings         int      `json:"servings"`
	IsPublic         bool     `json:"is_public"`
}

func (h *RecipeHandler) CreateRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	var req createRecipeRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	recipe := &models.Recipe{
		Title:            req.Title,
		Description:      req.Description,
		DescriptionShort: req.DescriptionShort,
		Author:           req.Author,
		RatingValue:      req.RatingValue,
		RatingCount:      req.RatingCount,
		NutritionJSON:    req.NutritionJSON,
		VideoURL:         req.VideoURL,
		EquipmentJSON:    req.EquipmentJSON,
		SourceURL:        req.SourceURL,
		ImageURL:         req.ImageURL,
		ImageOptions:     req.ImageOptions,
		Tags:             req.Tags,
		PrepTime:         req.PrepTime,
		CookTime:         req.CookTime,
		Servings:         req.Servings,
		IsPublic:         req.IsPublic,
	}

	if err := h.service.CreateRecipe(r.Context(), userID, recipe); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, recipe)
}

func (h *RecipeHandler) ListRecipes(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	recipes, err := h.service.ListRecipes(r.Context(), userID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, recipes)
}

func (h *RecipeHandler) GetRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	recipe, err := h.service.GetRecipe(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, recipe)
}

type updateRecipeRequest struct {
	Title            *string   `json:"title,omitempty"`
	Description      *string   `json:"description,omitempty"`
	DescriptionShort *string   `json:"description_short,omitempty"`
	Author           *string   `json:"author,omitempty"`
	RatingValue      *float64  `json:"rating_value,omitempty"`
	RatingCount      *int      `json:"rating_count,omitempty"`
	NutritionJSON    *string   `json:"nutrition_json,omitempty"`
	VideoURL         *string   `json:"video_url,omitempty"`
	EquipmentJSON    *string   `json:"equipment_json,omitempty"`
	SourceURL        *string   `json:"source_url,omitempty"`
	ImageURL         *string   `json:"image_url,omitempty"`
	ImageOptions     []string  `json:"image_options,omitempty"`
	Tags             []string  `json:"tags,omitempty"`
	PrepTime         *int      `json:"prep_time,omitempty"`
	CookTime         *int      `json:"cook_time,omitempty"`
	Servings         *int      `json:"servings,omitempty"`
	IsPublic         *bool     `json:"is_public,omitempty"`
}

func (h *RecipeHandler) UpdateRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateRecipeRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetRecipe(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.Title != nil {
		existing.Title = *req.Title
	}
	if req.Description != nil {
		existing.Description = *req.Description
	}
	if req.DescriptionShort != nil {
		existing.DescriptionShort = *req.DescriptionShort
	}
	if req.Author != nil {
		existing.Author = *req.Author
	}
	if req.RatingValue != nil {
		existing.RatingValue = *req.RatingValue
	}
	if req.RatingCount != nil {
		existing.RatingCount = *req.RatingCount
	}
	if req.NutritionJSON != nil {
		existing.NutritionJSON = *req.NutritionJSON
	}
	if req.VideoURL != nil {
		existing.VideoURL = *req.VideoURL
	}
	if req.EquipmentJSON != nil {
		existing.EquipmentJSON = *req.EquipmentJSON
	}
	if req.SourceURL != nil {
		existing.SourceURL = *req.SourceURL
	}
	if req.ImageURL != nil {
		existing.ImageURL = *req.ImageURL
	}
	if req.ImageOptions != nil {
		existing.ImageOptions = req.ImageOptions
	}
	if req.Tags != nil {
		existing.Tags = req.Tags
	}
	if req.PrepTime != nil {
		existing.PrepTime = *req.PrepTime
	}
	if req.CookTime != nil {
		existing.CookTime = *req.CookTime
	}
	if req.Servings != nil {
		existing.Servings = *req.Servings
	}
	if req.IsPublic != nil {
		existing.IsPublic = *req.IsPublic
	}

	if err := h.service.UpdateRecipe(r.Context(), userID, existing); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, existing)
}

func (h *RecipeHandler) DeleteRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteRecipe(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type recipeShareRequest struct {
	SharedWithUserID uuid.UUID `json:"shared_with_user_id"`
	Permission       string    `json:"permission"`
}

func (h *RecipeHandler) ShareRecipe(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req recipeShareRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.ShareRecipe(r.Context(), userID, id, req.SharedWithUserID, req.Permission); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type addToListRequest struct {
	ListID        uuid.UUID   `json:"list_id"`
	Servings      *int        `json:"servings,omitempty"`
	IngredientIDs []uuid.UUID `json:"ingredient_ids,omitempty"`
}

func (h *RecipeHandler) AddToList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}
	if h.listSvc == nil {
		respondError(w, &api.ValidationError{Message: "list integration is not configured"})
		return
	}
	recipeID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}
	var req addToListRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}
	if req.ListID == uuid.Nil {
		respondError(w, &api.ValidationError{Field: "list_id", Message: "list_id is required"})
		return
	}

	recipe, err := h.service.GetRecipe(r.Context(), user.ID, recipeID)
	if err != nil {
		respondError(w, err)
		return
	}

	ingredients, err := h.service.ListIngredientsForRecipe(r.Context(), user.ID, recipeID)
	if err != nil {
		respondError(w, err)
		return
	}

	// Filter to selected ingredients if specified
	selected := ingredients
	if len(req.IngredientIDs) > 0 {
		idSet := make(map[uuid.UUID]struct{}, len(req.IngredientIDs))
		for _, id := range req.IngredientIDs {
			idSet[id] = struct{}{}
		}
		selected = make([]models.RecipeIngredient, 0, len(req.IngredientIDs))
		for _, ing := range ingredients {
			if _, ok := idSet[ing.ID]; ok {
				selected = append(selected, ing)
			}
		}
	}

	// Calculate scaling factor
	scale := 1.0
	if req.Servings != nil && recipe.Servings > 0 {
		scale = float64(*req.Servings) / float64(recipe.Servings)
	}

	added := make([]models.ListItem, 0, len(selected))
	for _, ing := range selected {
		qty := parseIngredientAmount(ing.Quantity) * scale
		if qty <= 0 {
			qty = 1 * scale
		}
		item, err := h.listSvc.AddItemAmount(r.Context(), user, req.ListID, ing.Name, qty, ing.Unit, "From recipe: "+recipe.Title)
		if err != nil {
			respondError(w, err)
			return
		}
		added = append(added, *item)
	}
	respondJSON(w, http.StatusOK, map[string]any{"added": added})
}

type addMissingToListRequest struct {
	ListID uuid.UUID `json:"list_id"`
}

func (h *RecipeHandler) AddMissingToList(w http.ResponseWriter, r *http.Request) {
	user, ok := userFromContext(r)
	if !ok {
		respondError(w, api.ErrUnauthorized)
		return
	}
	if h.listSvc == nil {
		respondError(w, &api.ValidationError{Message: "list integration is not configured"})
		return
	}
	recipeID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}
	var req addMissingToListRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}
	if req.ListID == uuid.Nil {
		respondError(w, &api.ValidationError{Field: "list_id", Message: "list_id is required"})
		return
	}

	recipe, err := h.service.GetRecipe(r.Context(), user.ID, recipeID)
	if err != nil {
		respondError(w, err)
		return
	}

	ingredients, err := h.service.ListIngredientsForRecipe(r.Context(), user.ID, recipeID)
	if err != nil {
		respondError(w, err)
		return
	}

	// Get existing list items for deduplication
	existingItems, err := h.listSvc.ListItems(r.Context(), user, req.ListID, 0, 0)
	if err != nil {
		respondError(w, err)
		return
	}

	// Build set of existing item names (normalized)
	existingNames := make(map[string]struct{}, len(existingItems))
	for _, item := range existingItems {
		existingNames[normalizeName(item.Name)] = struct{}{}
	}

	added := make([]models.ListItem, 0)
	skipped := make([]string, 0)
	for _, ing := range ingredients {
		if _, exists := existingNames[normalizeName(ing.Name)]; exists {
			skipped = append(skipped, ing.Name)
			continue
		}
		qty := parseIngredientAmount(ing.Quantity)
		if qty <= 0 {
			qty = 1
		}
		item, err := h.listSvc.AddItemAmount(r.Context(), user, req.ListID, ing.Name, qty, ing.Unit, "From recipe: "+recipe.Title)
		if err != nil {
			respondError(w, err)
			return
		}
		added = append(added, *item)
	}
	respondJSON(w, http.StatusOK, map[string]any{"added": added, "skipped": skipped})
}

func normalizeName(name string) string {
	return strings.ToLower(strings.TrimSpace(name))
}

func parseIngredientAmount(raw string) float64 {
	raw = strings.TrimSpace(strings.ReplaceAll(raw, ",", "."))
	if raw == "" {
		return 1
	}
	for _, field := range strings.Fields(raw) {
		if n, err := strconv.ParseFloat(field, 64); err == nil && n > 0 {
			return n
		}
	}
	if n, err := strconv.ParseFloat(raw, 64); err == nil && n > 0 {
		return n
	}
	return 1
}

type recipeClipRequest struct {
	URL string `json:"url"`
}

func (h *RecipeHandler) ClipRecipe(w http.ResponseWriter, r *http.Request) {
	_ = RequireUser(w, r) // authentication only; clip data is not user-specific

	if h.scrapeSvc == nil {
		respondError(w, &api.ValidationError{Field: "url", Message: "recipe scraping is not configured"})
		return
	}

	var req recipeClipRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}
	if req.URL == "" {
		respondError(w, &api.ValidationError{Field: "url", Message: "url is required"})
		return
	}

	clip, err := h.scrapeSvc.ScrapeRecipe(r.Context(), req.URL)
	if err != nil {
		respondError(w, &api.ValidationError{Field: "url", Message: err.Error()})
		return
	}

	respondJSON(w, http.StatusOK, clip)
}

// ------------------------------------------------------------------
// Collections
// ------------------------------------------------------------------

type createCollectionRequest struct {
	Name string `json:"name"`
}

func (h *RecipeHandler) CreateCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	var req createCollectionRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	collection := &models.Collection{
		Name: req.Name,
	}

	if err := h.service.CreateCollection(r.Context(), userID, collection); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusCreated, collection)
}

func (h *RecipeHandler) ListCollections(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	limit, offset := parsePagination(r)
	collections, err := h.service.ListCollections(r.Context(), userID, limit, offset)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, collections)
}

func (h *RecipeHandler) GetCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	collection, err := h.service.GetCollection(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, collection)
}

type updateCollectionRequest struct {
	Name *string `json:"name,omitempty"`
}

func (h *RecipeHandler) UpdateCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req updateCollectionRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	existing, err := h.service.GetCollection(r.Context(), userID, id)
	if err != nil {
		respondError(w, err)
		return
	}

	if req.Name != nil {
		existing.Name = *req.Name
	}

	if err := h.service.UpdateCollection(r.Context(), userID, existing); err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, existing)
}

func (h *RecipeHandler) DeleteCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	id, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.DeleteCollection(r.Context(), userID, id); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

type addToCollectionRequest struct {
	RecipeID uuid.UUID `json:"recipe_id"`
}

func (h *RecipeHandler) AddToCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	collectionID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	var req addToCollectionRequest
	if err := decodeJSON(r, &req); err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.AddToCollection(r.Context(), userID, collectionID, req.RecipeID); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *RecipeHandler) RemoveFromCollection(w http.ResponseWriter, r *http.Request) {
	userID, err := currentUserID(r)
	if err != nil {
		respondError(w, err)
		return
	}

	collectionID, err := parseUUIDParam(r, "id")
	if err != nil {
		respondError(w, err)
		return
	}

	recipeID, err := parseUUIDParam(r, "recipe_id")
	if err != nil {
		respondError(w, err)
		return
	}

	if err := h.service.RemoveFromCollection(r.Context(), userID, collectionID, recipeID); err != nil {
		respondError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
