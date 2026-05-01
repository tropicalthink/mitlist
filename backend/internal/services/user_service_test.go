package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories/mocks"
)

func TestUserService_Register(t *testing.T) {
	ctx := context.Background()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		jwtSvc := new(mocks.MockJWTService)
		passSvc := new(mocks.MockPasswordService)
		mailSvc := new(mocks.MockMailService)
		svc := NewUserService(userRepo, authRepo, jwtSvc, passSvc, mailSvc)

		userRepo.On("GetByEmail", ctx, "new@example.com").Return(nil, errors.New("user not found"))
		passSvc.On("Hash", "password123").Return("hashed", nil)
		userRepo.On("Create", ctx, mock.AnythingOfType("*models.User")).Return(nil)

		user, err := svc.Register(ctx, RegisterInput{Email: "new@example.com", Password: "password123", FirstName: "New", LastName: "User"})
		require.NoError(t, err)
		assert.Equal(t, "new@example.com", user.Email)
		assert.Equal(t, "hashed", user.PasswordHash)
		assert.True(t, user.IsActive)
		assert.True(t, user.IsVerified)
	})

	t.Run("missing email or password", func(t *testing.T) {
		svc := NewUserService(nil, nil, nil, nil, nil)
		_, err := svc.Register(ctx, RegisterInput{Email: "", Password: ""})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("password too short", func(t *testing.T) {
		svc := NewUserService(nil, nil, nil, nil, nil)
		_, err := svc.Register(ctx, RegisterInput{Email: "a@b.com", Password: "123"})
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("email already registered", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		existing := &models.User{Email: "existing@example.com"}
		userRepo.On("GetByEmail", ctx, "existing@example.com").Return(existing, nil)

		_, err := svc.Register(ctx, RegisterInput{Email: "existing@example.com", Password: "password123"})
		require.Error(t, err)
		assert.IsType(t, &api.ConflictError{}, err)
	})
}

func TestUserService_Login(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		jwtSvc := new(mocks.MockJWTService)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, jwtSvc, passSvc, nil)

		user := &models.User{ID: userID, Email: "test@example.com", PasswordHash: "hash", IsActive: true, IsVerified: true}
		userRepo.On("GetByEmail", ctx, "test@example.com").Return(user, nil)
		passSvc.On("Compare", "hash", "password123").Return(true)
		jwtSvc.On("GenerateTokenPair", userID.String(), []string{}).Return("access", "refresh", nil)

		u, access, refresh, err := svc.Login(ctx, "test@example.com", "password123")
		require.NoError(t, err)
		assert.Equal(t, userID, u.ID)
		assert.Equal(t, "access", access)
		assert.Equal(t, "refresh", refresh)
	})

	t.Run("invalid credentials", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		userRepo.On("GetByEmail", ctx, "test@example.com").Return(nil, errors.New("user not found"))

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "invalid email or password", err.Error())
	})

	t.Run("wrong password", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, Email: "test@example.com", PasswordHash: "hash", IsActive: true, IsVerified: true}
		userRepo.On("GetByEmail", ctx, "test@example.com").Return(user, nil)
		passSvc.On("Compare", "hash", "wrongpassword").Return(false)

		_, _, _, err := svc.Login(ctx, "test@example.com", "wrongpassword")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "invalid email or password", err.Error())
	})

	t.Run("inactive user", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, Email: "test@example.com", PasswordHash: "hash", IsActive: false, IsVerified: true}
		userRepo.On("GetByEmail", ctx, "test@example.com").Return(user, nil)
		passSvc.On("Compare", "hash", "password123").Return(true)

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "account is inactive", err.Error())
	})

	t.Run("unverified user", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, Email: "test@example.com", PasswordHash: "hash", IsActive: true, IsVerified: false}
		userRepo.On("GetByEmail", ctx, "test@example.com").Return(user, nil)
		passSvc.On("Compare", "hash", "password123").Return(true)

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "account is not verified", err.Error())
	})
}

func TestUserService_GetMe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)

		u, err := svc.GetMe(ctx, userID)
		require.NoError(t, err)
		assert.Equal(t, userID, u.ID)
	})

	t.Run("not found", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		userRepo.On("GetByID", ctx, userID).Return(nil, errors.New("user not found"))

		_, err := svc.GetMe(ctx, userID)
		require.Error(t, err)
		assert.IsType(t, &api.NotFoundError{}, err)
	})

	t.Run("inactive user", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: false, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)

		_, err := svc.GetMe(ctx, userID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "account is inactive", err.Error())
	})

	t.Run("unverified user", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: true, IsVerified: false}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)

		_, err := svc.GetMe(ctx, userID)
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "account is not verified", err.Error())
	})
}

func TestUserService_UpdateMe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		userRepo.On("Update", ctx, user).Return(nil)

		name := "Updated"
		u, err := svc.UpdateMe(ctx, userID, UpdateMeInput{FirstName: &name})
		require.NoError(t, err)
		assert.Equal(t, "Updated", u.FirstName)
	})
}

