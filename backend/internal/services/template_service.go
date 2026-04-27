package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// TemplateService provides business logic for list and chore templates.
type TemplateService struct {
	templateRepo repositories.TemplateRepo
	groupRepo    repositories.GroupRepo
	listRepo     repositories.ListRepo
}

// NewTemplateService creates a new TemplateService.
func NewTemplateService(templateRepo repositories.TemplateRepo, groupRepo repositories.GroupRepo, listRepo repositories.ListRepo) *TemplateService {
	return &TemplateService{
		templateRepo: templateRepo,
		groupRepo:    groupRepo,
		listRepo:     listRepo,
	}
}

func (s *TemplateService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return fmt.Errorf("failed to check membership: %w", err)
	}
	return nil
}

func (s *TemplateService) requireActiveVerifiedUser(u *models.User) error {
	if !u.IsActive || !u.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	return nil
}

// CreateTemplate creates a new list template.
func (s *TemplateService) CreateTemplate(ctx context.Context, user *models.User, template *models.Template) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	if err := s.requireMembership(ctx, user.ID, template.GroupID); err != nil {
		return err
	}
	if template.Name == "" {
		return &api.ValidationError{Field: "name", Message: "template name is required"}
	}
	return s.templateRepo.CreateTemplate(ctx, template)
}

// GetTemplate retrieves a list template by ID.
func (s *TemplateService) GetTemplate(ctx context.Context, user *models.User, templateID uuid.UUID) (*models.Template, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	template, err := s.templateRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "template", ID: templateID.String()}
		}
		return nil, fmt.Errorf("failed to get template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, template.GroupID); err != nil {
		return nil, err
	}
	return template, nil
}

// ListTemplates returns all list templates for a group.
func (s *TemplateService) ListTemplates(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.Template, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.templateRepo.ListTemplates(ctx, groupID, limit, offset)
}

// UpdateTemplate updates a list template.
func (s *TemplateService) UpdateTemplate(ctx context.Context, user *models.User, templateID uuid.UUID, name string) (*models.Template, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	template, err := s.templateRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "template", ID: templateID.String()}
		}
		return nil, fmt.Errorf("failed to get template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, template.GroupID); err != nil {
		return nil, err
	}
	if name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "template name is required"}
	}
	template.Name = name
	if err := s.templateRepo.UpdateTemplate(ctx, template); err != nil {
		return nil, fmt.Errorf("failed to update template: %w", err)
	}
	return template, nil
}

// DeleteTemplate deletes a list template.
func (s *TemplateService) DeleteTemplate(ctx context.Context, user *models.User, templateID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	template, err := s.templateRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "template", ID: templateID.String()}
		}
		return fmt.Errorf("failed to get template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, template.GroupID); err != nil {
		return err
	}
	return s.templateRepo.DeleteTemplate(ctx, templateID)
}

// ApplyTemplate creates a new list (and its items) from a list template.
func (s *TemplateService) ApplyTemplate(ctx context.Context, user *models.User, templateID uuid.UUID, listName string) (*models.List, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	template, err := s.templateRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "template", ID: templateID.String()}
		}
		return nil, fmt.Errorf("failed to get template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, template.GroupID); err != nil {
		return nil, err
	}

	tplItems, err := s.templateRepo.ListTemplateItems(ctx, templateID)
	if err != nil {
		return nil, fmt.Errorf("failed to list template items: %w", err)
	}

	name := listName
	if name == "" {
		name = template.Name
	}

	list := &models.List{
		GroupID: template.GroupID,
		Name:    name,
		Type:    "shopping",
	}
	if err := s.listRepo.CreateList(ctx, list); err != nil {
		return nil, fmt.Errorf("failed to create list: %w", err)
	}

	for i, ti := range tplItems {
		item := &models.ListItem{
			ListID:   list.ID,
			Name:     ti.Name,
			Quantity: float64(ti.Quantity),
			Unit:     ti.Unit,
			Position: i,
		}
		if err := s.listRepo.CreateItem(ctx, item); err != nil {
			return nil, fmt.Errorf("failed to create list item: %w", err)
		}
	}

	return list, nil
}

// CreateChoreTemplate creates a new chore template.
func (s *TemplateService) CreateChoreTemplate(ctx context.Context, user *models.User, ct *models.ChoreTemplate) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	if err := s.requireMembership(ctx, user.ID, ct.GroupID); err != nil {
		return err
	}
	if ct.Name == "" {
		return &api.ValidationError{Field: "name", Message: "chore template name is required"}
	}
	return s.templateRepo.CreateChoreTemplate(ctx, ct)
}

// GetChoreTemplate retrieves a chore template by ID.
func (s *TemplateService) GetChoreTemplate(ctx context.Context, user *models.User, templateID uuid.UUID) (*models.ChoreTemplate, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	ct, err := s.templateRepo.GetChoreTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore template", ID: templateID.String()}
		}
		return nil, fmt.Errorf("failed to get chore template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, ct.GroupID); err != nil {
		return nil, err
	}
	return ct, nil
}

// ListChoreTemplates returns all chore templates for a group.
func (s *TemplateService) ListChoreTemplates(ctx context.Context, user *models.User, groupID uuid.UUID, limit, offset int) ([]models.ChoreTemplate, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}
	return s.templateRepo.ListChoreTemplates(ctx, groupID, limit, offset)
}

// UpdateChoreTemplate updates a chore template.
func (s *TemplateService) UpdateChoreTemplate(ctx context.Context, user *models.User, ct *models.ChoreTemplate) (*models.ChoreTemplate, error) {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return nil, err
	}
	existing, err := s.templateRepo.GetChoreTemplateByID(ctx, ct.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "chore template", ID: ct.ID.String()}
		}
		return nil, fmt.Errorf("failed to get chore template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, existing.GroupID); err != nil {
		return nil, err
	}
	if ct.Name == "" {
		return nil, &api.ValidationError{Field: "name", Message: "chore template name is required"}
	}
	ct.GroupID = existing.GroupID
	if err := s.templateRepo.UpdateChoreTemplate(ctx, ct); err != nil {
		return nil, fmt.Errorf("failed to update chore template: %w", err)
	}
	return ct, nil
}

// DeleteChoreTemplate deletes a chore template.
func (s *TemplateService) DeleteChoreTemplate(ctx context.Context, user *models.User, templateID uuid.UUID) error {
	if err := s.requireActiveVerifiedUser(user); err != nil {
		return err
	}
	ct, err := s.templateRepo.GetChoreTemplateByID(ctx, templateID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "chore template", ID: templateID.String()}
		}
		return fmt.Errorf("failed to get chore template: %w", err)
	}
	if err := s.requireMembership(ctx, user.ID, ct.GroupID); err != nil {
		return err
	}
	return s.templateRepo.DeleteChoreTemplate(ctx, templateID)
}
