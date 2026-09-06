package repositories

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type TestingSignup struct {
	Email          string
	Platform       string
	ConsentVersion string
	CreatedAt      time.Time
}

type TestingSignupRepository struct{ pool *pgxpool.Pool }

func NewTestingSignupRepository(pool *pgxpool.Pool) *TestingSignupRepository {
	return &TestingSignupRepository{pool: pool}
}

// A repeated signup does not overwrite consent history or reveal membership.
func (r *TestingSignupRepository) Create(ctx context.Context, email, platform, consentVersion string) error {
	_, err := r.pool.Exec(ctx, `INSERT INTO testing_signups (email, platform, consent_version)
		VALUES ($1, $2, $3) ON CONFLICT (email, platform) DO NOTHING`, email, platform, consentVersion)
	return err
}

func (r *TestingSignupRepository) List(ctx context.Context, platform string) ([]TestingSignup, error) {
	rows, err := r.pool.Query(ctx, `SELECT email, platform, consent_version, created_at FROM testing_signups
		WHERE ($1 = '' OR platform = $1) ORDER BY created_at, id`, platform)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := []TestingSignup{}
	for rows.Next() {
		var signup TestingSignup
		if err := rows.Scan(&signup.Email, &signup.Platform, &signup.ConsentVersion, &signup.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, signup)
	}
	return result, rows.Err()
}
