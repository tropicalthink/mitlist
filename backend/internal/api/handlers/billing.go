package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/services"
)

// BillingHandler exposes premium status and the checkout flow.
type BillingHandler struct {
	svc *services.BillingService
}

// NewBillingHandler creates a handler backed by svc.
func NewBillingHandler(svc *services.BillingService) *BillingHandler {
	return &BillingHandler{svc: svc}
}

// RegisterRoutes mounts the billing endpoints.
func (h *BillingHandler) RegisterRoutes(r chi.Router) {
	r.Get("/billing/status", h.GetStatus)
	r.Get("/billing/groups/{groupID}/entitlement", h.GetHouseholdEntitlement)
	r.Put("/billing/groups/{groupID}/premium", h.SetPremiumHousehold)
	r.Post("/billing/checkout", h.CreateCheckout)
	r.Post("/billing/portal", h.OpenPortal)
}

// billingStatusResponse describes the caller's own billing position.
type billingStatusResponse struct {
	// Enabled is false on servers with no payment provider configured — a
	// self-hosted instance, typically. Clients should hide billing UI entirely.
	Enabled      bool                        `json:"enabled"`
	FreeLimit    int                         `json:"free_limit"`
	Subscription *models.BillingSubscription `json:"subscription,omitempty"`
}

// GetStatus GET /billing/status
func (h *BillingHandler) GetStatus(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	sub, err := h.svc.GetUserSubscription(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, billingStatusResponse{
		Enabled:      h.svc.Enabled(),
		FreeLimit:    h.svc.FreeMemberLimit(),
		Subscription: sub,
	})
}

// GetHouseholdEntitlement GET /billing/groups/{groupID}/entitlement
func (h *BillingHandler) GetHouseholdEntitlement(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}
	groupID, err := parseUUIDParam(r, "groupID")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	ent, err := h.svc.GetHouseholdEntitlement(r.Context(), userID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, ent)
}

// SetPremiumHousehold PUT /billing/groups/{groupID}/premium
//
// Moves the caller's subscription to cover this household, the way a console is
// made primary. The previous household keeps every member it already has.
func (h *BillingHandler) SetPremiumHousehold(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}
	groupID, err := parseUUIDParam(r, "groupID")
	if err != nil {
		api.RespondError(w, err)
		return
	}

	sub, err := h.svc.SetPremiumHousehold(r.Context(), userID, groupID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, sub)
}

type createCheckoutRequest struct {
	// Interval is "monthly" or "yearly".
	Interval string `json:"interval"`
	// GroupID is the household the subscription will cover. Optional: when
	// omitted the buyer picks their premium household after paying.
	GroupID string `json:"group_id,omitempty"`
	// DiscountID optionally auto-applies a discount. Customers can also enter
	// a promo code on the checkout page itself, which needs nothing from here.
	DiscountID string `json:"discount_id,omitempty"`
}

type createCheckoutResponse struct {
	CheckoutURL string `json:"checkout_url"`
}

// CreateCheckout POST /billing/checkout
func (h *BillingHandler) CreateCheckout(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	var req createCheckoutRequest
	if err := decodeJSON(r, &req); err != nil {
		api.RespondError(w, err)
		return
	}

	var interval services.PlanInterval
	switch req.Interval {
	case "", string(services.PlanMonthly):
		interval = services.PlanMonthly
	case string(services.PlanYearly):
		interval = services.PlanYearly
	default:
		api.RespondError(w, &api.ValidationError{Field: "interval", Message: "interval must be monthly or yearly"})
		return
	}

	var groupID uuid.UUID
	if req.GroupID != "" {
		parsed, parseErr := uuid.Parse(req.GroupID)
		if parseErr != nil || parsed == uuid.Nil {
			api.RespondError(w, &api.ValidationError{Field: "group_id", Message: "group_id must be a valid household ID"})
			return
		}
		groupID = parsed
	}

	url, err := h.svc.StartCheckout(r.Context(), userID, services.CheckoutInput{
		Interval:   interval,
		GroupID:    groupID,
		DiscountID: req.DiscountID,
	})
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, createCheckoutResponse{CheckoutURL: url})
}

type portalResponse struct {
	PortalURL string `json:"portal_url"`
}

// OpenPortal POST /billing/portal
func (h *BillingHandler) OpenPortal(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	url, err := h.svc.OpenCustomerPortal(r.Context(), userID)
	if err != nil {
		api.RespondError(w, err)
		return
	}
	api.RespondJSON(w, http.StatusOK, portalResponse{PortalURL: url})
}
