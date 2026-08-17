package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/models"
)

func isNoRows(err error) bool {
	return errors.Is(err, pgx.ErrNoRows)
}

// BillingRepository provides data access for premium subscriptions.
type BillingRepository struct {
	pool DBTX
}

// NewBillingRepository creates a new BillingRepository.
func NewBillingRepository(pool DBTX) *BillingRepository {
	return &BillingRepository{pool: pool}
}

const billingSubscriptionColumns = `
	id, user_id, primary_group_id, provider, provider_subscription_id, provider_customer_id,
	product_id, status, recurring_interval, amount_cents, currency, discount_id,
	current_period_end, cancel_at_period_end, trial_end, started_at, ends_at,
	provider_modified_at, created_at, updated_at
`

func scanBillingSubscription(row interface {
	Scan(dest ...any) error
}) (*models.BillingSubscription, error) {
	var s models.BillingSubscription
	err := row.Scan(
		&s.ID, &s.UserID, &s.PrimaryGroupID, &s.Provider, &s.ProviderSubscriptionID, &s.ProviderCustomerID,
		&s.ProductID, &s.Status, &s.RecurringInterval, &s.AmountCents, &s.Currency, &s.DiscountID,
		&s.CurrentPeriodEnd, &s.CancelAtPeriodEnd, &s.TrialEnd, &s.StartedAt, &s.EndsAt,
		&s.ProviderModifiedAt, &s.CreatedAt, &s.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// UpsertSubscription inserts or updates a subscription keyed by its provider
// ID. Deliveries can arrive out of order, so an update whose provider timestamp
// is older than the stored one is ignored; the returned row is always the
// current stored state.
func (r *BillingRepository) UpsertSubscription(ctx context.Context, s *models.BillingSubscription) (*models.BillingSubscription, error) {
	if s.ID == uuid.Nil {
		s.ID = uuid.New()
	}
	if s.Provider == "" {
		s.Provider = "polar"
	}

	query := `
		INSERT INTO billing_subscriptions (
			id, user_id, primary_group_id, provider, provider_subscription_id, provider_customer_id,
			product_id, status, recurring_interval, amount_cents, currency, discount_id,
			current_period_end, cancel_at_period_end, trial_end, started_at, ends_at,
			provider_modified_at, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, NOW(), NOW())
		ON CONFLICT (provider, provider_subscription_id) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			-- Never clobber a household the owner has already chosen: renewals
			-- and status changes carry checkout metadata that may be stale or
			-- absent. Only fill it in when nothing is set yet.
			primary_group_id = COALESCE(billing_subscriptions.primary_group_id, EXCLUDED.primary_group_id),
			provider_customer_id = EXCLUDED.provider_customer_id,
			product_id = EXCLUDED.product_id,
			status = EXCLUDED.status,
			recurring_interval = EXCLUDED.recurring_interval,
			amount_cents = EXCLUDED.amount_cents,
			currency = EXCLUDED.currency,
			discount_id = EXCLUDED.discount_id,
			current_period_end = EXCLUDED.current_period_end,
			cancel_at_period_end = EXCLUDED.cancel_at_period_end,
			trial_end = EXCLUDED.trial_end,
			started_at = EXCLUDED.started_at,
			ends_at = EXCLUDED.ends_at,
			provider_modified_at = EXCLUDED.provider_modified_at,
			updated_at = NOW()
		WHERE billing_subscriptions.provider_modified_at IS NULL
		   OR EXCLUDED.provider_modified_at IS NULL
		   OR EXCLUDED.provider_modified_at >= billing_subscriptions.provider_modified_at
		RETURNING ` + billingSubscriptionColumns

	row := r.pool.QueryRow(ctx, query,
		s.ID, s.UserID, s.PrimaryGroupID, s.Provider, s.ProviderSubscriptionID, s.ProviderCustomerID,
		s.ProductID, s.Status, s.RecurringInterval, s.AmountCents, s.Currency, s.DiscountID,
		s.CurrentPeriodEnd, s.CancelAtPeriodEnd, s.TrialEnd, s.StartedAt, s.EndsAt,
		s.ProviderModifiedAt,
	)

	updated, err := scanBillingSubscription(row)
	if err == nil {
		return updated, nil
	}
	// No row came back: the ON CONFLICT guard rejected a stale delivery. The
	// stored row is newer and stands.
	if isNoRows(err) {
		return r.GetSubscriptionByProviderID(ctx, s.Provider, s.ProviderSubscriptionID)
	}
	return nil, err
}

// SupersedeSubscription closes a provider row that was replaced by another
// purchase token (Google plan changes). It is deliberately provider-scoped and
// monotonic so an old RTDN delivery cannot reactivate the superseded token.
func (r *BillingRepository) SupersedeSubscription(ctx context.Context, provider, providerSubscriptionID string, supersededAt time.Time) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE billing_subscriptions
		SET status = 'canceled', cancel_at_period_end = false,
			current_period_end = LEAST(COALESCE(current_period_end, $3), $3),
			ends_at = $3, provider_modified_at = $3, updated_at = NOW()
		WHERE provider = $1 AND provider_subscription_id = $2
		  AND (provider_modified_at IS NULL OR provider_modified_at <= $3)`,
		provider, providerSubscriptionID, supersededAt)
	return err
}

// GetSubscriptionByProviderID looks up a subscription by the provider's ID.
func (r *BillingRepository) GetSubscriptionByProviderID(ctx context.Context, provider, providerSubscriptionID string) (*models.BillingSubscription, error) {
	query := `SELECT ` + billingSubscriptionColumns + `
		FROM billing_subscriptions
		WHERE provider = $1 AND provider_subscription_id = $2`
	return scanBillingSubscription(r.pool.QueryRow(ctx, query, provider, providerSubscriptionID))
}

// ListSubscriptionsByUser returns every subscription a user holds, newest first.
func (r *BillingRepository) ListSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.BillingSubscription, error) {
	query := `SELECT ` + billingSubscriptionColumns + `
		FROM billing_subscriptions
		WHERE user_id = $1
		ORDER BY created_at DESC`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var subs []models.BillingSubscription
	for rows.Next() {
		s, err := scanBillingSubscription(rows)
		if err != nil {
			return nil, err
		}
		subs = append(subs, *s)
	}
	return subs, rows.Err()
}

// GetLiveSubscriptionForUser returns the user's own entitlement-granting
// subscription, or nil when they hold none.
func (r *BillingRepository) GetLiveSubscriptionForUser(ctx context.Context, userID uuid.UUID) (*models.BillingSubscription, error) {
	query := `SELECT ` + billingSubscriptionColumns + `
		FROM billing_subscriptions
		WHERE user_id = $1
		  AND status IN ('active', 'trialing')
		  AND (current_period_end IS NULL OR current_period_end > NOW())
		ORDER BY current_period_end DESC NULLS FIRST
		LIMIT 1`
	s, err := scanBillingSubscription(r.pool.QueryRow(ctx, query, userID))
	if isNoRows(err) {
		return nil, nil
	}
	return s, err
}

// GetGroupCoverage reports whether this household is some member's designated
// premium household, and the display name of that member.
//
// A subscription covers exactly the one household it is pinned to, so the payer
// must both have chosen this group and still be a member of it — otherwise a
// payer could leave and strand premium behind them.
func (r *BillingRepository) GetGroupCoverage(ctx context.Context, groupID uuid.UUID) (bool, *string, error) {
	query := `
		SELECT trim(u.first_name || ' ' || u.last_name) AS display_name
		FROM billing_subscriptions s
		JOIN group_memberships gm ON gm.user_id = s.user_id AND gm.group_id = s.primary_group_id
		JOIN users u ON u.id = s.user_id
		WHERE s.primary_group_id = $1
		  AND s.status IN ('active', 'trialing')
		  AND (s.current_period_end IS NULL OR s.current_period_end > NOW())
		ORDER BY s.created_at ASC
		LIMIT 1`

	var name string
	err := r.pool.QueryRow(ctx, query, groupID).Scan(&name)
	if isNoRows(err) {
		return false, nil, nil
	}
	if err != nil {
		return false, nil, err
	}
	return true, &name, nil
}

// SetPrimaryGroupForUser moves the user's live subscription to cover groupID,
// the way a console is made primary. Passing uuid.Nil unpins it, leaving the
// subscription covering nothing.
//
// Returns nil when the user holds no live subscription; callers treat that as
// "nothing to move".
func (r *BillingRepository) SetPrimaryGroupForUser(ctx context.Context, userID, groupID uuid.UUID) (*models.BillingSubscription, error) {
	var target *uuid.UUID
	if groupID != uuid.Nil {
		target = &groupID
	}

	// Scoped to the same live-subscription definition used everywhere else, so
	// an expired row can never be re-pointed at a household.
	query := `
		UPDATE billing_subscriptions
		SET primary_group_id = $2, updated_at = NOW()
		WHERE id = (
			SELECT id FROM billing_subscriptions
			WHERE user_id = $1
			  AND status IN ('active', 'trialing')
			  AND (current_period_end IS NULL OR current_period_end > NOW())
			ORDER BY current_period_end DESC NULLS FIRST
			LIMIT 1
		)
		RETURNING ` + billingSubscriptionColumns

	s, err := scanBillingSubscription(r.pool.QueryRow(ctx, query, userID, target))
	if isNoRows(err) {
		return nil, nil
	}
	return s, err
}

// CountGroupMembers returns the number of members in a group.
func (r *BillingRepository) CountGroupMembers(ctx context.Context, groupID uuid.UUID) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM group_memberships WHERE group_id = $1`, groupID).Scan(&count)
	return count, err
}

// MarkWebhookEventProcessed records a delivery ID and reports whether it was
// newly recorded. A false result means the event was already applied and the
// caller should skip it.
func (r *BillingRepository) MarkWebhookEventProcessed(ctx context.Context, id, provider, eventType string) (bool, error) {
	tag, err := r.pool.Exec(ctx,
		`INSERT INTO billing_webhook_events (id, provider, event_type)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (id) DO NOTHING`,
		id, provider, eventType)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() > 0, nil
}

// DeleteWebhookEventsBefore prunes processed delivery IDs older than cutoff.
func (r *BillingRepository) DeleteWebhookEventsBefore(ctx context.Context, cutoff time.Time) (int64, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM billing_webhook_events WHERE processed_at < $1`, cutoff)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
