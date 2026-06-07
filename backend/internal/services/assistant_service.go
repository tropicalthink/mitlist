package services

import (
	"context"
	"encoding/json"
	"fmt"
)

// ScanResult is the structured output from scanning an image.
type ScanResult struct {
	Type   string     `json:"type"` // "receipt", "list", "recipe", "chore"
	Title  string     `json:"title,omitempty"`
	Items  []ScanItem `json:"items,omitempty"`
	Steps  []string   `json:"steps,omitempty"`
	Amount int        `json:"amount,omitempty"` // in cents
}

// ScanItem is a single line item extracted from a scanned image.
type ScanItem struct {
	Name       string `json:"name"`
	Quantity   string `json:"quantity,omitempty"`
	Unit       string `json:"unit,omitempty"`
	PriceCents int    `json:"price_cents,omitempty"`
}

// ScanService provides OCR/image scanning via CrofAI Vision.
type ScanService struct {
	aiClient AIClient
}

// NewScanService creates a new ScanService.
func NewScanService(aiClient AIClient) *ScanService {
	return &ScanService{aiClient: aiClient}
}

// ScanImage processes an image through CrofAI Vision and returns structured data.
func (s *ScanService) ScanImage(ctx context.Context, imageBytes []byte, mimeType string) (*ScanResult, error) {
	schema := map[string]any{
		"name": "scan_result",
		"type": "object",
		"properties": map[string]any{
			"type":  map[string]any{"type": "string", "enum": []string{"receipt", "list", "recipe", "chore"}},
			"title": map[string]any{"type": "string"},
			"items": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type": "object",
					"properties": map[string]any{
						"name":        map[string]any{"type": "string"},
						"quantity":    map[string]any{"type": "string"},
						"unit":        map[string]any{"type": "string"},
						"price_cents": map[string]any{"type": "integer"},
					},
					"required":             []string{"name"},
					"additionalProperties": false,
				},
			},
			"steps": map[string]any{
				"type":  "array",
				"items": map[string]any{"type": "string"},
			},
			"amount": map[string]any{"type": "integer"},
		},
		"required":             []string{"type"},
		"additionalProperties": false,
	}

	prompt := `Analyze this image. It could be a receipt, a shopping list, a recipe, or a chore reminder.
Return a JSON object with:
- "type": one of "receipt", "list", "recipe", "chore"
- "title": a short title for what was scanned
- "items": array of objects with "name" (required), "quantity", "unit", "price_cents" (for receipts/lists)
- "steps": array of instruction strings (for recipes/chores)
- "amount": total amount in cents (for receipts only)

Extract as much detail as possible. For receipts, parse each line item with prices in cents. For lists, extract items with optional quantities. For recipes, extract ingredients as items and instructions as steps. For chores, title + steps.`

	result, err := s.aiClient.GenerateImage(imageBytes, mimeType, prompt, "kimi-k2.5", schema)
	if err != nil {
		return nil, fmt.Errorf("scan image: %w", err)
	}

	var scan ScanResult
	b, err := json.Marshal(result)
	if err != nil {
		return nil, fmt.Errorf("serialize scan result: %w", err)
	}
	if err := json.Unmarshal(b, &scan); err != nil {
		return nil, fmt.Errorf("parse scan result: %w", err)
	}

	return &scan, nil
}