func TestUserService_DeleteMe(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		userRepo.On("SoftDelete", ctx, userID).Return(nil)

		err := svc.DeleteMe(ctx, userID)
		require.NoError(t, err)
	})
}

func TestUserService_ChangePassword(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, PasswordHash: "oldhash", IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Compare", "oldhash", "oldpassword").Return(true)
		passSvc.On("Hash", "newpassword").Return("newhash", nil)
		userRepo.On("Update", ctx, user).Return(nil)

		err := svc.ChangePassword(ctx, userID, "oldpassword", "newpassword")
		require.NoError(t, err)
	})

	t.Run("incorrect current password", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, PasswordHash: "oldhash", IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Compare", "oldhash", "wrong").Return(false)

		err := svc.ChangePassword(ctx, userID, "wrong", "newpassword")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestUserService_RequestPasswordReset(t *testing.T) {
	ctx := context.Background()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		mailSvc := new(mocks.MockMailService)
		svc := NewUserService(userRepo, authRepo, nil, nil, mailSvc)

		user := &models.User{ID: uuid.New(), Email: "test@example.com", IsActive: true, IsVerified: true}
		userRepo.On("GetByEmail", ctx, "test@example.com").Return(user, nil)
		authRepo.On("CreatePasswordResetToken", ctx, mock.AnythingOfType("*models.PasswordResetToken")).Return(nil)
		mailSvc.On("Send", user.Email, "Password Reset", mock.AnythingOfType("string"), false).Return(nil)

		err := svc.RequestPasswordReset(ctx, "test@example.com")
		require.NoError(t, err)
	})

	t.Run("email not found returns nil", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		userRepo.On("GetByEmail", ctx, "missing@example.com").Return(nil, errors.New("user not found"))

		err := svc.RequestPasswordReset(ctx, "missing@example.com")
		require.NoError(t, err)
	})
}

func TestUserService_ConfirmPasswordReset(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	tokenID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, authRepo, nil, passSvc, nil)

		resetToken := &models.PasswordResetToken{ID: tokenID, UserID: userID, Token: "abc", ExpiresAt: time.Now().UTC().Add(time.Hour)}
		authRepo.On("GetPasswordResetToken", ctx, "abc").Return(resetToken, nil)
		user := &models.User{ID: userID, IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Hash", "newpassword").Return("newhash", nil)
		userRepo.On("Update", ctx, user).Return(nil)
		authRepo.On("ConsumeToken", ctx, tokenID).Return(nil)

		err := svc.ConfirmPasswordReset(ctx, "abc", "newpassword")
		require.NoError(t, err)
	})

	t.Run("token already used", func(t *testing.T) {
		authRepo := new(mocks.MockAuthRepo)
		svc := NewUserService(nil, authRepo, nil, nil, nil)

		now := time.Now().UTC()
		resetToken := &models.PasswordResetToken{ID: tokenID, UsedAt: &now}
		authRepo.On("GetPasswordResetToken", ctx, "used").Return(resetToken, nil)

		err := svc.ConfirmPasswordReset(ctx, "used", "newpassword")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("token expired", func(t *testing.T) {
		authRepo := new(mocks.MockAuthRepo)
		svc := NewUserService(nil, authRepo, nil, nil, nil)

		resetToken := &models.PasswordResetToken{ID: tokenID, ExpiresAt: time.Now().UTC().Add(-time.Hour)}
		authRepo.On("GetPasswordResetToken", ctx, "expired").Return(resetToken, nil)

		err := svc.ConfirmPasswordReset(ctx, "expired", "newpassword")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestUserService_ClaimAccount(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, IsGuest: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Hash", "password123").Return("hash", nil)
		userRepo.On("Update", ctx, user).Return(nil)

		u, err := svc.ClaimAccount(ctx, userID, ClaimAccountInput{Password: "password123", FirstName: "Test", LastName: "User"})
		require.NoError(t, err)
		assert.False(t, u.IsGuest)
		assert.True(t, u.IsActive)
		assert.True(t, u.IsVerified)
	})

	t.Run("already claimed", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		svc := NewUserService(userRepo, nil, nil, nil, nil)

		user := &models.User{ID: userID, IsActive: true, IsVerified: true, PasswordHash: "hash", IsGuest: false}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)

		_, err := svc.ClaimAccount(ctx, userID, ClaimAccountInput{Password: "password123"})
		require.Error(t, err)
		assert.IsType(t, &api.ConflictError{}, err)
	})
}

func TestIsNotFound(t *testing.T) {
	assert.True(t, isNotFound(pgx.ErrNoRows))
	assert.True(t, isNotFound(errors.New("user not found")))
	assert.True(t, isNotFound(errors.New("oauth account not found")))
	assert.False(t, isNotFound(nil))
	assert.False(t, isNotFound(errors.New("some other error")))
}
