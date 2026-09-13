package services

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
	"github.com/mitlist-app/mitlist/pkg/validation"
)

// memberGate decides whether a household may grow past the free member limit.
// Implemented by BillingService; left nil on servers with billing switched off,
// where every household grows without limit.
type memberGate interface {
	EnsureCanAddMember(ctx context.Context, groupID uuid.UUID) error
}

// GroupService provides business logic for group and membership management.
type GroupService struct {
	groupRepo repositories.GroupRepo
	userRepo  repositories.UserRepo
	billing   memberGate
	hub       *sse.Hub
}

// SetHub injects the household event hub for group and membership changes.
func (s *GroupService) SetHub(h *sse.Hub) { s.hub = h }

// NewGroupService creates a new GroupService.
func NewGroupService(groupRepo repositories.GroupRepo, userRepo repositories.UserRepo) *GroupService {
	return &GroupService{
		groupRepo: groupRepo,
		userRepo:  userRepo,
	}
}

// SetMemberGate installs the premium gate applied before a household grows.
// Without it, household size is unlimited — which is what a self-hosted
// instance with no billing configured should do.
func (s *GroupService) SetMemberGate(gate memberGate) {
	s.billing = gate
}

// ensureCanAddMember applies the premium gate, if one is installed.
func (s *GroupService) ensureCanAddMember(ctx context.Context, groupID uuid.UUID) error {
	if s.billing == nil {
		return nil
	}
	return s.billing.EnsureCanAddMember(ctx, groupID)
}

// CreateGroupInput holds fields for creating a group.
type CreateGroupInput struct {
	Name        string
	Description *string
	Currency    string `json:"currency"`
}

// CreateGroup creates a new group and makes the creator an admin.
func (s *GroupService) CreateGroup(ctx context.Context, userID uuid.UUID, input CreateGroupInput) (*models.Group, error) {
	if err := validation.RequiredString(input.Name, "name"); err != nil {
		return nil, &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(input.Name, validation.MaxGroupNameLength, "name"); err != nil {
		return nil, &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if input.Description != nil && *input.Description != "" {
		if err := validation.MaxLength(*input.Description, validation.MaxDescriptionLength, "description"); err != nil {
			return nil, &api.ValidationError{Field: "description", Message: err.Error()}
		}
	}

	currency := input.Currency
	if currency == "" {
		currency = "USD"
	}
	group := &models.Group{
		Name:        input.Name,
		Description: input.Description,
		Currency:    currency,
		CreatedBy:   userID,
	}

	if err := s.groupRepo.CreateGroup(ctx, group); err != nil {
		return nil, err
	}

	membership := &models.GroupMembership{
		GroupID: group.ID,
		UserID:  userID,
		Role:    "admin",
	}
	if err := s.groupRepo.CreateMembership(ctx, membership); err != nil {
		return nil, err
	}
	publishDomainEvent(s.hub, "group:created", group.ID, map[string]string{"group_id": group.ID.String()})

	return group, nil
}

// GetGroup returns a group if the user is a member.
func (s *GroupService) GetGroup(ctx context.Context, userID, groupID uuid.UUID) (*models.Group, error) {
	if _, err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "group"}
		}
		return nil, err
	}
	return group, nil
}

// ListGroups returns all groups the user belongs to.
func (s *GroupService) ListGroups(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Group, error) {
	return s.groupRepo.ListGroupsByUser(ctx, userID, limit, offset)
}

// ListMemberProfiles returns display-ready members for a group.
// ListMemberProfiles returns the household roster. Former members are only
// included on request: clients that know about LeftAt ask for them so the
// names on old expenses and chores keep resolving, while older clients keep
// seeing a roster made of people who are actually in the household.
func (s *GroupService) ListMemberProfiles(ctx context.Context, userID, groupID uuid.UUID, includeFormer bool) ([]models.GroupMemberProfile, error) {
	if _, err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}
	profiles, err := s.groupRepo.ListMemberProfilesByGroup(ctx, groupID)
	if err != nil || includeFormer {
		return profiles, err
	}
	active := profiles[:0]
	for _, p := range profiles {
		if p.LeftAt == nil {
			active = append(active, p)
		}
	}
	return active, nil
}

// UpdateGroupInput holds optional fields for updating a group.
type UpdateGroupInput struct {
	Name        *string
	Description *string
	Currency    *string   `json:"currency"`
	ChoreZones  *[]string `json:"chore_zones"`
}

// onlyChoreZones reports whether the update touches nothing but chore zones.
func (in UpdateGroupInput) onlyChoreZones() bool {
	return in.ChoreZones != nil && in.Name == nil && in.Description == nil && in.Currency == nil
}

