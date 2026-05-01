package services

import (
	"context"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

var (
	// urlRegex matches HTTP/HTTPS URLs.
	urlRegex = regexp.MustCompile(`https?://[^\s]+`)
)

// ParsedShare holds extracted data from shared text.
type ParsedShare struct {
	Title string   `json:"title"`
	URL   string   `json:"url,omitempty"`
	Lines []string `json:"lines"`
}

// ShareService parses shared text and creates domain entities.
type ShareService struct {
	listRepo   repositories.ListRepo
	recipeRepo repositories.RecipeRepoIface
	groupRepo  repositories.GroupRepo
}

// NewShareService creates a new ShareService.
func NewShareService(listRepo repositories.ListRepo, recipeRepo repositories.RecipeRepoIface, groupRepo repositories.GroupRepo) *ShareService {
	return &ShareService{
		listRepo:   listRepo,
		recipeRepo: recipeRepo,
		groupRepo:  groupRepo,
	}
}

// ParseSharedText extracts URLs, title, and lines from raw shared text.
func (s *ShareService) ParseSharedText(text string) (*ParsedShare, error) {
	if strings.TrimSpace(text) == "" {
		return nil, &api.ValidationError{Field: "text", Message: "shared text cannot be empty"}
	}

	result := &ParsedShare{
		Lines: []string{},
	}

	// Extract URL.
	matches := urlRegex.FindAllString(text, -1)
	if len(matches) > 0 {
		result.URL = matches[0]
	}

	// Split into lines and clean.
	rawLines := strings.Split(text, "\n")
	for _, line := range rawLines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Skip if line is exactly the URL.
		if line == result.URL {
			continue
		}
		result.Lines = append(result.Lines, line)
	}

	// Determine title: first non-URL, non-empty line.
	if len(result.Lines) > 0 {
		result.Title = result.Lines[0]
		result.Lines = result.Lines[1:]
	}

	if result.Title == "" {
		if result.URL != "" {
			if u, err := url.Parse(result.URL); err == nil && u.Host != "" {
				result.Title = u.Host
			} else {
				result.Title = "Shared link"
			}
		} else {
			result.Title = "Shared items"
		}
	}

	return result, nil
}

// CreateListFromShare creates a list with items from shared text.
func (s *ShareService) CreateListFromShare(ctx context.Context, userID uuid.UUID, groupID uuid.UUID, text string) (*models.List, []models.ListItem, error) {
	parsed, err := s.ParseSharedText(text)
	if err != nil {
		return nil, nil, err
	}

	if s.groupRepo != nil {
		_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
		if err != nil {
			return nil, nil, &api.PermissionDeniedError{Message: "not a member of this group"}
		}
	}

	list := &models.List{
		GroupID: groupID,
		Name:    parsed.Title,
		Type:    "shopping",
	}
	if err := s.listRepo.CreateList(ctx, list); err != nil {
		return nil, nil, fmt.Errorf("create list: %w", err)
	}

	var items []models.ListItem
	for i, line := range parsed.Lines {
		item := &models.ListItem{
			ListID:   list.ID,
			Name:     line,
			Quantity: 1,
			Position: i,
		}
		if err := s.listRepo.CreateItem(ctx, item); err != nil {
			return nil, nil, fmt.Errorf("create list item: %w", err)
		}
		items = append(items, *item)
	}

	return list, items, nil
}

// CreateRecipeFromShare creates a recipe from shared text.
func (s *ShareService) CreateRecipeFromShare(ctx context.Context, userID uuid.UUID, text string) (*models.Recipe, error) {
	parsed, err := s.ParseSharedText(text)
	if err != nil {
		return nil, err
	}

	recipe := &models.Recipe{
		UserID: userID,
		Title:  parsed.Title,
	}
	if parsed.URL != "" {
		recipe.Description = fmt.Sprintf("%s\n\nSource: %s", text, parsed.URL)
	} else {
		recipe.Description = text
	}
	if err := s.recipeRepo.CreateRecipe(ctx, recipe); err != nil {
		return nil, fmt.Errorf("create recipe: %w", err)
	}

	return recipe, nil
}
