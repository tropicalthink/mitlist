package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	pushvalidate "github.com/mitlist-app/mitlist/internal/services/push"
	"github.com/mitlist-app/mitlist/pkg/validation"
)

// UserService provides business logic for user authentication and management.
type UserService struct {
	userRepo repositories.UserRepo
	authRepo repositories.AuthRepo
	jwt      JWTService
	password PasswordService
	mail     MailService
}

// A fixed bcrypt hash ensures unknown-email logins perform the same expensive
// password comparison as known accounts, reducing account-enumeration timing.
const dummyPasswordHash = "$2b$12$gJZj6I3Qm7va1CXdAY2VHe5QWxOlueQEP0li/hhhjIy.HF9LJhLF."

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

// Register creates an inactive-login account and sends a one-time email
// verification credential. Sessions are issued only after verification.
func (s *UserService) Register(ctx context.Context, input RegisterInput) (*models.User, error) {
	input.Email = validation.NormalizeEmail(input.Email)
	if err := validation.Email(input.Email); err != nil {
		return nil, &api.ValidationError{Field: "email", Message: err.Error()}
	}
	if err := validation.Password(input.Password); err != nil {
		return nil, &api.ValidationError{Field: "password", Message: err.Error()}
	}
	if input.FirstName != "" {
		if err := validation.Name(input.FirstName, "first_name"); err != nil {
			return nil, &api.ValidationError{Field: "first_name", Message: err.Error()}
		}
	}
	if input.LastName != "" {
		if err := validation.Name(input.LastName, "last_name"); err != nil {
			return nil, &api.ValidationError{Field: "last_name", Message: err.Error()}
		}
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
		IsVerified:   false,
		IsGuest:      false,
	}

	rawToken, tokenHash, expiresAt, err := newEmailVerificationToken()
	if err != nil {
		return nil, err
	}
	if err := s.authRepo.CreateUnverifiedUser(ctx, user, tokenHash, expiresAt); err != nil {
		return nil, err
	}
	if err := s.mail.Send(user.Email, "Verify your mitlist account", fmt.Sprintf("Your email verification code is: %s", rawToken), false); err != nil {
		log.Error().Err(err).Str("user_id", user.ID.String()).Msg("registration verification delivery failed")
	}

	return user, nil
}

func newEmailVerificationToken() (raw, hash string, expiresAt time.Time, err error) {
	tokenBytes := make([]byte, 32)
	if _, err = rand.Read(tokenBytes); err != nil {
		return "", "", time.Time{}, err
	}
	raw = hex.EncodeToString(tokenBytes)
	return raw, resetTokenHash(raw), time.Now().UTC().Add(30 * time.Minute), nil
}

// VerifyEmail atomically consumes a verification credential and returns the
// newly verified account.
func (s *UserService) VerifyEmail(ctx context.Context, token string) (*models.User, error) {
	if token == "" {
		return nil, &api.ValidationError{Field: "token", Message: "verification code is required"}
	}
	userID, err := s.authRepo.ConsumeEmailVerification(ctx, resetTokenHash(token))
	if err != nil {
		return nil, &api.ValidationError{Message: "invalid or expired verification code"}
	}
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return user, nil
}

// ResendEmailVerification intentionally returns no account-existence signal.
func (s *UserService) ResendEmailVerification(ctx context.Context, email string) error {
	email = validation.NormalizeEmail(email)
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil || user.IsVerified || !user.IsActive {
		return nil
	}
	raw, hash, expiresAt, err := newEmailVerificationToken()
	if err != nil {
		return err
	}
	if err = s.authRepo.CreateEmailVerification(ctx, user.ID, hash, expiresAt); err != nil {
		return err
	}
	if err = s.mail.Send(user.Email, "Verify your mitlist account", fmt.Sprintf("Your email verification code is: %s", raw), false); err != nil {
		return fmt.Errorf("send verification email: %w", err)
	}
	return nil
}

// Login validates credentials and returns the user with an access/refresh token pair.
func (s *UserService) Login(ctx context.Context, email, password string) (*models.User, string, string, error) {
	email = validation.NormalizeEmail(email)
	if s.authRepo != nil {
		allowed, err := s.authRepo.ReserveLoginAttempt(ctx, email, 5, 5*time.Minute)
		if err != nil {
			return nil, "", "", err
		}
		if !allowed {
			return nil, "", "", &api.ValidationError{Message: "too many attempts, please wait and try again"}
		}
	}
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		if isNotFound(err) {
			s.password.Compare(dummyPasswordHash, password)
			return nil, "", "", &api.ValidationError{Message: "invalid email or password"}
		}
		return nil, "", "", err
	}

	if !s.password.Compare(user.PasswordHash, password) {
		return nil, "", "", &api.ValidationError{Message: "invalid email or password"}
	}
	if !user.IsActive {
		return nil, "", "", &api.ValidationError{Message: "account is inactive"}
	}
	if !user.IsVerified {
		return nil, "", "", &api.ValidationError{Message: "account is not verified"}
	}

	if s.authRepo != nil {
		if err := s.authRepo.ClearLoginAttempts(ctx, email); err != nil {
			return nil, "", "", err
		}
	}
	access, refresh, err := s.jwt.GenerateTokenPair(user.ID.String(), []string{})
	if err != nil {
		return nil, "", "", err
	}

	return user, access, refresh, nil
}