// UpdateGroup updates a group's details. Name, description and currency are
// admin-only; chore zones are household upkeep that any member may edit, since
// the chore editor offers "add zone" to everyone.
func (s *GroupService) UpdateGroup(ctx context.Context, userID, groupID uuid.UUID, input UpdateGroupInput) (*models.Group, error) {
	if input.onlyChoreZones() {
		if _, err := s.requireMembership(ctx, userID, groupID); err != nil {
			return nil, err
		}
	} else if err := s.requireAdmin(ctx, userID, groupID); err != nil {
		return nil, err
	}

	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "group"}
		}
		return nil, err
	}

	if input.Name != nil {
		if err := validation.RequiredString(*input.Name, "name"); err != nil {
			return nil, &api.ValidationError{Field: "name", Message: err.Error()}
		}
		if err := validation.MaxLength(*input.Name, validation.MaxGroupNameLength, "name"); err != nil {
			return nil, &api.ValidationError{Field: "name", Message: err.Error()}
		}
		group.Name = *input.Name
	}
	if input.Description != nil {
		if *input.Description != "" {
			if err := validation.MaxLength(*input.Description, validation.MaxDescriptionLength, "description"); err != nil {
				return nil, &api.ValidationError{Field: "description", Message: err.Error()}
			}
		}
		group.Description = input.Description
	}
	if input.Currency != nil {
		group.Currency = *input.Currency
	}
	if input.ChoreZones != nil {
		group.ChoreZones = *input.ChoreZones
	}

	if err := s.groupRepo.UpdateGroup(ctx, group); err != nil {
		return nil, err
	}
	publishDomainEvent(s.hub, "group:updated", group.ID, map[string]string{"group_id": group.ID.String()})
	return group, nil
}

// DeleteGroup removes a group; only admins may do so.
func (s *GroupService) DeleteGroup(ctx context.Context, userID, groupID uuid.UUID) error {
	if err := s.requireAdmin(ctx, userID, groupID); err != nil {
		return err
	}
	if err := s.groupRepo.DeleteGroup(ctx, groupID); err != nil {
		return err
	}
	publishDomainEvent(s.hub, "group:deleted", groupID, map[string]string{"group_id": groupID.String()})
	return nil
}

// InviteMember creates an invite code for the group. Any member of the
// household may invite; the code admits anyone who presents it for a week,
// and accepting does not use it up.
//
// The premium gate is applied here, on the inviter's side, and not only at
// join time: the person inviting is a household member who can pay, whereas
// the person presenting a code is a stranger who cannot resolve a paywall.
// A full household therefore gets a PaymentRequiredError before any code is
// minted, and the app turns that into the premium flow.
func (s *GroupService) InviteMember(ctx context.Context, userID, groupID uuid.UUID, role string) (*models.GroupInvite, error) {
	if _, err := s.requireMembership(ctx, userID, groupID); err != nil {
		return nil, err
	}
	if role == "" {
		role = "member"
	}
	if role != "member" {
		return nil, &api.ValidationError{Message: "invites can only grant the member role"}
	}
	if err := s.ensureCanAddMember(ctx, groupID); err != nil {
		return nil, err
	}

	// Generate short, human-friendly codes. Retry on rare uniqueness collisions.
	for attempt := 0; attempt < 10; attempt++ {
		code, err := generatePlayfulInviteCode()
		if err != nil {
			return nil, err
		}

		invite := &models.GroupInvite{
			GroupID:   groupID,
			Code:      code,
			ExpiresAt: time.Now().UTC().Add(7 * 24 * time.Hour),
		}

		if err := s.groupRepo.CreateInvite(ctx, invite); err != nil {
			var pgErr *pgconn.PgError
			if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
				continue
			}
			return nil, err
		}
		return invite, nil
	}

	return nil, &api.ValidationError{Message: "could not generate invite code, please try again"}
}

// PreviewInvite resolves an invite code to the household it opens without
// joining, so the recipient can decide whether to accept. Unknown codes are
// a 404; expired and already-a-member codes still resolve so the page can
// explain why accepting will not work.
func (s *GroupService) PreviewInvite(ctx context.Context, userID uuid.UUID, code string) (*models.InvitePreview, error) {
	code = strings.ToUpper(strings.TrimSpace(code))

	invite, err := s.groupRepo.GetInviteByCode(ctx, code)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "invite"}
		}
		return nil, err
	}

	group, err := s.groupRepo.GetGroupByID(ctx, invite.GroupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.NotFoundError{Resource: "invite"}
		}
		return nil, err
	}

	members, err := s.groupRepo.ListMembershipsByGroup(ctx, invite.GroupID)
	if err != nil {
		return nil, err
	}

	status := models.InviteStatusValid
	if time.Now().UTC().After(invite.ExpiresAt) {
		status = models.InviteStatusExpired
	}
	for _, m := range members {
		if m.UserID == userID {
			status = models.InviteStatusAlreadyMember
			break
		}
	}

	return &models.InvitePreview{
		Code:        invite.Code,
		GroupID:     group.ID,
		GroupName:   group.Name,
		MemberCount: len(members),
		ExpiresAt:   invite.ExpiresAt,
		Status:      status,
	}, nil
}

