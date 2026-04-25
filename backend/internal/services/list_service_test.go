package services

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func validUser() *models.User {
	return &models.User{
		ID:         uuid.New(),
		Email:      "test@example.com",
		FirstName:  "Test",
		LastName:   "User",
		IsActive:   true,
		IsVerified: true,
	}
}

func TestListService_CreateList(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("CreateList", ctx, mock.AnythingOfType("*models.List")).Return(nil)

		list := &models.List{GroupID: groupID, Name: "Shopping"}
		err := svc.CreateList(ctx, user, list)
		require.NoError(t, err)
	})

	t.Run("inactive user", func(t *testing.T) {
		svc := NewListService(nil, nil)
		inactive := &models.User{IsActive: false, IsVerified: true}
		err := svc.CreateList(ctx, inactive, &models.List{})
		require.Error(t, err)
		assert.IsType(t, &api.PermissionDeniedError{}, err)
	})

	t.Run("missing name", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(nil, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		err := svc.CreateList(ctx, user, &models.List{GroupID: groupID, Name: ""})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestListService_GetList(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		l, err := svc.GetList(ctx, user, listID)
		require.NoError(t, err)
		assert.Equal(t, listID, l.ID)
	})

	t.Run("not found", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		svc := NewListService(listRepo, nil)

		listRepo.On("GetListByID", ctx, listID).Return(nil, pgx.ErrNoRows)

		_, err := svc.GetList(ctx, user, listID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})
}

func TestListService_ListLists(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("ListListsByGroup", ctx, groupID, 10, 0).Return([]models.List{{ID: uuid.New()}}, nil)

		lists, err := svc.ListLists(ctx, user, groupID, 10, 0)
		require.NoError(t, err)
		assert.Len(t, lists, 1)
	})
}

func TestListService_UpdateList(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID, Name: "Old"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("UpdateList", ctx, mock.AnythingOfType("*models.List")).Return(nil)

		l, err := svc.UpdateList(ctx, user, listID, "New", "shopping")
		require.NoError(t, err)
		assert.Equal(t, "New", l.Name)
	})
}

func TestListService_DeleteList(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("HardDeleteList", ctx, listID).Return(nil)

		err := svc.DeleteList(ctx, user, listID)
		require.NoError(t, err)
	})
}

func TestListService_CreateItem(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("CreateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		item := &models.ListItem{ListID: listID, Name: "Milk"}
		err := svc.CreateItem(ctx, user, item)
		require.NoError(t, err)
	})

	t.Run("missing item name", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		item := &models.ListItem{ListID: listID, Name: ""}
		err := svc.CreateItem(ctx, user, item)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestListService_GetItem(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	itemID := uuid.New()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetItemByID", ctx, itemID).Return(&models.ListItem{ID: itemID, ListID: listID}, nil)
		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)

		item, err := svc.GetItem(ctx, user, itemID)
		require.NoError(t, err)
		assert.Equal(t, itemID, item.ID)
	})
}

func TestListService_UpdateItem(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	itemID := uuid.New()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetItemByID", ctx, itemID).Return(&models.ListItem{ID: itemID, ListID: listID}, nil)
		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("UpdateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		item := &models.ListItem{ID: itemID, Name: "Updated"}
		err := svc.UpdateItem(ctx, user, item)
		require.NoError(t, err)
	})
}

func TestListService_DeleteItem(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	itemID := uuid.New()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetItemByID", ctx, itemID).Return(&models.ListItem{ID: itemID, ListID: listID}, nil)
		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("SoftDeleteItem", ctx, itemID).Return(nil)

		err := svc.DeleteItem(ctx, user, itemID)
		require.NoError(t, err)
	})
}

func TestListService_ReorderItems(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()
	item1 := uuid.New()
	item2 := uuid.New()

	t.Run("success", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("ListItemsByList", ctx, listID, 0, 0).Return([]models.ListItem{
			{ID: item1}, {ID: item2},
		}, nil)
		listRepo.On("UpdateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		err := svc.ReorderItems(ctx, user, listID, []uuid.UUID{item2, item1})
		require.NoError(t, err)
	})

	t.Run("item not in list", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{}, nil)
		listRepo.On("ListItemsByList", ctx, listID, 0, 0).Return([]models.ListItem{{ID: item1}}, nil)

		err := svc.ReorderItems(ctx, user, listID, []uuid.UUID{item2})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}
