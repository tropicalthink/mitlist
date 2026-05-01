package services

import (
	"context"
	"fmt"
	"math/rand"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
)

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

// CreateGuest generates a random guest name and creates a guest user.
func (s *GuestService) CreateGuest(ctx context.Context) (*models.User, string, string, error) {
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

	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		return nil, "", "", fmt.Errorf("generate tokens: %w", err)
	}

	return user, access, refresh, nil
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
	return user, nil
}

// ConvertGuest converts a guest user to a normal user.
// For data integrity and FK safety, the existing user record is updated in-place
// rather than deleted and recreated.
func (s *GuestService) ConvertGuest(ctx context.Context, guestID uuid.UUID, email, password, firstName, lastName string) (*models.User, string, string, error) {
	user, err := s.userRepo.GetByID(ctx, guestID)
	if err != nil {
		return nil, "", "", &api.NotFoundError{Resource: "guest user", ID: guestID.String()}
	}
	if !user.IsGuest {
		return nil, "", "", &api.ValidationError{Field: "user", Message: "user is not a guest"}
	}

	hash, err := s.passwordService.Hash(password)
	if err != nil {
		return nil, "", "", fmt.Errorf("hash password: %w", err)
	}

	user.Email = email
	user.PasswordHash = hash
	user.FirstName = firstName
	user.LastName = lastName
	user.IsGuest = false

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, "", "", fmt.Errorf("convert guest: %w", err)
	}

	access, refresh, err := s.jwtService.GenerateTokenPair(user.ID.String(), nil)
	if err != nil {
		return nil, "", "", fmt.Errorf("generate tokens: %w", err)
	}

	return user, access, refresh, nil
}

func generateGuestName() string {
	adj := guestAdjectives[rand.Intn(len(guestAdjectives))]
	noun := guestNouns[rand.Intn(len(guestNouns))]
	return fmt.Sprintf("%s %s", adj, noun)
}
