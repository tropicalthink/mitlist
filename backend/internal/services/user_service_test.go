package services

import (
	"context"
	"errors"
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
		passSvc.On("Hash", "password123!").Return("hashed", nil)
		authRepo.On("CreateUnverifiedUser", ctx, mock.AnythingOfType("*models.User"), mock.AnythingOfType("string"), mock.AnythingOfType("time.Time")).Return(nil)
		mailSvc.On("Send", "new@example.com", "Verify your mitlist account", mock.AnythingOfType("string"), false).Return(nil)

		user, err := svc.Register(ctx, RegisterInput{Email: "new@example.com", Password: "password123!", FirstName: "New", LastName: "User"})
		require.NoError(t, err)
		assert.Equal(t, "new@example.com", user.Email)
		assert.Equal(t, "hashed", user.PasswordHash)
		assert.True(t, user.IsActive)
		assert.False(t, user.IsVerified)
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

		_, err := svc.Register(ctx, RegisterInput{Email: "existing@example.com", Password: "password123!"})
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
		passSvc.On("Compare", "hash", "password123!").Return(true)
		jwtSvc.On("GenerateTokenPair", userID.String(), []string{}).Return("access", "refresh", nil)

		u, access, refresh, err := svc.Login(ctx, "test@example.com", "password123!")
		require.NoError(t, err)
		assert.Equal(t, userID, u.ID)
		assert.Equal(t, "access", access)
		assert.Equal(t, "refresh", refresh)
	})

	t.Run("invalid credentials", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		userRepo.On("GetByEmail", ctx, "test@example.com").Return(nil, errors.New("user not found"))
		passSvc.On("Compare", dummyPasswordHash, "password123!").Return(false)

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123!")
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
		passSvc.On("Compare", "hash", "password123!").Return(true)

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123!")
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
		passSvc.On("Compare", "hash", "password123!").Return(true)

		_, _, _, err := svc.Login(ctx, "test@example.com", "password123!")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
		assert.Equal(t, "account is not verified", err.Error())
	})
}

func TestUserService_VerifyEmail(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()
	authRepo := new(mocks.MockAuthRepo)
	userRepo := new(mocks.MockUserRepo)
	svc := NewUserService(userRepo, authRepo, nil, nil, nil)

	authRepo.On("ConsumeEmailVerification", ctx, resetTokenHash("verification-code")).Return(userID, nil)
	userRepo.On("GetByID", ctx, userID).Return(&models.User{ID: userID, Email: "verified@example.com", IsVerified: true}, nil)

	user, err := svc.VerifyEmail(ctx, "verification-code")
	require.NoError(t, err)
	assert.True(t, user.IsVerified)
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
		authRepo := new(mocks.MockAuthRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, authRepo, nil, passSvc, nil)

		user := &models.User{ID: userID, PasswordHash: "oldhash", IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Compare", "oldhash", "oldpassword12!").Return(true)
		passSvc.On("Hash", "newpassword12!").Return("newhash", nil)
		authRepo.On("UpdatePasswordAndRevokeSessions", ctx, userID, "newhash").Return(nil)

		err := svc.ChangePassword(ctx, userID, "oldpassword12!", "newpassword12!")
		require.NoError(t, err)
	})

	t.Run("incorrect current password", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, nil, passSvc, nil)

		user := &models.User{ID: userID, PasswordHash: "oldhash", IsActive: true, IsVerified: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Compare", "oldhash", "wrong").Return(false)

		err := svc.ChangePassword(ctx, userID, "wrong", "newpassword12!")
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

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		authRepo := new(mocks.MockAuthRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, authRepo, nil, passSvc, nil)

		passSvc.On("Hash", "newpassword12!").Return("newhash", nil)
		authRepo.On("ConsumePasswordReset", ctx, resetTokenHash("abc"), "newhash").Return(userID, nil)

		err := svc.ConfirmPasswordReset(ctx, "abc", "newpassword12!")
		require.NoError(t, err)
	})

	t.Run("token already used", func(t *testing.T) {
		authRepo := new(mocks.MockAuthRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(nil, authRepo, nil, passSvc, nil)

		passSvc.On("Hash", "newpassword12!").Return("newhash", nil)
		authRepo.On("ConsumePasswordReset", ctx, resetTokenHash("used"), "newhash").Return(uuid.Nil, pgx.ErrNoRows)

		err := svc.ConfirmPasswordReset(ctx, "used", "newpassword12!")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})

	t.Run("token expired", func(t *testing.T) {
		authRepo := new(mocks.MockAuthRepo)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(nil, authRepo, nil, passSvc, nil)

		passSvc.On("Hash", "newpassword12!").Return("newhash", nil)
		authRepo.On("ConsumePasswordReset", ctx, resetTokenHash("expired"), "newhash").Return(uuid.Nil, pgx.ErrNoRows)

		err := svc.ConfirmPasswordReset(ctx, "expired", "newpassword12!")
		require.Error(t, err)
		assert.IsType(t, &api.ValidationError{}, err)
	})
}

func TestUserService_ClaimAccount(t *testing.T) {
	ctx := context.Background()
	userID := uuid.New()

	t.Run("success", func(t *testing.T) {
		userRepo := new(mocks.MockUserRepo)
		jwtSvc := new(mocks.MockJWTService)
		passSvc := new(mocks.MockPasswordService)
		svc := NewUserService(userRepo, nil, jwtSvc, passSvc, nil)

		user := &models.User{ID: userID, IsGuest: true}
		userRepo.On("GetByID", ctx, userID).Return(user, nil)
		passSvc.On("Hash", "password123!").Return("hash", nil)
		userRepo.On("Update", ctx, user).Return(nil)
		jwtSvc.On("RevokeUserSessions", userID).Return(nil)

		u, err := svc.ClaimAccount(ctx, userID, ClaimAccountInput{Password: "password123!", FirstName: "Test", LastName: "User"})
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

		_, err := svc.ClaimAccount(ctx, userID, ClaimAccountInput{Password: "password123!"})
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
