package repositories

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type TestingSignup struct {
	Email                string
	Platform             string
	ConsentVersion       string
	LaunchUpdates        bool
	LaunchConsentVersion *string
	LaunchConsentedAt    *time.Time
	CreatedAt            time.Time
}

type TestingSignupRepository struct{ pool *pgxpool.Pool }

func NewTestingSignupRepository(pool *pgxpool.Pool) *TestingSignupRepository {
	return &TestingSignupRepository{pool: pool}
}

// A repeated signup does not overwrite consent history or reveal membership.
func (r *TestingSignupRepository) Create(ctx context.Context, email, platform, consentVersion string, launchUpdates bool, launchConsentVersion string) error {
	var launchVersion *string
	var launchConsentedAt *time.Time
	if launchUpdates {
		now := time.Now()
		launchVersion = &launchConsentVersion
		launchConsentedAt = &now
	}
	_, err := r.pool.Exec(ctx, `INSERT INTO testing_signups
		(email, platform, consent_version, launch_updates, launch_consent_version, launch_consented_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (email, platform) DO UPDATE SET
			launch_updates = testing_signups.launch_updates OR EXCLUDED.launch_updates,
			launch_consent_version = CASE WHEN EXCLUDED.launch_updates THEN EXCLUDED.launch_consent_version ELSE testing_signups.launch_consent_version END,
			launch_consented_at = CASE WHEN EXCLUDED.launch_updates THEN EXCLUDED.launch_consented_at ELSE testing_signups.launch_consented_at END`,
		email, platform, consentVersion, launchUpdates, launchVersion, launchConsentedAt)
	return err
}

func (r *TestingSignupRepository) List(ctx context.Context, platform string) ([]TestingSignup, error) {
	rows, err := r.pool.Query(ctx, `SELECT email, platform, consent_version, launch_updates, launch_consent_version, launch_consented_at, created_at FROM testing_signups
		WHERE ($1 = '' OR platform = $1) ORDER BY created_at, id`, platform)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []TestingSignup{}
	for rows.Next() {
		var signup TestingSignup
		if err := rows.Scan(&signup.Email, &signup.Platform, &signup.ConsentVersion, &signup.LaunchUpdates, &signup.LaunchConsentVersion, &signup.LaunchConsentedAt, &signup.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, signup)
	}
	return result, rows.Err()
}
