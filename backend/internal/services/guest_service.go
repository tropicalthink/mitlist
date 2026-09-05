package services

import (
	"context"
	cryptorand "crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/validation"
)

var ErrGuestCreationLimit = errors.New("guest creation limit reached")

var (
	guestAdjectives = []string{
		"Happy", "Clever", "Brave", "Mighty", "Swift", "Bright", "Calm", "Jolly",
	}
	guestNouns = []string{
		"Guest", "Visitor", "Traveler", "Wanderer", "Friend", "Penguin", "Otter", "Fox",
	}
)

// GuestService manages guest user lifecycle.
type GuestService struct {
	userRepo        repositories.UserRepo
	jwtService      JWTService
	passwordService PasswordService
	authRepo        repositories.AuthRepo
	mailService     MailService
	frontendURL     string
}

// SetFrontendURL configures the web fallback link included in verification
// emails. The code remains usable when the app link cannot be opened.
func (s *GuestService) SetFrontendURL(frontendURL string) {
	s.frontendURL = strings.TrimRight(frontendURL, "/")
}

// NewGuestService creates a new GuestService.
func NewGuestService(
	userRepo repositories.UserRepo,
	jwtService JWTService,
	passwordService PasswordService,
) *GuestService {
	return &GuestService{
		userRepo:        userRepo,
		jwtService:      jwtService,
		passwordService: passwordService,
	}
}

// NewGuestServiceWithAuth wires the verification dependencies required when a
// guest supplies an email address. Keeping the plain constructor is useful for
// isolated callers that only create guests; conversion in production must use
// this constructor so an arbitrary address is never treated as verified.
func NewGuestServiceWithAuth(
	userRepo repositories.UserRepo,
	jwtService JWTService,
	passwordService PasswordService,
	authRepo repositories.AuthRepo,
	mailService MailService,
) *GuestService {
	svc := NewGuestService(userRepo, jwtService, passwordService)
	svc.authRepo = authRepo
	svc.mailService = mailService
	return svc
}

// CreateGuest generates a random guest name and creates a guest user.
func (s *GuestService) CreateGuest(ctx context.Context) (*models.User, string, string, error) {
	return s.createGuest(ctx)
}

// CreateGuestForIdentity applies database-backed quotas before allocating a
// permanent user row. The installation ID is the primary signal; the wider IP
// budget limits clients that deliberately omit or rotate it.
func (s *GuestService) CreateGuestForIdentity(ctx context.Context, ip, installID string) (*models.User, string, string, error) {
	if s.authRepo != nil {
		if installID != "" {
			allowed, err := s.authRepo.ReserveLoginAttempt(ctx, guestQuotaKey("install", installID), 3, 30*24*time.Hour)
			if err != nil {
				return nil, "", "", err
			}
			if !allowed {
				return nil, "", "", ErrGuestCreationLimit
			}
		}
		allowed, err := s.authRepo.ReserveLoginAttempt(ctx, guestQuotaKey("ip", ip), 30, 24*time.Hour)
		if err != nil {
			return nil, "", "", err
		}
		if !allowed {
			return nil, "", "", ErrGuestCreationLimit
		}
	}
	return s.createGuest(ctx)
}

func (s *GuestService) createGuest(ctx context.Context) (*models.User, string, string, error) {
	name := generateGuestName()
	user := &models.User{
		ID:         uuid.New(),
		Email:      fmt.Sprintf("guest_%s@mitlist.local", uuid.NewString()),
		FirstName:  name,
		LastName:   "Guest",
		IsActive:   true,
		IsVerified: true,
		IsGuest:    true,
	}
	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, "", "", fmt.Errorf("create guest: %w", err)
	}

	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), []string{"guest"})
	if err != nil {
		return nil, "", "", fmt.Errorf("generate tokens: %w", err)
	}

	return user, access, refresh, nil
}

func guestQuotaKey(kind, value string) string {
	digest := sha256.Sum256([]byte(strings.TrimSpace(value)))
	return "guest:" + kind + ":" + hex.EncodeToString(digest[:])
}

