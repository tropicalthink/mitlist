package mocks

import (
	"context"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/stretchr/testify/mock"
)

// MockGroupRepo is a mock implementation of repositories.GroupRepo.
type MockGroupRepo struct {
	mock.Mock
}

func (m *MockGroupRepo) WithTx(ctx context.Context, fn func(txRepo repositories.GroupRepo) error) error {
	args := m.Called(ctx, mock.Anything)
	if args.Error(0) != nil {
		return args.Error(0)
	}
	return fn(m)
}

func (m *MockGroupRepo) LockGroup(ctx context.Context, groupID uuid.UUID) error {
	args := m.Called(ctx, groupID)
	return args.Error(0)
}

func (m *MockGroupRepo) CreateGroup(ctx context.Context, group *models.Group) error {
	args := m.Called(ctx, group)
	return args.Error(0)
}

func (m *MockGroupRepo) GetGroupByID(ctx context.Context, id uuid.UUID) (*models.Group, error) {
	args := m.Called(ctx, id)
	if g := args.Get(0); g != nil {
		return g.(*models.Group), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) ListGroupsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Group, error) {
	args := m.Called(ctx, userID, limit, offset)
	if g := args.Get(0); g != nil {
		return g.([]models.Group), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) UpdateGroup(ctx context.Context, group *models.Group) error {
	args := m.Called(ctx, group)
	return args.Error(0)
}

func (m *MockGroupRepo) DeleteGroup(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockGroupRepo) CreateMembership(ctx context.Context, membership *models.GroupMembership) error {
	args := m.Called(ctx, membership)
	return args.Error(0)
}

func (m *MockGroupRepo) GetMembership(ctx context.Context, groupID, userID uuid.UUID) (*models.GroupMembership, error) {
	args := m.Called(ctx, groupID, userID)
	if mm := args.Get(0); mm != nil {
		return mm.(*models.GroupMembership), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) UpdateMembership(ctx context.Context, membership *models.GroupMembership) error {
	args := m.Called(ctx, membership)
	return args.Error(0)
}

func (m *MockGroupRepo) DeleteMembership(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockGroupRepo) CreateInvite(ctx context.Context, invite *models.GroupInvite) error {
	args := m.Called(ctx, invite)
	return args.Error(0)
}

func (m *MockGroupRepo) GetInviteByCode(ctx context.Context, code string) (*models.GroupInvite, error) {
	args := m.Called(ctx, code)
	if i := args.Get(0); i != nil {
		return i.(*models.GroupInvite), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) ConsumeInvite(ctx context.Context, inviteID, userID uuid.UUID) error {
	args := m.Called(ctx, inviteID, userID)
	return args.Error(0)
}

func (m *MockGroupRepo) CreatePendingClaim(ctx context.Context, claim *models.PendingClaim) error {
	args := m.Called(ctx, claim)
	return args.Error(0)
}

func (m *MockGroupRepo) GetPendingClaimByCode(ctx context.Context, code string) (*models.PendingClaim, error) {
	args := m.Called(ctx, code)
	if c := args.Get(0); c != nil {
		return c.(*models.PendingClaim), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) GetPendingClaimByID(ctx context.Context, id uuid.UUID) (*models.PendingClaim, error) {
	args := m.Called(ctx, id)
	if c := args.Get(0); c != nil {
		return c.(*models.PendingClaim), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) DeletePendingClaim(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *MockGroupRepo) ListMembershipsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMembership, error) {
	args := m.Called(ctx, groupID)
	if mm := args.Get(0); mm != nil {
		return mm.([]models.GroupMembership), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) ListMemberProfilesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMemberProfile, error) {
	args := m.Called(ctx, groupID)
	if profiles := args.Get(0); profiles != nil {
		return profiles.([]models.GroupMemberProfile), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) ListPendingClaimsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.PendingClaim, error) {
	args := m.Called(ctx, groupID)
	if c := args.Get(0); c != nil {
		return c.([]models.PendingClaim), args.Error(1)
	}
	return nil, args.Error(1)
}

func (m *MockGroupRepo) ListMemberEmailsByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]string, error) {
	args := m.Called(ctx, groupID)
	if em := args.Get(0); em != nil {
		return em.(map[uuid.UUID]string), args.Error(1)
	}
	return nil, args.Error(1)
}
