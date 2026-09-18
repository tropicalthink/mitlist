package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
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

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
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

		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

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

		lid := uuid.New()
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("ListListsByGroup", ctx, groupID, 10, 0).Return([]models.List{{ID: lid}}, nil)
		listRepo.On("ListItemPreviewLinesByListIDs", ctx, []uuid.UUID{lid}, listHubPreviewLines).
			Return(map[uuid.UUID][]string{lid: {"milk", "eggs"}}, nil)

		lists, err := svc.ListLists(ctx, user, groupID, 10, 0)
		require.NoError(t, err)
		require.Len(t, lists, 1)
		assert.Equal(t, []string{"milk", "eggs"}, lists[0].ItemPreview)
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("UpdateList", ctx, mock.AnythingOfType("*models.List")).Return(nil)

		l, err := svc.UpdateList(ctx, user, listID, "New", "shopping")
		require.NoError(t, err)
		assert.Equal(t, "New", l.Name)
	})
}

func TestListService_SetListReminder(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	t.Run("schedules a future reminder", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)
		remindAt := time.Now().Add(2 * time.Hour)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID, Name: "Groceries"}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("SetListReminder", ctx, listID, mock.AnythingOfType("*time.Time")).Return(nil)

		l, err := svc.SetListReminder(ctx, user, listID, &remindAt)
		require.NoError(t, err)
		require.NotNil(t, l.RemindAt)
		assert.Equal(t, remindAt.UTC(), *l.RemindAt)
		assert.Nil(t, l.ReminderSentAt)
		listRepo.AssertExpectations(t)
	})

	t.Run("rejects a past time", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)
		past := time.Now().Add(-time.Minute)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

		_, err := svc.SetListReminder(ctx, user, listID, &past)
		var verr *api.ValidationError
		require.ErrorAs(t, err, &verr)
		assert.Equal(t, "remind_at", verr.Field)
		listRepo.AssertNotCalled(t, "SetListReminder", mock.Anything, mock.Anything, mock.Anything)
	})

	t.Run("clears with nil", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)
		existing := time.Now().Add(time.Hour)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID, RemindAt: &existing}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("SetListReminder", ctx, listID, (*time.Time)(nil)).Return(nil)

		l, err := svc.SetListReminder(ctx, user, listID, nil)
		require.NoError(t, err)
		assert.Nil(t, l.RemindAt)
		listRepo.AssertExpectations(t)
	})

	t.Run("requires membership", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)
		remindAt := time.Now().Add(time.Hour)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(nil, pgx.ErrNoRows)

		_, err := svc.SetListReminder(ctx, user, listID, &remindAt)
		require.Error(t, err)
		listRepo.AssertNotCalled(t, "SetListReminder", mock.Anything, mock.Anything, mock.Anything)
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)

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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("UpdateItem", ctx, mock.AnythingOfType("*models.ListItem")).Return(nil)

		item := &models.ListItem{ID: itemID, Name: "Updated", Quantity: 1}
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("SoftDeleteItem", ctx, itemID).Return(nil)

		err := svc.DeleteItem(ctx, user, itemID)
		require.NoError(t, err)
	})
}

func TestListService_ClearItems(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("SoftDeleteItemsByList", ctx, listID, true).Return(2, nil)

	deleted, err := svc.ClearItems(ctx, user, listID, true)
	require.NoError(t, err)
	assert.EqualValues(t, 2, deleted)
}

func TestListService_AddItemAmount_IncrementsExisting(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()
	itemID := uuid.New()

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("GetItemByListNameUnit", ctx, listID, "Milk", "L").Return(&models.ListItem{
		ID: itemID, ListID: listID, Name: "Milk", Quantity: 2, Unit: "L", Checked: true,
	}, nil)
	listRepo.On("UpdateItem", ctx, mock.MatchedBy(func(item *models.ListItem) bool {
		return item.ID == itemID && item.Quantity == 5 && !item.Checked && item.Note == "whole"
	})).Return(nil)

	item, err := svc.AddItemAmount(ctx, user, listID, " Milk ", 3, " L ", " whole ")
	require.NoError(t, err)
	assert.Equal(t, 5.0, item.Quantity)
}

func TestListService_AddItemAmount_CreatesWhenMissing(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("GetItemByListNameUnit", ctx, listID, "Milk", "").Return(nil, pgx.ErrNoRows)
	listRepo.On("CreateItem", ctx, mock.MatchedBy(func(item *models.ListItem) bool {
		return item.ListID == listID && item.Name == "Milk" && item.Quantity == 2
	})).Return(nil)

	item, err := svc.AddItemAmount(ctx, user, listID, "Milk", 2, "", "")
	require.NoError(t, err)
	assert.Equal(t, "Milk", item.Name)
}