// JoinGroup allows a user to join a group using an invite code. The code is
// reusable until it expires, so joining only checks the deadline and adds
// the membership.
func (s *GroupService) JoinGroup(ctx context.Context, userID uuid.UUID, code string) (*models.Group, error) {
	code = strings.ToUpper(strings.TrimSpace(code))

	invite, err := s.groupRepo.GetInviteByCode(ctx, code)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.ValidationError{Message: "invalid invite code"}
		}
		return nil, err
	}

	if time.Now().UTC().After(invite.ExpiresAt) {
		return nil, &api.ValidationError{Message: "invite expired"}
	}

	existing, _ := s.groupRepo.GetMembership(ctx, invite.GroupID, userID)
	if existing != nil {
		return nil, &api.ConflictError{Message: "already a member of this group"}
	}

	if err := s.ensureCanAddMember(ctx, invite.GroupID); err != nil {
		return nil, err
	}

	membership := &models.GroupMembership{
		GroupID: invite.GroupID,
		UserID:  userID,
		Role:    "member",
	}
	if err := s.groupRepo.CreateMembership(ctx, membership); err != nil {
		return nil, err
	}

	publishDomainEvent(s.hub, "member:joined", invite.GroupID, map[string]string{"user_id": userID.String()})
	return s.groupRepo.GetGroupByID(ctx, invite.GroupID)
}

// LeaveGroup removes the user's membership. The last admin cannot leave.
func (s *GroupService) LeaveGroup(ctx context.Context, userID, groupID uuid.UUID) error {
	err := s.groupRepo.WithTx(ctx, func(repo repositories.GroupRepo) error {
		if err := repo.LockGroup(ctx, groupID); err != nil {
			return err
		}
		membership, err := repo.GetMembership(ctx, groupID, userID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
				return &api.NotFoundError{Resource: "membership"}
			}
			return err
		}
		if membership.Role == "admin" {
			isLast, err := isLastAdmin(ctx, repo, groupID, userID)
			if err != nil {
				return err
			}
			if isLast {
				return &api.ValidationError{Message: "cannot leave group as the last admin"}
			}
		}
		return repo.EndMembership(ctx, membership.ID)
	})
	if err == nil {
		publishDomainEvent(s.hub, "member:left", groupID, map[string]string{"user_id": userID.String()})
	}
	return err
}

// UpdateMemberRole changes a member's role. Only admins may do so.
func (s *GroupService) UpdateMemberRole(ctx context.Context, userID, groupID, targetUserID uuid.UUID, role string) error {
	if role != "admin" && role != "member" {
		return &api.ValidationError{Message: "role must be admin or member"}
	}
	err := s.groupRepo.WithTx(ctx, func(repo repositories.GroupRepo) error {
		if err := repo.LockGroup(ctx, groupID); err != nil {
			return err
		}
		if err := requireAdmin(ctx, repo, userID, groupID); err != nil {
			return err
		}
		membership, err := repo.GetMembership(ctx, groupID, targetUserID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
				return &api.NotFoundError{Resource: "membership"}
			}
			return err
		}
		if membership.Role == "admin" && role == "member" {
			isLast, err := isLastAdmin(ctx, repo, groupID, targetUserID)
			if err != nil {
				return err
			}
			if isLast {
				return &api.ValidationError{Message: "cannot demote the last admin"}
			}
		}
		membership.Role = role
		return repo.UpdateMembership(ctx, membership)
	})
	if err == nil {
		publishDomainEvent(s.hub, "member:role_updated", groupID, map[string]string{"user_id": targetUserID.String()})
	}
	return err
}

// RemoveMember removes a member from the group. Any member of the household
// may remove another member; the last admin is still protected so the group
// never ends up without one. The membership is retired, not deleted, so the
// person's expenses, chores and posts keep their name and balances still add
// up; accepting a new invite reactivates it.
func (s *GroupService) RemoveMember(ctx context.Context, userID, groupID, targetUserID uuid.UUID) error {
	err := s.groupRepo.WithTx(ctx, func(repo repositories.GroupRepo) error {
		if err := repo.LockGroup(ctx, groupID); err != nil {
			return err
		}
		if _, err := requireMembership(ctx, repo, userID, groupID); err != nil {
			return err
		}
		membership, err := repo.GetMembership(ctx, groupID, targetUserID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
				return &api.NotFoundError{Resource: "membership"}
			}
			return err
		}
		if membership.Role == "admin" {
			isLast, err := isLastAdmin(ctx, repo, groupID, targetUserID)
			if err != nil {
				return err
			}
			if isLast {
				return &api.ValidationError{Message: "cannot remove the last admin"}
			}
		}
		return repo.EndMembership(ctx, membership.ID)
	})
	if err == nil {
		publishDomainEvent(s.hub, "member:removed", groupID, map[string]string{"user_id": targetUserID.String()})
	}
	return err
}