// GetGuest retrieves a guest user by ID.
func (s *GuestService) GetGuest(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	user, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, &api.NotFoundError{Resource: "guest user", ID: userID.String()}
	}
	if !user.IsGuest {
		return nil, &api.ValidationError{Field: "user", Message: "user is not a guest"}
	}
	if !user.IsActive {
		return nil, &api.ValidationError{Message: "guest account is locked; refresh the app session to reactivate it"}
	}
	return user, nil
}

// ConvertGuest converts a guest user to a normal user.
// For data integrity and FK safety, the existing user record is updated in-place
// rather than deleted and recreated.
func (s *GuestService) ConvertGuest(ctx context.Context, guestID uuid.UUID, email, password, firstName, lastName string) (*models.User, string, string, error) {
	email = validation.NormalizeEmail(email)
	if err := validation.Email(email); err != nil {
		return nil, "", "", &api.ValidationError{Field: "email", Message: err.Error()}
	}
	if err := validation.Password(password); err != nil {
		return nil, "", "", &api.ValidationError{Field: "password", Message: err.Error()}
	}
	if err := validation.Name(firstName, "first_name"); err != nil {
		return nil, "", "", &api.ValidationError{Field: "first_name", Message: err.Error()}
	}
	if err := validation.Name(lastName, "last_name"); err != nil {
		return nil, "", "", &api.ValidationError{Field: "last_name", Message: err.Error()}
	}
	user, err := s.userRepo.GetByID(ctx, guestID)
	if err != nil {
		return nil, "", "", &api.NotFoundError{Resource: "guest user", ID: guestID.String()}
	}
	if !user.IsGuest {
		return nil, "", "", &api.ValidationError{Field: "user", Message: "user is not a guest"}
	}
	if !user.IsActive {
		return nil, "", "", &api.ValidationError{Message: "guest account is locked; refresh the app session to reactivate it"}
	}
	if s.authRepo == nil || s.mailService == nil {
		return nil, "", "", fmt.Errorf("guest conversion verification is not configured")
	}
	if existing, lookupErr := s.userRepo.GetByEmail(ctx, email); lookupErr == nil && existing.ID != guestID {
		return nil, "", "", &api.ConflictError{Message: "email is not available"}
	}

	hash, err := s.passwordService.Hash(password)
	if err != nil {
		return nil, "", "", fmt.Errorf("hash password: %w", err)
	}

	user.Email = email
	user.PasswordHash = hash
	user.FirstName = firstName
	user.LastName = lastName
	// Keep the guest session alive while the user enters the emailed code. The
	// verification transaction flips is_guest off atomically with is_verified.
	user.IsGuest = true
	user.IsVerified = false

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, "", "", fmt.Errorf("convert guest: %w", err)
	}
	rawToken, tokenHash, expiresAt, err := newEmailVerificationToken()
	if err != nil {
		return nil, "", "", err
	}
	if err := s.authRepo.CreateEmailVerification(ctx, user.ID, tokenHash, expiresAt); err != nil {
		return nil, "", "", fmt.Errorf("create guest verification: %w", err)
	}
	if err := sendVerificationEmail(s.mailService, user.Email, rawToken, s.frontendURL); err != nil {
		return nil, "", "", fmt.Errorf("send guest verification email: %w", err)
	}
	if err := s.jwtService.RevokeUserSessions(user.ID); err != nil {
		return nil, "", "", fmt.Errorf("revoke guest sessions: %w", err)
	}

	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), []string{"guest"})
	if err != nil {
		return nil, "", "", fmt.Errorf("generate tokens: %w", err)
	}

	return user, access, refresh, nil
}

func generateGuestName() string {
	adj := guestAdjectives[secureIndex(len(guestAdjectives))]
	noun := guestNouns[secureIndex(len(guestNouns))]
	return fmt.Sprintf("%s %s", adj, noun)
}

func secureIndex(length int) int {
	if length <= 1 {
		return 0
	}
	n, err := cryptorand.Int(cryptorand.Reader, big.NewInt(int64(length)))
	if err != nil {
		// Failure to obtain entropy should not make guest creation panic. The
		// value is cosmetic; the account ID remains generated by uuid.New.
		return 0
	}
	return int(n.Int64())
}
