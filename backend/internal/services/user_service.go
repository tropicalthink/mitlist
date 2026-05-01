package services

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// UserService provides business logic for user authentication and management.
type UserService struct {
	userRepo repositories.UserRepo
	authRepo repositories.AuthRepo
	jwt      JWTService
	password PasswordService
	mail     MailService
}

// NewUserService creates a new UserService.
func NewUserService(
	userRepo repositories.UserRepo,
	authRepo repositories.AuthRepo,
	jwt JWTService,
	password PasswordService,
	mail MailService,
) *UserService {
	return &UserService{
		userRepo: userRepo,
		authRepo: authRepo,
		jwt:      jwt,
		password: password,
		mail:     mail,
	}
}

// RegisterInput holds fields required to create a new user account.
type RegisterInput struct {
	Email     string
	Password  string
	FirstName string
	LastName  string
}

// Register creates a new verified user account with a hashed password.
func (s *UserService) Register(ctx context.Context, input RegisterInput) (*models.User, error) {
	if input.Email == "" || input.Password == "" {
		return nil, &api.ValidationError{Message: "email and password are required"}
	}
	if len(input.Password) < 6 {
		return nil, &api.ValidationError{Message: "password must be at least 6 characters"}
	}

	existing, err := s.userRepo.GetByEmail(ctx, input.Email)
	if err != nil {
		if !isNotFound(err) {
			return nil, err
		}
	} else if existing != nil {
		return nil, &api.ConflictError{Message: "email already registered"}
	}

	hash, err := s.password.Hash(input.Password)
	if err != nil {
		return nil, err
	}

	user := &models.User{
		Email:        input.Email,
		PasswordHash: hash,
		FirstName:    input.FirstName,
		LastName:     input.LastName,
		IsActive:     true,
		IsVerified:   true,
		IsGuest:      false,
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

// Login validates credentials and returns the user with an access/refresh token pair.
func (s *UserService) Login(ctx context.Context, email, password string) (*models.User, string, string, error) {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if isNotFound(err) {
			return nil, "", "", &api.ValidationError{Message: "invalid email or password"}
		}
		return nil, "", "", err
	}

	if !user.IsActive {
		return nil, "", "", &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return nil, "", "", &api.ValidationError{Message: "account is not verified"}
	}

	if !s.password.Compare(user.PasswordHash, password) {
		return nil, "", "", &api.ValidationError{Message: "invalid email or password"}
	}

	access, refresh, err := s.jwt.GenerateTokenPair(user.ID.String(), []string{})
	if err != nil {
		return nil, "", "", err
	}

	return user, access, refresh, nil
}

// GetMe returns the authenticated user's profile.
func (s *UserService) GetMe(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		if isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "user"}
		}
		return nil, err
	}
	if !user.IsActive {
		return nil, &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return nil, &api.ValidationError{Message: "account is not verified"}
	}
	return user, nil
}

// UpdateMeInput holds optional fields for updating the current user.
type UpdateMeInput struct {
	FirstName *string
	LastName  *string
	AvatarURL *string
}

// UpdateMe updates the authenticated user's profile fields.
func (s *UserService) UpdateMe(ctx context.Context, userID uuid.UUID, input UpdateMeInput) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		if isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "user"}
		}
		return nil, err
	}
	if !user.IsActive {
		return nil, &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return nil, &api.ValidationError{Message: "account is not verified"}
	}

	if input.FirstName != nil {
		user.FirstName = *input.FirstName
	}
	if input.LastName != nil {
		user.LastName = *input.LastName
	}
	if input.AvatarURL != nil {
		user.AvatarURL = input.AvatarURL
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

// DeleteMe soft-deletes the authenticated user's account.
func (s *UserService) DeleteMe(ctx context.Context, userID uuid.UUID) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		if isNotFound(err) {
			return &api.NotFoundError{Resource: "user"}
		}
		return err
	}
	if !user.IsActive {
		return &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return &api.ValidationError{Message: "account is not verified"}
	}
	return s.userRepo.SoftDelete(ctx, userID)
}

// ChangePassword updates the user's password after verifying the current one.
func (s *UserService) ChangePassword(ctx context.Context, userID uuid.UUID, oldPassword, newPassword string) error {
	if len(newPassword) < 6 {
		return &api.ValidationError{Message: "password must be at least 6 characters"}
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		if isNotFound(err) {
			return &api.NotFoundError{Resource: "user"}
		}
		return err
	}
	if !user.IsActive {
		return &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return &api.ValidationError{Message: "account is not verified"}
	}

	if !s.password.Compare(user.PasswordHash, oldPassword) {
		return &api.ValidationError{Message: "incorrect current password"}
	}

	hash, err := s.password.Hash(newPassword)
	if err != nil {
		return err
	}
	user.PasswordHash = hash
	return s.userRepo.Update(ctx, user)
}

