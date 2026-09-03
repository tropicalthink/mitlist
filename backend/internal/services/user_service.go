package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net/url"
	"strings"
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
	userRepo    repositories.UserRepo
	authRepo    repositories.AuthRepo
	jwt         JWTService
	password    PasswordService
	mail        MailService
	frontendURL string
}

// SetFrontendURL adds a clickable signup/recovery link to email messages while
// retaining the short code for clients that cannot open app links.
func (s *UserService) SetFrontendURL(frontendURL string) {
	s.frontendURL = strings.TrimRight(frontendURL, "/")
}

func verificationMessage(raw, frontendURL string) string {
	message := "Your email verification code is: " + raw
	if frontendURL != "" {
		message += "\n\nOpen " + frontendURL + "/signup?verification_token=" + url.QueryEscape(raw)
	}
	return message
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
	if err := s.mail.Send(user.Email, "Verify your mitlist account", verificationMessage(rawToken, s.frontendURL), false); err != nil {
		// Deliberately not fatal. The account is already persisted above, so
		// failing here told the caller registration failed while leaving a real
		// pending account behind — and the retry then looked like a duplicate.
		// Registration answers 202 either way; the caller recovers through
		// verify-email/resend, which the register handler already routes a
		// repeat attempt into.
		log.Error().Err(err).Str("user_id", user.ID.String()).Msg("registration verification delivery failed")
	}

	return user, nil
}

