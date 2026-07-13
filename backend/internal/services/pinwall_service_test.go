package services

import (
	"context"
	"math"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func newActiveUser(id uuid.UUID) *models.User {
	return &models.User{ID: id, IsActive: true, IsVerified: true}
}

func TestPinwallService_CreatePost(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	user := newActiveUser(userID)

	t.Run("success", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("CreatePost", ctx, &models.PinwallPost{
			GroupID: groupID,
			UserID:  userID,
			Content: "Hello household!",
		}).Return(nil)

		post, err := svc.CreatePost(ctx, user, groupID, "Hello household!", nil)
		require.NoError(t, err)
		require.NotNil(t, post)
		assert.Equal(t, "Hello household!", post.Content)
		assert.Equal(t, groupID, post.GroupID)
		assert.Equal(t, userID, post.UserID)
	})

	t.Run("inactive user is rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		inactiveUser := &models.User{ID: userID, IsActive: false, IsVerified: true}
		_, err := svc.CreatePost(ctx, inactiveUser, groupID, "Hi", nil)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})

	t.Run("unverified user is rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		unverifiedUser := &models.User{ID: userID, IsActive: true, IsVerified: false}
		_, err := svc.CreatePost(ctx, unverifiedUser, groupID, "Hi", nil)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})

	t.Run("non-member is rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.CreatePost(ctx, user, groupID, "Hi", nil)
		require.Error(t, err)
	})

	t.Run("empty content is rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		_, err := svc.CreatePost(ctx, user, groupID, "   ", nil)
		require.Error(t, err)
		var ve *api.ValidationError
		assert.ErrorAs(t, err, &ve)
	})

	t.Run("remind_at in past is rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		past := time.Now().Add(-1 * time.Hour)
		_, err := svc.CreatePost(ctx, user, groupID, "Reminder", &past)
		require.Error(t, err)
		var ve *api.ValidationError
		assert.ErrorAs(t, err, &ve)
	})
}

func TestPinwallService_ListPosts(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	user := newActiveUser(userID)

	t.Run("success returns posts", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		posts := []models.PinwallPost{
			{ID: uuid.New(), GroupID: groupID, UserID: userID, Content: "Post A"},
			{ID: uuid.New(), GroupID: groupID, UserID: userID, Content: "Post B"},
		}
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("ListPostsByGroup", ctx, groupID, 20, 0).Return(posts, nil)

		result, err := svc.ListPosts(ctx, user, groupID, 20, 0)
		require.NoError(t, err)
		assert.Len(t, result, 2)
		assert.Equal(t, "Post A", result[0].Content)
	})

	t.Run("non-member denied", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.ListPosts(ctx, user, groupID, 20, 0)
		require.Error(t, err)
	})
}

func TestPinwallService_DeletePost(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	postID := uuid.New()
	user := newActiveUser(userID)

	t.Run("success", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("GetPostByID", ctx, postID).Return(&models.PinwallPost{ID: postID, GroupID: groupID}, nil)
		pinwallRepo.On("DeletePost", ctx, postID).Return(nil)

		err := svc.DeletePost(ctx, user, groupID, postID)
		require.NoError(t, err)
	})

	t.Run("post not found", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("GetPostByID", ctx, postID).Return(nil, pgx.ErrNoRows)

		err := svc.DeletePost(ctx, user, groupID, postID)
		require.Error(t, err)
		var nfe *api.NotFoundError
		assert.ErrorAs(t, err, &nfe)
	})

	t.Run("post from different group rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		otherGroupID := uuid.New()
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("GetPostByID", ctx, postID).Return(&models.PinwallPost{ID: postID, GroupID: otherGroupID}, nil)

		err := svc.DeletePost(ctx, user, groupID, postID)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})
}

func TestPinwallService_UpdatePostPosition(t *testing.T) {
	ctx := context.Background()
	groupID := uuid.New()
	userID := uuid.New()
	postID := uuid.New()
	user := newActiveUser(userID)

	t.Run("success returns positioned post", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("GetPostByID", ctx, postID).Return(&models.PinwallPost{ID: postID, GroupID: groupID}, nil)
		pinwallRepo.On("UpdatePostPosition", ctx, postID, 120.5, 340.0).Return(nil)

		post, err := svc.UpdatePostPosition(ctx, user, groupID, postID, 120.5, 340.0)
		require.NoError(t, err)
		require.NotNil(t, post)
		require.NotNil(t, post.PosX)
		require.NotNil(t, post.PosY)
		assert.Equal(t, 120.5, *post.PosX)
		assert.Equal(t, 340.0, *post.PosY)
	})

	t.Run("non-finite coordinate rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		_, err := svc.UpdatePostPosition(ctx, user, groupID, postID, math.Inf(1), 0)
		require.Error(t, err)
		var ve *api.ValidationError
		assert.ErrorAs(t, err, &ve)
	})

	t.Run("negative coordinate rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)

		_, err := svc.UpdatePostPosition(ctx, user, groupID, postID, -5, 10)
		require.Error(t, err)
		var ve *api.ValidationError
		assert.ErrorAs(t, err, &ve)
	})

	t.Run("post from different group rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		otherGroupID := uuid.New()
		groupRepo.On("GetMembership", ctx, groupID, userID).Return(&models.GroupMembership{Role: "member"}, nil)
		pinwallRepo.On("GetPostByID", ctx, postID).Return(&models.PinwallPost{ID: postID, GroupID: otherGroupID}, nil)

		_, err := svc.UpdatePostPosition(ctx, user, groupID, postID, 10, 10)
		require.Error(t, err)
		var pe *api.PermissionDeniedError
		assert.ErrorAs(t, err, &pe)
	})

	t.Run("non-member rejected", func(t *testing.T) {
		pinwallRepo := new(mocks.MockPinwallRepo)
		groupRepo := new(mocks.MockGroupRepo)
		svc := NewPinwallService(pinwallRepo, groupRepo)

		groupRepo.On("GetMembership", ctx, groupID, userID).Return(nil, pgx.ErrNoRows)

		_, err := svc.UpdatePostPosition(ctx, user, groupID, postID, 10, 10)
		require.Error(t, err)
	})
}
