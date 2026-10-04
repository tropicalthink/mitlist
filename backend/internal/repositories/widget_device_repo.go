package repositories

import (
	"context"

	"github.com/google/uuid"
)

// WidgetDeviceRepository answers the refresh-push questions about devices
// running home screen widgets (plans/047, contract C6): which people have a
// live widget credential, and which WidgetKit push tokens their widget
// extensions registered. A credential is live when it is not revoked, not
// expired and newer than the owner's auth cutoff, as in GetActiveByHash.
type WidgetDeviceRepository struct{ db DBTX }

func NewWidgetDeviceRepository(db DBTX) *WidgetDeviceRepository {
	return &WidgetDeviceRepository{db: db}
}

const liveWidgetCredential = `ic.kind = 'widget' AND ic.revoked_at IS NULL AND ic.expires_at > NOW()
	  AND ic.created_at > (SELECT u.auth_valid_after FROM users u WHERE u.id = ic.user_id)`

// ListUsersWithWidgets returns the subset of userIDs holding a live widget
// credential.
func (r *WidgetDeviceRepository) ListUsersWithWidgets(ctx context.Context, userIDs []uuid.UUID) ([]uuid.UUID, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT ic.user_id FROM integration_credentials ic
		WHERE ic.user_id = ANY($1) AND `+liveWidgetCredential, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// ListPushTokens returns the WidgetKit push tokens registered by userIDs'
// live widget credentials.
func (r *WidgetDeviceRepository) ListPushTokens(ctx context.Context, userIDs []uuid.UUID) ([]string, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT ic.push_token FROM integration_credentials ic
		WHERE ic.user_id = ANY($1) AND ic.push_token IS NOT NULL AND `+liveWidgetCredential, userIDs)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var token string
		if err := rows.Scan(&token); err != nil {
			return nil, err
		}
		out = append(out, token)
	}
	return out, rows.Err()
}

// SetPushToken records the WidgetKit push token of the widget credential
// credentialID. It reports false when that credential is not a live widget
// credential (revoked in the meantime, or not a widget credential at all).
func (r *WidgetDeviceRepository) SetPushToken(ctx context.Context, credentialID uuid.UUID, token string) (bool, error) {
	tag, err := r.db.Exec(ctx, `
		UPDATE integration_credentials ic SET push_token = $2
		WHERE ic.id = $1 AND `+liveWidgetCredential, credentialID, token)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// ClearPushToken forgets a token APNs reported as no longer valid.
func (r *WidgetDeviceRepository) ClearPushToken(ctx context.Context, token string) error {
	_, err := r.db.Exec(ctx, `UPDATE integration_credentials SET push_token = NULL WHERE push_token = $1`, token)
	return err
}