// RequestPasswordReset generates a reset token and sends it via email.
// To prevent email enumeration, it always returns nil when the email is not found.
func (s *UserService) RequestPasswordReset(ctx context.Context, email string) error {
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil
	}
	if !user.IsActive || !user.IsVerified {
		return nil
	}

	tokenBytes := make([]byte, 32)
	if _, err := rand.Read(tokenBytes); err != nil {
		return err
	}
	tokenStr := hex.EncodeToString(tokenBytes)

	resetToken := &models.PasswordResetToken{
		UserID:    user.ID,
		Token:     tokenStr,
		ExpiresAt: time.Now().UTC().Add(24 * time.Hour),
	}

	if err := s.authRepo.CreatePasswordResetToken(ctx, resetToken); err != nil {
		return err
	}

	s.mail.Send(user.Email, "Password Reset", fmt.Sprintf("Your password reset code is: %s", tokenStr), false)
	return nil
}

// ConfirmPasswordReset validates a reset token and updates the user's password.
func (s *UserService) ConfirmPasswordReset(ctx context.Context, token, newPassword string) error {
	if len(newPassword) < 6 {
		return &api.ValidationError{Message: "password must be at least 6 characters"}
	}

	resetToken, err := s.authRepo.GetPasswordResetToken(ctx, token)
	if err != nil {
		if isNotFound(err) {
			return &api.ValidationError{Message: "invalid or expired token"}
		}
		return err
	}

	if resetToken.UsedAt != nil {
		return &api.ValidationError{Message: "token already used"}
	}
	if time.Now().UTC().After(resetToken.ExpiresAt) {
		return &api.ValidationError{Message: "token expired"}
	}

	user, err := s.userRepo.GetByID(ctx, resetToken.UserID)
	if err != nil {
		if isNotFound(err) {
			return &api.NotFoundError{Resource: "user"}
		}
		return err
	}

	hash, err := s.password.Hash(newPassword)
	if err != nil {
		return err
	}
	user.PasswordHash = hash

	if err := s.userRepo.Update(ctx, user); err != nil {
		return err
	}

	return s.authRepo.ConsumeToken(ctx, resetToken.ID)
}

// ClaimAccountInput holds fields for claiming a pre-created or guest account.
type ClaimAccountInput struct {
	Password  string
	FirstName string
	LastName  string
}

// ClaimAccount allows a user to set a password and claim their account.
func (s *UserService) ClaimAccount(ctx context.Context, userID uuid.UUID, input ClaimAccountInput) (*models.User, error) {
	if len(input.Password) < 6 {
		return nil, &api.ValidationError{Message: "password must be at least 6 characters"}
	}

	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		if isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "user"}
		}
		return nil, err
	}
	if user.IsActive && user.IsVerified && user.PasswordHash != "" && !user.IsGuest {
		return nil, &api.ConflictError{Message: "account already claimed"}
	}

	hash, err := s.password.Hash(input.Password)
	if err != nil {
		return nil, err
	}

	user.PasswordHash = hash
	user.FirstName = input.FirstName
	user.LastName = input.LastName
	user.IsActive = true
	user.IsVerified = true
	user.IsGuest = false

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

// CreatePushSubscription registers a web-push subscription for the current user.
func (s *UserService) CreatePushSubscription(ctx context.Context, sub *models.PushSubscription) error {
	if sub == nil {
		return &api.ValidationError{Message: "subscription is required"}
	}
	if sub.UserID == uuid.Nil {
		return &api.ValidationError{Message: "user_id is required"}
	}
	if sub.Endpoint == "" || sub.P256dh == "" || sub.Auth == "" {
		return &api.ValidationError{Message: "endpoint, p256dh, and auth are required"}
	}
	if err := s.authRepo.CreatePushSubscription(ctx, sub); err != nil {
		return err
	}
	return nil
}

// ListPushSubscriptions lists all web-push subscriptions for the current user.
func (s *UserService) ListPushSubscriptions(ctx context.Context, userID uuid.UUID) ([]models.PushSubscription, error) {
	if userID == uuid.Nil {
		return nil, &api.ValidationError{Message: "user_id is required"}
	}
	return s.authRepo.ListPushSubscriptionsByUser(ctx, userID)
}

// DeletePushSubscription deletes a web-push subscription by ID.
func (s *UserService) DeletePushSubscription(ctx context.Context, userID, subID uuid.UUID) error {
	if userID == uuid.Nil || subID == uuid.Nil {
		return &api.ValidationError{Message: "user_id and subscription id are required"}
	}
	// We don't currently enforce ownership in the repo layer; do a best-effort check first.
	subs, err := s.authRepo.ListPushSubscriptionsByUser(ctx, userID)
	if err != nil {
		return err
	}
	owned := false
	for _, s := range subs {
		if s.ID == subID {
			owned = true
			break
		}
	}
	if !owned {
		return &api.NotFoundError{Resource: "push subscription", ID: subID.String()}
	}
	return s.authRepo.DeletePushSubscription(ctx, subID)
}

// isNotFound reports whether err indicates a missing resource from any repository.
func isNotFound(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return true
	}
	switch err.Error() {
	case "user not found",
		"oauth account not found",
		"token not found",
		"token not found or already used",
		"push subscription not found":
		return true
	}
	return false
}
