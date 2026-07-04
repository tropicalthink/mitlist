package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
)

// GroceryService manages the household grocery graph and correction memory.
type GroceryService struct {
	repo      *repositories.GroceryRepository
	groupRepo repositories.GroupRepo
	hub       *sse.Hub
}

// NewGroceryService creates a new GroceryService.
func NewGroceryService(repo *repositories.GroceryRepository, groupRepo repositories.GroupRepo) *GroceryService {
	return &GroceryService{repo: repo, groupRepo: groupRepo}
}

// SetHub injects the SSE hub for real-time graph-updated events.
func (s *GroceryService) SetHub(h *sse.Hub) { s.hub = h }

// GetGraphDelta returns the graph delta for a household since sinceVersion.
// Membership is verified before data is returned.
func (s *GroceryService) GetGraphDelta(ctx context.Context, userID, groupID uuid.UUID, sinceVersion int64) (*models.GroceryGraphDelta, error) {
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}

	delta, err := s.repo.GetDelta(ctx, groupID, sinceVersion)
	if err != nil {
		return nil, err
	}

	if !delta.HasMore {
		maxVersion, err := s.repo.CurrentVersion(ctx, groupID)
		if err != nil {
			return nil, err
		}
		delta.MaxVersion = maxVersion
	}

	// Ensure nil slices are empty arrays in JSON output.
	if delta.CanonicalItems == nil {
		delta.CanonicalItems = []models.CanonicalItem{}
	}
	if delta.ItemAliases == nil {
		delta.ItemAliases = []models.ItemAlias{}
	}
	if delta.Corrections == nil {
		delta.Corrections = []models.Correction{}
	}
	if delta.StoreAisles == nil {
		delta.StoreAisles = []models.StoreAisle{}
	}
	if delta.PurchaseHistory == nil {
		delta.PurchaseHistory = []models.PurchaseHistory{}
	}
	if delta.ItemCooccurrence == nil {
		delta.ItemCooccurrence = []models.ItemCooccurrence{}
	}

	return delta, nil
}

// RecordCorrectionRequest is the payload from the client for a confirmed correction.
type RecordCorrectionRequest struct {
	RawText             string             `json:"raw_text"`
	Kind                string             `json:"kind"`  // alias | reject
	Scope               string             `json:"scope"` // household | user
	ResolvedCanonicalID *uuid.UUID         `json:"canonical_item_id,omitempty"`
	CanonicalItem       *CanonicalItemStub `json:"canonical_item,omitempty"`
	Lang                string             `json:"lang"`
}

type CanonicalItemStub struct {
	ID          uuid.UUID `json:"id"`
	NameDe      string    `json:"name_de"`
	NameEn      string    `json:"name_en"`
	Category    string    `json:"category"`
	DefaultUnit string    `json:"default_unit"`
}

// RecordCorrection records a confirmed correction and materialises the alias.
// Returns the next max version so the client can update its cursor.
func (s *GroceryService) RecordCorrection(ctx context.Context, userID, groupID uuid.UUID, req RecordCorrectionRequest) (int64, error) {
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return 0, err
	}

	var version int64
	err := s.repo.WithTx(ctx, func(txRepo *repositories.GroceryRepository) error {
		var err error
		version, err = txRepo.NextVersion(ctx, groupID)
		if err != nil {
			return err
		}

		if req.Kind == "alias" && req.ResolvedCanonicalID != nil && req.CanonicalItem != nil {
			if err := txRepo.UpsertCanonicalItem(
				ctx,
				req.CanonicalItem.ID,
				groupID,
				req.CanonicalItem.NameDe,
				req.CanonicalItem.NameEn,
				req.CanonicalItem.Category,
				req.CanonicalItem.DefaultUnit,
				version,
			); err != nil {
				return err
			}
		}

		correctedValueJSON, _ := json.Marshal(map[string]string{"alias_text": strings.ToLower(strings.TrimSpace(req.RawText))})

		c := &models.Correction{
			GroupID:                 groupID,
			UserID:                  &userID,
			Scope:                   req.Scope,
			Kind:                    req.Kind,
			RawText:                 req.RawText,
			ResolvedCanonicalItemID: req.ResolvedCanonicalID,
			CorrectedValue:          json.RawMessage(correctedValueJSON),
			Source:                  "client",
		}
		if err := txRepo.InsertCorrection(ctx, c, version); err != nil {
			return err
		}

		// Materialise: write the alias row so lookup is instant on next scan.
		if req.Kind == "alias" && req.ResolvedCanonicalID != nil {
			lang := req.Lang
			if lang == "" {
				lang = "de"
			}
			aliasText := strings.ToLower(strings.TrimSpace(req.RawText))
			if err := txRepo.UpsertAlias(ctx, groupID, *req.ResolvedCanonicalID, aliasText, lang, "correction", version); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return 0, err
	}

	// Notify other devices immediately.
	s.publishGraphUpdated(groupID, version)

	return version, nil
}

// AisleFeedbackRequest is the body for the aisle feedback endpoint.
type AisleFeedbackRequest struct {
	Aisles []repositories.AisleFeedbackItem `json:"aisles"`
}

// UpdateAisles persists drag-to-reorder aisle feedback from the client.
// Returns the new max version so the client can update its cursor.
func (s *GroceryService) UpdateAisles(ctx context.Context, userID, groupID uuid.UUID, req AisleFeedbackRequest) (int64, error) {
	if err := s.requireMembership(ctx, userID, groupID); err != nil {
		return 0, err
	}
	if len(req.Aisles) == 0 {
		cur, err := s.repo.CurrentVersion(ctx, groupID)
		return cur, err
	}
	var version int64
	err := s.repo.WithTx(ctx, func(txRepo *repositories.GroceryRepository) error {
		var err error
		version, err = txRepo.NextVersion(ctx, groupID)
		if err != nil {
			return err
		}
		return txRepo.UpsertAislesBatch(ctx, groupID, req.Aisles, version)
	})
	if err != nil {
		return 0, err
	}
	s.publishGraphUpdated(groupID, version)
	return version, nil
}

// ResolveIngredientName performs an exact alias lookup for the given ingredient
// name against the household's grocery catalog (household-scoped aliases first,
// then global seed aliases). Returns the canonical item ID when matched, nil
// when not found. Resolution is best-effort: callers must not fail the request
// when this returns nil.
func (s *GroceryService) ResolveIngredientName(ctx context.Context, groupID uuid.UUID, name string) (*uuid.UUID, error) {
	// Normalise: lowercase, trim, collapse internal whitespace.
	normalised := strings.Join(strings.Fields(strings.ToLower(strings.TrimSpace(name))), " ")
	if normalised == "" {
		return nil, nil
	}
	id, found, err := s.repo.ResolveAlias(ctx, groupID, normalised)
	if err != nil {
		return nil, fmt.Errorf("resolve ingredient alias: %w", err)
	}
	if !found {
		return nil, nil
	}
	return &id, nil
}

func (s *GroceryService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *GroceryService) publishGraphUpdated(groupID uuid.UUID, version int64) {
	if s.hub == nil {
		return
	}
	data, _ := json.Marshal(map[string]any{"group_id": groupID.String(), "version": version})
	s.hub.Publish(groupID.String(), sse.Event{
		Type:    "grocery:graph_updated",
		GroupID: groupID.String(),
		Payload: data,
	})
}