func newEmailVerificationToken() (raw, hash string, expiresAt time.Time, err error) {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	const tokenLength = 8
	rawBytes := make([]byte, tokenLength)
	for i := range rawBytes {
		var n [1]byte
		if _, err = rand.Read(n[:]); err != nil {
			return "", "", time.Time{}, err
		}
		rawBytes[i] = alphabet[int(n[0])%len(alphabet)]
	}
	raw = string(rawBytes)
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

// Every code-sending endpoint is public and answers the same way for every
// address, which makes it a free way to flood someone's inbox and burn the
// mail quota. Three sends per address per window is plenty for a person and
// nothing for an abuser; a throttled request is dropped silently, because a
// 429 would confirm the address exists.
const (
	emailCodeSendLimit  = 3
	emailCodeSendWindow = 15 * time.Minute
)

// allowEmailCodeSend reserves one send for the address under the given
// purpose. It reports true when the send may go ahead.
func (s *UserService) allowEmailCodeSend(ctx context.Context, purpose, email string) (bool, error) {
	if s.authRepo == nil {
		return true, nil
	}
	allowed, err := s.authRepo.ReserveLoginAttempt(ctx, purpose+":"+email, emailCodeSendLimit, emailCodeSendWindow)
	if err != nil {
		return false, err
	}
	if !allowed {
		log.Info().Str("purpose", purpose).Msg("email code send throttled")
	}
	return allowed, nil
}

// ResendEmailVerification intentionally returns no account-existence signal.
func (s *UserService) ResendEmailVerification(ctx context.Context, email string) error {
	email = validation.NormalizeEmail(email)
	if allowed, err := s.allowEmailCodeSend(ctx, "verify-resend", email); err != nil || !allowed {
		return err
	}
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
	if err = s.mail.Send(user.Email, "Verify your mitlist account", verificationMessage(raw, s.frontendURL), false); err != nil {
		// Same reasoning as Register, plus an enumeration one: this call only
		// reaches a send for an address that exists and is unverified, so
		// surfacing the failure would answer 500 for real addresses and nil for
		// unknown ones — the account-existence signal this function promises
		// not to give.
		log.Error().Err(err).Str("user_id", user.ID.String()).Msg("verification resend delivery failed")
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
		// Right password, unproven address. Distinct from a bad credential so
		// the client can open the verification step instead of a dead end.
		return nil, "", "", &api.EmailUnverifiedError{}
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
	if user.IsGuest {
		// Activity is deliberately refreshed only after the account has passed
		// the active checks above. A stale token cannot revive a locked guest.
		if err := s.userRepo.TouchGuestActivity(ctx, userID); err != nil {
			return nil, err
		}
	}
	// A guest that has supplied an email but has not completed verification may
	// continue the guest session long enough to enter the emailed code. It does
	// not receive a normal account session until verification consumes the code.
	if !user.IsVerified && !user.IsGuest {
		return nil, &api.ValidationError{Message: "account is not verified"}
	}

	return user, nil
}

// ReactivateGuestForRefresh unlocks an inactive guest after the JWT layer has
// confirmed possession of a live, unrevoked refresh session. The refresh
// endpoint calls this before rotating that session, so a locked guest can
// return without an email-based account-recovery flow while an expired guest
// remains permanently unavailable after cleanup.
func (s *UserService) ReactivateGuestForRefresh(ctx context.Context, userID uuid.UUID) error {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if !user.IsGuest {
		if !user.IsActive {
			return &api.ValidationError{Message: "account is inactive"}
		}
		return nil
	}
	if user.IsActive {
		return nil
	}
	return s.userRepo.ReactivateGuest(ctx, userID)
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
	if s.jwt != nil {
		if err := s.jwt.RevokeUserSessions(userID); err != nil {
			return err
		}
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
	if allowed, err := s.allowEmailCodeSend(ctx, "password-reset", email); err != nil || !allowed {
		return err
	}
	user, err := s.userRepo.GetByEmail(ctx, email)
	if err != nil {
		return nil
	}
	if !user.IsActive || !user.IsVerified {
		return nil
	}

	tokenStr, tokenHash, expiresAt, err := newEmailVerificationToken()
	if err != nil {
		return err
	}

	resetToken := &models.PasswordResetToken{
		UserID:    user.ID,
		Token:     tokenHash,
		ExpiresAt: expiresAt,
	}

	if err := s.authRepo.CreatePasswordResetToken(ctx, resetToken); err != nil {
		return err
	}

	resetMessage := "Your password reset code is: " + tokenStr
	if s.frontendURL != "" {
		resetMessage += "\n\nOpen " + s.frontendURL + "/reset-password?token=" + url.QueryEscape(tokenStr)
	}
	if err := s.mail.Send(user.Email, "Password Reset", resetMessage, false); err != nil {
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
	digest := sha256.Sum256([]byte(strings.ToUpper(strings.TrimSpace(token))))
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
	if user.IsGuest {
		return nil, &api.ValidationError{Message: "guest accounts must be converted and email-verified before claiming"}
	}
	if !user.IsVerified {
		return nil, &api.ValidationError{Message: "email verification is required before claiming this account"}
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
	// Claiming never proves ownership of an email address. Verification must
	// have happened through the one-time email credential before this method is
	// allowed to set a password.
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
	// Browser-provided key material is short base64url data. Bound each field
	// before it reaches storage so a malicious registration cannot consume
	// oversized rows or memory in downstream push code.
	const maxPushKeyLength = 512
	if len(sub.P256dh) > maxPushKeyLength {
		return &api.ValidationError{Field: "p256dh", Message: "p256dh exceeds maximum length of 512 bytes"}
	}
	if len(sub.Auth) > maxPushKeyLength {
		return &api.ValidationError{Field: "auth", Message: "auth exceeds maximum length of 512 bytes"}
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
	if userID == uuid.Nil {
		return nil, &api.ValidationError{Field: "user_id", Message: "user_id is required"}
	}
	if platform != "android" && platform != "ios" {
		return nil, &api.ValidationError{Field: "platform", Message: "platform must be android or ios"}
	}
	if token == "" {
		return nil, &api.ValidationError{Field: "token", Message: "token is required"}
	}
	const maxDeviceTokenLength = 4096
	if len(token) > maxDeviceTokenLength {
		return nil, &api.ValidationError{Field: "token", Message: "token exceeds maximum length of 4096 bytes"}
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