// GetPendingClaims returns all pending claims for a group. Admins only.
func (s *GroupService) GetPendingClaims(ctx context.Context, userID, groupID uuid.UUID) ([]models.PendingClaim, error) {
	if err := s.requireAdmin(ctx, userID, groupID); err != nil {
		return nil, err
	}
	return s.groupRepo.ListPendingClaimsByGroup(ctx, groupID)
}

// ApproveClaim approves a pending claim, creating a membership for the claimant.
func (s *GroupService) ApproveClaim(ctx context.Context, userID, groupID, claimID uuid.UUID) error {
	if err := s.requireAdmin(ctx, userID, groupID); err != nil {
		return err
	}

	claim, err := s.groupRepo.GetPendingClaimByID(ctx, claimID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return &api.NotFoundError{Resource: "pending claim"}
		}
		return err
	}
	if claim.GroupID != groupID {
		return &api.NotFoundError{Resource: "pending claim"}
	}

	if claim.ClaimedBy == nil {
		return &api.ValidationError{Message: "claim has not been claimed yet"}
	}

	existing, _ := s.groupRepo.GetMembership(ctx, groupID, *claim.ClaimedBy)
	if existing != nil {
		return s.groupRepo.DeletePendingClaim(ctx, claimID)
	}

	if err := s.ensureCanAddMember(ctx, groupID); err != nil {
		return err
	}

	membership := &models.GroupMembership{
		GroupID: groupID,
		UserID:  *claim.ClaimedBy,
		Role:    "member",
	}
	if err := s.groupRepo.CreateMembership(ctx, membership); err != nil {
		return err
	}
	publishDomainEvent(s.hub, "member:joined", groupID, map[string]string{"user_id": claim.ClaimedBy.String()})

	return s.groupRepo.DeletePendingClaim(ctx, claimID)
}

// RejectClaim deletes a pending claim.
func (s *GroupService) RejectClaim(ctx context.Context, userID, groupID, claimID uuid.UUID) error {
	if err := s.requireAdmin(ctx, userID, groupID); err != nil {
		return err
	}

	claim, err := s.groupRepo.GetPendingClaimByID(ctx, claimID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return &api.NotFoundError{Resource: "pending claim"}
		}
		return err
	}
	if claim.GroupID != groupID {
		return &api.NotFoundError{Resource: "pending claim"}
	}

	return s.groupRepo.DeletePendingClaim(ctx, claimID)
}

// requireMembership returns the membership or permission denied.
func (s *GroupService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) (*models.GroupMembership, error) {
	return requireMembership(ctx, s.groupRepo, userID, groupID)
}

func requireMembership(ctx context.Context, repo repositories.GroupRepo, userID, groupID uuid.UUID) (*models.GroupMembership, error) {
	m, err := repo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return nil, &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return nil, err
	}
	if !isGroupMember(m) {
		return nil, &api.PermissionDeniedError{Message: "not a member of this group"}
	}
	return m, nil
}

// requireAdmin returns permission denied if the user is not a group admin.
func (s *GroupService) requireAdmin(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireAdmin(ctx, s.groupRepo, userID, groupID)
}

func requireAdmin(ctx context.Context, repo repositories.GroupRepo, userID, groupID uuid.UUID) error {
	m, err := repo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) || isNotFound(err) {
			return &api.PermissionDeniedError{Message: "not a member of this group"}
		}
		return err
	}
	if !isGroupAdmin(m) {
		return &api.PermissionDeniedError{Message: "admin access required"}
	}
	return nil
}

// isLastAdmin reports whether userID is the only admin in the group.
func (s *GroupService) isLastAdmin(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	return isLastAdmin(ctx, s.groupRepo, groupID, userID)
}

func isLastAdmin(ctx context.Context, repo repositories.GroupRepo, groupID, userID uuid.UUID) (bool, error) {
	memberships, err := repo.ListMembershipsByGroup(ctx, groupID)
	if err != nil {
		return false, err
	}
	for _, m := range memberships {
		if m.Role == "admin" && m.UserID != userID {
			return false, nil
		}
	}
	for _, m := range memberships {
		if m.UserID == userID && m.Role == "admin" {
			return true, nil
		}
	}
	return false, nil
}
