package jobs

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/onboarding"
	"github.com/mitlist-app/mitlist/internal/repositories"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// reengagementCandidate is a person who has stopped opening the app.
type reengagementCandidate struct {
	ID           uuid.UUID
	Email        string
	FirstName    string
	LastActiveAt time.Time
	HasAndroid   bool
	// Language is the app language the person's app last reported; empty
	// when it never has, and the email falls back to English.
	Language string
}

type reengagementRepo interface {
	// ListCandidates returns verified, subscribed full accounts whose last
	// app use falls in [idleFloor, idleCutoff), who have had no check-in since
	// cooldownSince and no onboarding tip since quietSince.
	ListCandidates(ctx context.Context, idleCutoff, idleFloor, cooldownSince, quietSince time.Time, limit int) ([]reengagementCandidate, error)
	// Claim reserves the check-in for one inactivity episode before mail
	// leaves the process; only one scheduler instance can win it.
	Claim(ctx context.Context, userID uuid.UUID, inactiveSince time.Time) (bool, error)
	MarkSent(ctx context.Context, userID uuid.UUID, inactiveSince time.Time) error
	MarkFailed(ctx context.Context, userID uuid.UUID, inactiveSince time.Time, reason string) error
}

// Reengagement emails a feedback check-in to people who have not opened the
// app for a week. Runs daily; like the onboarding tips it is at-most-once per
// episode, so an ambiguous provider failure skips a person rather than
// mailing them twice.
type Reengagement struct {
	repo   reengagementRepo
	mail   onboardingMailer
	log    *logger.Logger
	secret []byte
	// appURL is the web app origin the feedback button points at; apiURL
	// and apiPrefix build the unsubscribe link.
	appURL    string
	apiURL    string
	apiPrefix string
	now       func() time.Time
}

const (
	// reengagementPerRunCap bounds one day's sends, so the first run after
	// launch works through the backlog of lapsed accounts over a few days.
	reengagementPerRunCap = 200
	// reengagementQuietAfterTip keeps the check-in from landing next to an
	// onboarding tip: a new account that went quiet gets its day-7 tip and
	// the check-in on different days.
	reengagementQuietAfterTip = 48 * time.Hour
)

// NewReengagement wires the job against the database and mail service.
func NewReengagement(db repositories.DBTX, mail onboardingMailer, secret, appURL, apiURL, apiPrefix string, log *logger.Logger) *Reengagement {
	return &Reengagement{
		repo:      &reengagementRepoImpl{db: db},
		mail:      mail,
		log:       log,
		secret:    []byte(secret),
		appURL:    appURL,
		apiURL:    apiURL,
		apiPrefix: apiPrefix,
		now:       time.Now,
	}
}

// Run sends whatever is due. Errors are logged per person; one bad address
// never stops the rest of the run.
func (j *Reengagement) Run() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	sent, failed := j.run(ctx)
	if sent > 0 || failed > 0 {
		j.log.Info().Int("sent", sent).Int("failed", failed).Msg("reengagement run finished")
	}
}

func (j *Reengagement) run(ctx context.Context) (sent, failed int) {
	now := j.now().UTC()
	candidates, err := j.repo.ListCandidates(ctx,
		now.Add(-onboarding.ReengagementAfter),
		now.Add(-onboarding.ReengagementMaxIdle),
		now.Add(-onboarding.ReengagementCooldown),
		now.Add(-reengagementQuietAfterTip),
		reengagementPerRunCap,
	)
	if err != nil {
		j.log.WithError(err).Error().Msg("reengagement: list candidates failed")
		return 0, 0
	}

	for _, c := range candidates {
		claimed, err := j.repo.Claim(ctx, c.ID, c.LastActiveAt)
		if err != nil {
			j.log.WithError(err).Error().Str("user_id", c.ID.String()).Msg("reengagement: claim failed")
			continue
		}
		if !claimed {
			continue
		}
		if err := j.send(c); err != nil {
			failed++
			j.log.WithError(err).Warn().Str("user_id", c.ID.String()).Msg("reengagement: send failed")
			if merr := j.repo.MarkFailed(ctx, c.ID, c.LastActiveAt, err.Error()); merr != nil {
				j.log.WithError(merr).Error().Str("user_id", c.ID.String()).Msg("reengagement: mark failed failed")
			}
			continue
		}
		if err := j.repo.MarkSent(ctx, c.ID, c.LastActiveAt); err != nil {
			// Claim already made the attempt durable, so a ledger write
			// failure here cannot cause another delivery.
			j.log.WithError(err).Error().Str("user_id", c.ID.String()).Msg("reengagement: record success failed")
		}
		sent++
	}
	return sent, failed
}