func TestListService_RemoveItemAmount_DecrementsOrDeletes(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()
	itemID := uuid.New()

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("GetItemByListNameUnit", ctx, listID, "Milk", "").Return(&models.ListItem{
		ID: itemID, ListID: listID, Name: "Milk", Quantity: 2,
	}, nil)
	listRepo.On("SoftDeleteItem", ctx, itemID).Return(nil)

	item, removed, err := svc.RemoveItemAmount(ctx, user, listID, "Milk", 2, "")
	require.NoError(t, err)
	assert.True(t, removed)
	assert.Equal(t, itemID, item.ID)
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
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("ListItemsByList", ctx, listID, 10000, 0).Return([]models.ListItem{
			{ID: item1}, {ID: item2},
		}, nil)
		listRepo.On("BatchUpdateItemPositions", ctx, mock.AnythingOfType("[]models.ListItem")).Return(nil)

		err := svc.ReorderItems(ctx, user, listID, []uuid.UUID{item2, item1})
		require.NoError(t, err)
	})

	t.Run("item not in list", func(t *testing.T) {
		listRepo := new(mocks.MockListRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewListService(listRepo, groupRepo)

		listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
		listRepo.On("ListItemsByList", ctx, listID, 10000, 0).Return([]models.ListItem{{ID: item1}}, nil)

		err := svc.ReorderItems(ctx, user, listID, []uuid.UUID{item2})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestListService_BulkCompleteItems(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	itemIDs := []uuid.UUID{uuid.New(), uuid.New()}

	listRepo := new(mocks.MockListRepo)
	svc := NewListService(listRepo, nil)

	listRepo.On("BulkMarkItemsChecked", ctx, user.ID, itemIDs).Return(int64(2), nil)

	count, err := svc.BulkCompleteItems(ctx, user, itemIDs)
	require.NoError(t, err)
	assert.Equal(t, 2, count)
	listRepo.AssertNotCalled(t, "GetItemByID", ctx, mock.Anything)
	listRepo.AssertNotCalled(t, "UpdateItem", ctx, mock.Anything)
}

func TestListService_GetShoppingTrip_BatchesListAndItemQueries(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	groupID := uuid.New()
	listID1 := uuid.New()
	listID2 := uuid.New()
	listIDs := []uuid.UUID{listID1, listID2}

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	lists := []models.List{
		{ID: listID1, GroupID: groupID, Name: "Groceries"},
		{ID: listID2, GroupID: groupID, Name: "Hardware"},
	}
	itemsByList := map[uuid.UUID][]models.ListItem{
		listID1: {{ID: uuid.New(), ListID: listID1, Name: "Milk"}},
		listID2: {{ID: uuid.New(), ListID: listID2, Name: "Screws"}},
	}

	listRepo.On("GetListsByIDs", ctx, listIDs).Return(lists, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("ListItemsByListIDs", ctx, listIDs).Return(itemsByList, nil)

	result, err := svc.GetShoppingTrip(ctx, user, listIDs)
	require.NoError(t, err)
	require.Len(t, result, 2)
	assert.Equal(t, "Groceries", result[0].ListName)
	assert.Equal(t, "Milk", result[0].Items[0].Name)
	assert.Equal(t, "Hardware", result[1].ListName)

	listRepo.AssertNotCalled(t, "GetListByID", ctx, mock.Anything)
	listRepo.AssertNotCalled(t, "ListItemsByList", ctx, mock.Anything, mock.Anything, mock.Anything)
}

func TestListService_AddItemsBatch_SingleListFetch(t *testing.T) {
	ctx := context.Background()
	user := validUser()
	listID := uuid.New()
	groupID := uuid.New()
	existingID := uuid.New()

	listRepo := new(mocks.MockListRepo)
	groupRepo := new(mocks.MockGroupRepo)
	svc := NewListService(listRepo, groupRepo)

	listRepo.On("GetListByID", ctx, listID).Return(&models.List{ID: listID, GroupID: groupID}, nil)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{Role: "member"}, nil)
	listRepo.On("ListItemsByList", ctx, listID, 0, 0).Return([]models.ListItem{
		{ID: existingID, ListID: listID, Name: "Milk", Unit: "L", Quantity: 1},
	}, nil)
	listRepo.On("UpdateItem", ctx, mock.MatchedBy(func(item *models.ListItem) bool {
		return item.ID == existingID && item.Quantity == 3
	})).Return(nil)
	listRepo.On("CreateItem", ctx, mock.MatchedBy(func(item *models.ListItem) bool {
		return item.Name == "Eggs" && item.Quantity == 6
	})).Return(nil)

	items, err := svc.AddItemsBatch(ctx, user, listID, []ListItemAmountInput{
		{Name: "Milk", Amount: 2, Unit: "L"},
		{Name: "Eggs", Amount: 6, Unit: ""},
	})
	require.NoError(t, err)
	require.Len(t, items, 2)
	listRepo.AssertNumberOfCalls(t, "GetListByID", 1)
	listRepo.AssertNotCalled(t, "GetItemByListNameUnit", ctx, mock.Anything, mock.Anything, mock.Anything, mock.Anything)
}