// GetMe returns the authenticated user's profile from PostgreSQL.
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
		if err := validation.Name(*input.FirstName, "first_name"); err != nil {
			return nil, &api.ValidationError{Field: "first_name", Message: err.Error()}
		}
		user.FirstName = *input.FirstName
	}
	if input.LastName != nil {
		if err := validation.Name(*input.LastName, "last_name"); err != nil {
			return nil, &api.ValidationError{Field: "last_name", Message: err.Error()}
		}
		user.LastName = *input.LastName
	}
	if input.AvatarURL != nil {
		if err := validation.MaxLength(*input.AvatarURL, 500, "avatar_url"); err != nil {
			return nil, &api.ValidationError{Field: "avatar_url", Message: err.Error()}
		}
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
	if err := s.userRepo.SoftDelete(ctx, userID); err != nil {
		return err
	}
	return nil
}

// ChangePassword updates the user's password after verifying the current one.
func (s *UserService) ChangePassword(ctx context.Context, userID uuid.UUID, oldPassword, newPassword string) error {
	if err := validation.Password(newPassword); err != nil {
		return &api.ValidationError{Field: "new_password", Message: err.Error()}
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
	if err := s.authRepo.UpdatePasswordAndRevokeSessions(ctx, userID, hash); err != nil {
		return err
	}
	return nil
}

// RequestPasswordReset generates a reset token and sends it via email.
// To prevent email enumeration, it always returns nil when the email is not found.
func (s *UserService) RequestPasswordReset(ctx context.Context, email string) error {
	email = validation.NormalizeEmail(email)
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
		Token:     resetTokenHash(tokenStr),
		ExpiresAt: time.Now().UTC().Add(24 * time.Hour),
	}

	if err := s.authRepo.CreatePasswordResetToken(ctx, resetToken); err != nil {
		return err
	}

	if err := s.mail.Send(user.Email, "Password Reset", fmt.Sprintf("Your password reset code is: %s", tokenStr), false); err != nil {
		return fmt.Errorf("send password reset email: %w", err)
	}
	return nil
}

// ConfirmPasswordReset validates a reset token and updates the user's password.
func (s *UserService) ConfirmPasswordReset(ctx context.Context, token, newPassword string) error {
	if err := validation.Password(newPassword); err != nil {
		return &api.ValidationError{Field: "new_password", Message: err.Error()}
	}

	hash, err := s.password.Hash(newPassword)
	if err != nil {
		return err
	}
	if _, err := s.authRepo.ConsumePasswordReset(ctx, resetTokenHash(token), hash); err != nil {
		return &api.ValidationError{Message: "invalid or expired token"}
	}
	return nil
}

func resetTokenHash(token string) string {
	digest := sha256.Sum256([]byte(token))
	return hex.EncodeToString(digest[:])
}

// ClaimAccountInput holds fields for claiming a pre-created or guest account.
type ClaimAccountInput struct {
	Password  string
	FirstName string
	LastName  string
}

// ClaimAccount allows a user to set a password and claim their account.
func (s *UserService) ClaimAccount(ctx context.Context, userID uuid.UUID, input ClaimAccountInput) (*models.User, error) {
	if err := validation.Password(input.Password); err != nil {
		return nil, &api.ValidationError{Field: "password", Message: err.Error()}
	}
	if input.FirstName != "" {
		if err := validation.Name(input.FirstName, "first_name"); err != nil {
			return nil, &api.ValidationError{Field: "first_name", Message: err.Error()}
		}
	}
	if input.LastName != "" {
		if err := validation.Name(input.LastName, "last_name"); err != nil {
			return nil, &api.ValidationError{Field: "last_name", Message: err.Error()}
		}
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
	if err := s.jwt.RevokeUserSessions(user.ID); err != nil {
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
	if err := pushvalidate.ValidatePushEndpoint(sub.Endpoint); err != nil {
		return err
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

// ---------------------------------------------------------------------------
// Device tokens (FCM — mobile push)
// ---------------------------------------------------------------------------

// SaveDeviceToken upserts an FCM device token for the current user.
func (s *UserService) SaveDeviceToken(ctx context.Context, userID uuid.UUID, platform, token string) (*models.DeviceToken, error) {
	if platform != "android" && platform != "ios" {
		return nil, &api.ValidationError{Field: "platform", Message: "platform must be android or ios"}
	}
	if token == "" {
		return nil, &api.ValidationError{Field: "token", Message: "token is required"}
	}
	return s.authRepo.SaveDeviceToken(ctx, userID, platform, token)
}

// ListDeviceTokens returns all device tokens for a user.
func (s *UserService) ListDeviceTokens(ctx context.Context, userID uuid.UUID) ([]models.DeviceToken, error) {
	return s.authRepo.ListDeviceTokensByUser(ctx, userID)
}

// DeleteDeviceToken removes a device token by ID, scoped to the owning user.
func (s *UserService) DeleteDeviceToken(ctx context.Context, userID, tokenID uuid.UUID) error {
	return s.authRepo.DeleteDeviceToken(ctx, userID, tokenID)
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