func (j *Reengagement) send(c reengagementCandidate) error {
	token := onboarding.UnsubscribeToken(j.secret, c.ID)
	unsubscribe := onboarding.UnsubscribeURL(j.apiURL, j.apiPrefix, token)
	msg := onboarding.RenderReengagement(c.Language, c.FirstName, onboarding.ReengagementLinks{
		AppURL:         j.appURL,
		UnsubscribeURL: unsubscribe,
		ShowRating:     c.HasAndroid,
	})
	headers := []mailservice.Header{
		{Name: "List-Unsubscribe", Value: "<" + unsubscribe + ">"},
		{Name: "List-Unsubscribe-Post", Value: "List-Unsubscribe=One-Click"},
	}
	return j.mail.SendHTMLWithHeadersOnce(c.Email, msg.Subject, msg.HTML, msg.Text, headers)
}

// reengagementRepoImpl is the SQL behind the job.
type reengagementRepoImpl struct {
	db repositories.DBTX
}

func (r *reengagementRepoImpl) ListCandidates(ctx context.Context, idleCutoff, idleFloor, cooldownSince, quietSince time.Time, limit int) ([]reengagementCandidate, error) {
	rows, err := r.db.Query(ctx, `
		SELECT u.id, u.email, u.first_name, u.last_active_at,
		       COALESCE(u.language, '') AS language,
		       EXISTS (
		           SELECT 1 FROM device_tokens d
		           WHERE d.user_id = u.id AND d.platform = 'android'
		       ) AS has_android
		FROM users u
		WHERE u.deleted_at IS NULL
		  AND u.is_active AND u.is_verified AND NOT u.is_guest
		  AND u.tips_emails_enabled
		  AND u.email <> ''
		  AND u.last_active_at < $1
		  AND u.last_active_at >= $2
		  AND NOT EXISTS (
		      SELECT 1 FROM reengagement_email_sends r
		      WHERE r.user_id = u.id AND r.attempted_at >= $3
		  )
		  AND NOT EXISTS (
		      SELECT 1 FROM onboarding_email_sends o
		      WHERE o.user_id = u.id AND o.attempted_at >= $4
		  )
		ORDER BY u.last_active_at
		LIMIT $5
	`, idleCutoff, idleFloor, cooldownSince, quietSince, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []reengagementCandidate
	for rows.Next() {
		var c reengagementCandidate
		if err := rows.Scan(&c.ID, &c.Email, &c.FirstName, &c.LastActiveAt, &c.Language, &c.HasAndroid); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *reengagementRepoImpl) Claim(ctx context.Context, userID uuid.UUID, inactiveSince time.Time) (bool, error) {
	var claimed bool
	err := r.db.QueryRow(ctx, `
		INSERT INTO reengagement_email_sends (user_id, inactive_since, attempted_at, updated_at)
		VALUES ($1, $2, now(), now())
		ON CONFLICT (user_id, inactive_since) DO NOTHING
		RETURNING true
	`, userID, inactiveSince).Scan(&claimed)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return claimed, err
}

func (r *reengagementRepoImpl) MarkSent(ctx context.Context, userID uuid.UUID, inactiveSince time.Time) error {
	_, err := r.db.Exec(ctx, `
		UPDATE reengagement_email_sends
		SET sent_at = now(), last_error = NULL, updated_at = now()
		WHERE user_id = $1 AND inactive_since = $2
	`, userID, inactiveSince)
	return err
}

func (r *reengagementRepoImpl) MarkFailed(ctx context.Context, userID uuid.UUID, inactiveSince time.Time, reason string) error {
	if len(reason) > 500 {
		reason = reason[:500]
	}
	_, err := r.db.Exec(ctx, `
		UPDATE reengagement_email_sends
		SET last_error = $3, updated_at = now()
		WHERE user_id = $1 AND inactive_since = $2
	`, userID, inactiveSince, reason)
	return err
}
