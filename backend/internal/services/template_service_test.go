package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestTemplateService_CreateTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		templateRepo.On("CreateTemplate", ctx, mock.AnythingOfType("*models.Template")).Return(nil)

		template := &models.Template{GroupID: groupID, Name: "TPL"}
		err := svc.CreateTemplate(ctx, user, template)
		require.NoError(t, err)
	})

	t.Run("missing name", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(nil, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		err := svc.CreateTemplate(ctx, user, &models.Template{GroupID: groupID, Name: ""})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestTemplateService_GetTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	templateID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		templateRepo.On("GetTemplateByID", ctx, templateID).Return(&models.Template{ID: templateID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		tpl, err := svc.GetTemplate(ctx, user, templateID)
		require.NoError(t, err)
		assert.Equal(t, templateID, tpl.ID)
	})

	t.Run("not found", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		svc := NewTemplateService(templateRepo, nil, nil)

		templateRepo.On("GetTemplateByID", ctx, templateID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetTemplate(ctx, user, templateID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}

func TestTemplateService_ApplyTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	templateID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		listRepo := new(mocks.MockListRepo)
		svc := NewTemplateService(templateRepo, groupRepo, listRepo)

		templateRepo.On("GetTemplateByID", ctx, templateID).Return(&models.Template{ID: templateID, GroupID: groupID, Name: "TPL"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		templateRepo.On("ListTemplateItems", ctx, templateID).Return([]models.TemplateItem{
			{Name: "A", Quantity: 1, Unit: "pc"},
		}, nil)
		listRepo.On("CreateList", ctx, mock.AnythingOfType("*models.List")).Return(nil)
		listRepo.On("CreateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		list, err := svc.ApplyTemplate(ctx, user, templateID, "")
		require.NoError(t, err)
		assert.Equal(t, "TPL", list.Name)
	})
}

func TestTemplateService_CreateChoreTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		templateRepo.On("CreateChoreTemplate", ctx, mock.AnythingOfType("*models.ChoreTemplate")).Return(nil)

		ct := &models.ChoreTemplate{GroupID: groupID, Name: "CT"}
		err := svc.CreateChoreTemplate(ctx, user, ct)
		require.NoError(t, err)
	})
}

func TestTemplateService_GetChoreTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	templateID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		templateRepo.On("GetChoreTemplateByID", ctx, templateID).Return(&models.ChoreTemplate{ID: templateID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		ct, err := svc.GetChoreTemplate(ctx, user, templateID)
		require.NoError(t, err)
		assert.Equal(t, templateID, ct.ID)
	})
}

func TestTemplateService_UpdateChoreTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	templateID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		templateRepo.On("GetChoreTemplateByID", ctx, templateID).Return(&models.ChoreTemplate{ID: templateID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		templateRepo.On("UpdateChoreTemplate", ctx, mock.AnythingOfType("*models.ChoreTemplate")).Return(nil)

		ct := &models.ChoreTemplate{ID: templateID, Name: "Updated"}
		updated, err := svc.UpdateChoreTemplate(ctx, user, ct)
		require.NoError(t, err)
		assert.Equal(t, "Updated", updated.Name)
	})
}

func TestTemplateService_DeleteChoreTemplate(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	templateID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		templateRepo := new(mocks.MockTemplateRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewTemplateService(templateRepo, groupRepo, nil)

		templateRepo.On("GetChoreTemplateByID", ctx, templateID).Return(&models.ChoreTemplate{ID: templateID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		templateRepo.On("DeleteChoreTemplate", ctx, templateID).Return(nil)

		err := svc.DeleteChoreTemplate(ctx, user, templateID)
		require.NoError(t, err)
	})
}
