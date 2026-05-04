package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

// GroupRepository provides data access for groups and related entities.
type GroupRepository struct {
	pool DBTX
}

// NewGroupRepository creates a new GroupRepository.
func NewGroupRepository(pool DBTX) *GroupRepository {
	return &GroupRepository{pool: pool}
}

// CreateGroup inserts a new group.
func (r *GroupRepository) CreateGroup(ctx context.Context, group *models.Group) error {
	if group.ID == uuid.Nil {
		group.ID = uuid.New()
	}
	now := time.Now().UTC()
	group.CreatedAt = now
	group.UpdatedAt = now

	query := `
		INSERT INTO groups (id, name, description, currency, created_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.pool.Exec(ctx, query,
		group.ID, group.Name, group.Description, group.Currency, group.CreatedBy, group.CreatedAt, group.UpdatedAt,
	)
	return err
}

// GetGroupByID retrieves a group by its ID.
func (r *GroupRepository) GetGroupByID(ctx context.Context, id uuid.UUID) (*models.Group, error) {
	query := `
		SELECT id, name, description, currency, created_by, created_at, updated_at
		FROM groups
		WHERE id = $1
	`
	row := r.pool.QueryRow(ctx, query, id)

	var g models.Group
	err := row.Scan(&g.ID, &g.Name, &g.Description, &g.Currency, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &g, nil
}

// ListGroupsByUser returns all groups a user is a member of.
func (r *GroupRepository) ListGroupsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Group, error) {
	if limit <= 0 {
		limit = 50
	}
	query := `
		SELECT g.id, g.name, g.description, g.currency, g.created_by, g.created_at, g.updated_at
		FROM groups g
		JOIN group_memberships gm ON g.id = gm.group_id
		WHERE gm.user_id = $1
		ORDER BY g.created_at DESC, g.id DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var groups []models.Group
	for rows.Next() {
		var g models.Group
		if err := rows.Scan(&g.ID, &g.Name, &g.Description, &g.Currency, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return groups, nil
}

// UpdateGroup updates an existing group.
func (r *GroupRepository) UpdateGroup(ctx context.Context, group *models.Group) error {
	group.UpdatedAt = time.Now().UTC()
	query := `
		UPDATE groups
		SET name = $1, description = $2, currency = COALESCE($5, currency), updated_at = $3
		WHERE id = $4
	`
	res, err := r.pool.Exec(ctx, query, group.Name, group.Description, group.UpdatedAt, group.ID, group.Currency)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("group not found")
	}
	return nil
}

// DeleteGroup hard-deletes a group by ID.
func (r *GroupRepository) DeleteGroup(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM groups WHERE id = $1`
	res, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("group not found")
	}
	return nil
}

// CreateMembership inserts a new group membership.
func (r *GroupRepository) CreateMembership(ctx context.Context, m *models.GroupMembership) error {
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	if m.JoinedAt.IsZero() {
		m.JoinedAt = time.Now().UTC()
	}

	query := `
		INSERT INTO group_memberships (id, group_id, user_id, role, joined_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.pool.Exec(ctx, query, m.ID, m.GroupID, m.UserID, m.Role, m.JoinedAt)
	return err
}

// GetMembership retrieves a membership by group and user ID.
func (r *GroupRepository) GetMembership(ctx context.Context, groupID, userID uuid.UUID) (*models.GroupMembership, error) {
	query := `
		SELECT id, group_id, user_id, role, joined_at
		FROM group_memberships
		WHERE group_id = $1 AND user_id = $2
	`
	row := r.pool.QueryRow(ctx, query, groupID, userID)

	var m models.GroupMembership
	err := row.Scan(&m.ID, &m.GroupID, &m.UserID, &m.Role, &m.JoinedAt)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// UpdateMembership updates an existing membership.
func (r *GroupRepository) UpdateMembership(ctx context.Context, m *models.GroupMembership) error {
	query := `
		UPDATE group_memberships
		SET role = $1
		WHERE id = $2
	`
	_, err := r.pool.Exec(ctx, query, m.Role, m.ID)
	return err
}

// DeleteMembership hard-deletes a membership by ID.
func (r *GroupRepository) DeleteMembership(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM group_memberships WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// CreateInvite inserts a new group invite.
func (r *GroupRepository) CreateInvite(ctx context.Context, invite *models.GroupInvite) error {
	if invite.ID == uuid.Nil {
		invite.ID = uuid.New()
	}

	query := `
		INSERT INTO group_invites (id, group_id, code, expires_at, used_by, used_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, query,
		invite.ID, invite.GroupID, invite.Code, invite.ExpiresAt, invite.UsedBy, invite.UsedAt,
	)
	return err
}

// GetInviteByCode retrieves an invite by its code.
func (r *GroupRepository) GetInviteByCode(ctx context.Context, code string) (*models.GroupInvite, error) {
	query := `
		SELECT id, group_id, code, expires_at, used_by, used_at
		FROM group_invites
		WHERE code = $1
	`
	row := r.pool.QueryRow(ctx, query, code)

	var i models.GroupInvite
	err := row.Scan(&i.ID, &i.GroupID, &i.Code, &i.ExpiresAt, &i.UsedBy, &i.UsedAt)
	if err != nil {
		return nil, err
	}
	return &i, nil
}

// ConsumeInvite marks an invite as used.
func (r *GroupRepository) ConsumeInvite(ctx context.Context, inviteID, userID uuid.UUID) error {
	now := time.Now().UTC()
	query := `
		UPDATE group_invites
		SET used_by = $1, used_at = $2
		WHERE id = $3
	`
	_, err := r.pool.Exec(ctx, query, userID, now, inviteID)
	return err
}

// CreatePendingClaim inserts a new pending claim.
func (r *GroupRepository) CreatePendingClaim(ctx context.Context, claim *models.PendingClaim) error {
	if claim.ID == uuid.Nil {
		claim.ID = uuid.New()
	}

	query := `
		INSERT INTO pending_claims (id, group_id, code, expires_at, claimed_by, claimed_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err := r.pool.Exec(ctx, query,
		claim.ID, claim.GroupID, claim.Code, claim.ExpiresAt, claim.ClaimedBy, claim.ClaimedAt,
	)
	return err
}

// GetPendingClaimByCode retrieves a pending claim by its code.
func (r *GroupRepository) GetPendingClaimByCode(ctx context.Context, code string) (*models.PendingClaim, error) {
	query := `
		SELECT id, group_id, code, expires_at, claimed_by, claimed_at
		FROM pending_claims
		WHERE code = $1
	`
	row := r.pool.QueryRow(ctx, query, code)

	var c models.PendingClaim
	err := row.Scan(&c.ID, &c.GroupID, &c.Code, &c.ExpiresAt, &c.ClaimedBy, &c.ClaimedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// DeletePendingClaim hard-deletes a pending claim by ID.
func (r *GroupRepository) DeletePendingClaim(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM pending_claims WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

// ListMembershipsByGroup returns all memberships for a group, ordered by user_id for determinism.
func (r *GroupRepository) ListMembershipsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMembership, error) {
	query := `
		SELECT id, group_id, user_id, role, joined_at
		FROM group_memberships
		WHERE group_id = $1
		ORDER BY user_id ASC
	`
	rows, err := r.pool.Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var memberships []models.GroupMembership
	for rows.Next() {
		var m models.GroupMembership
		if err := rows.Scan(&m.ID, &m.GroupID, &m.UserID, &m.Role, &m.JoinedAt); err != nil {
			return nil, err
		}
		memberships = append(memberships, m)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return memberships, nil
}

// ListMemberProfilesByGroup returns member display information for a group.
func (r *GroupRepository) ListMemberProfilesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMemberProfile, error) {
	query := `
		SELECT u.id, trim(u.first_name || ' ' || u.last_name) AS display_name, gm.role
		FROM group_memberships gm
		JOIN users u ON u.id = gm.user_id
		WHERE gm.group_id = $1
		ORDER BY display_name ASC, u.id ASC
	`
	rows, err := r.pool.Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var profiles []models.GroupMemberProfile
	for rows.Next() {
		var p models.GroupMemberProfile
		if err := rows.Scan(&p.UserID, &p.DisplayName, &p.Role); err != nil {
			return nil, err
		}
		profiles = append(profiles, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return profiles, nil
}

// GetPendingClaimByID retrieves a pending claim by its ID.
func (r *GroupRepository) GetPendingClaimByID(ctx context.Context, id uuid.UUID) (*models.PendingClaim, error) {
	query := `
		SELECT id, group_id, code, expires_at, claimed_by, claimed_at
		FROM pending_claims
		WHERE id = $1
	`
	row := r.pool.QueryRow(ctx, query, id)

	var c models.PendingClaim
	err := row.Scan(&c.ID, &c.GroupID, &c.Code, &c.ExpiresAt, &c.ClaimedBy, &c.ClaimedAt)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

// ListPendingClaimsByGroup returns all pending claims for a group.
func (r *GroupRepository) ListPendingClaimsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.PendingClaim, error) {
	query := `
		SELECT id, group_id, code, expires_at, claimed_by, claimed_at
		FROM pending_claims
		WHERE group_id = $1
		ORDER BY expires_at DESC
	`
	rows, err := r.pool.Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var claims []models.PendingClaim
	for rows.Next() {
		var c models.PendingClaim
		if err := rows.Scan(&c.ID, &c.GroupID, &c.Code, &c.ExpiresAt, &c.ClaimedBy, &c.ClaimedAt); err != nil {
			return nil, err
		}
		claims = append(claims, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return claims, nil
}

// compile-time interface check helpers
var (
	_ = pgx.ErrNoRows
)
