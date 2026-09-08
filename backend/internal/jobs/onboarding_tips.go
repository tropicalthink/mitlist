package jobs

import (
	"context"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/onboarding"
	"github.com/mitlist-app/mitlist/internal/repositories"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// onboardingMailer is the slice of the mail service this job needs.
type onboardingMailer interface {
	SendHTMLWithHeaders(to, subject, html, text string, headers []mailservice.Header) error
}

// onboardingCandidate is a person who may be owed a step.
type onboardingCandidate struct {
	ID        uuid.UUID
	Email     string
	FirstName string
	CreatedAt time.Time
}

type onboardingRepo interface {
	// ListCandidates returns verified, non-guest, subscribed accounts created
	// inside the series' overall reach. Anyone older is past every window.
	ListCandidates(ctx context.Context, createdAfter time.Time, limit int) ([]onboardingCandidate, error)
	// LedgerFor returns the send ledger of one person: step key -> entry.
	LedgerFor(ctx context.Context, userID uuid.UUID) (map[string]onboardingLedgerEntry, error)
	MarkSent(ctx context.Context, userID uuid.UUID, step string) error
	MarkFailed(ctx context.Context, userID uuid.UUID, step string, reason string) error
}

type onboardingLedgerEntry struct {
	Sent           bool
	FailedAttempts int
}

// OnboardingTips sends the post-sign-up tips series. Runs hourly; each run
// sends every step that has come due and not yet gone out, up to a per-run
// cap that keeps a backlog from blowing the SES daily quota in one go.
type OnboardingTips struct {
	repo   onboardingRepo
	mail   onboardingMailer
	log    *logger.Logger
	secret []byte
	// appURL is the web app origin the buttons point at; apiURL and apiPrefix
	// build the unsubscribe link.
	appURL    string
	apiURL    string
	apiPrefix string
	now       func() time.Time
}

const (
	// onboardingMaxAttempts stops retrying a step that keeps failing.
	onboardingMaxAttempts = 3
	// onboardingPerRunCap bounds one run's sends. SES in production allows
	// far more, but a job that drains a backlog gradually is easier to
	// reason about and survives the sandbox's 200/day while testing.
	onboardingPerRunCap = 200
)

// NewOnboardingTips wires the job against the database and mail service.
func NewOnboardingTips(db repositories.DBTX, mail onboardingMailer, secret, appURL, apiURL, apiPrefix string, log *logger.Logger) *OnboardingTips {
	return &OnboardingTips{
		repo:      &onboardingRepoImpl{db: db},
		mail:      mail,
		log:       log,
		secret:    []byte(secret),
		appURL:    appURL,
		apiURL:    apiURL,
		apiPrefix: apiPrefix,
		now:       time.Now,
	}
}

func newOnboardingTips(repo onboardingRepo, mail onboardingMailer, log *logger.Logger) *OnboardingTips {
	return &OnboardingTips{
		repo:      repo,
		mail:      mail,
		log:       log,
		secret:    []byte("test-secret"),
		appURL:    "https://app.example.test",
		apiURL:    "https://api.example.test",
		apiPrefix: "/api",
		now:       time.Now,
	}
}

// Run sends whatever is due. Errors are logged per person; one bad address
// never stops the rest of the run.
func (j *OnboardingTips) Run() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	sent, failed := j.run(ctx)
	if sent > 0 || failed > 0 {
		j.log.Info().Int("sent", sent).Int("failed", failed).Msg("onboarding tips run finished")
	}
}

func (j *OnboardingTips) run(ctx context.Context) (sent, failed int) {
	now := j.now().UTC()
	// The oldest account that can still owe anything was created at
	// (last step's delay + window) ago.
	last := onboarding.Steps[len(onboarding.Steps)-1]
	createdAfter := now.Add(-(last.After + onboarding.SendWindow))

	candidates, err := j.repo.ListCandidates(ctx, createdAfter, 5000)
	if err != nil {
		j.log.WithError(err).Error().Msg("onboarding tips: list candidates failed")
		return 0, 0
	}

	for _, c := range candidates {
		if sent >= onboardingPerRunCap {
			return sent, failed
		}
		due := onboarding.Due(c.CreatedAt, now)
		if len(due) == 0 {
			continue
		}
		ledger, err := j.repo.LedgerFor(ctx, c.ID)
		if err != nil {
			j.log.WithError(err).Error().Str("user_id", c.ID.String()).Msg("onboarding tips: read ledger failed")
			continue
		}
		for _, step := range due {
			entry := ledger[step.Key]
			if entry.Sent || entry.FailedAttempts >= onboardingMaxAttempts {
				continue
			}
			if err := j.send(c, step); err != nil {
				failed++
				j.log.WithError(err).Warn().Str("user_id", c.ID.String()).Str("step", step.Key).Msg("onboarding tips: send failed")
				if merr := j.repo.MarkFailed(ctx, c.ID, step.Key, err.Error()); merr != nil {
					j.log.WithError(merr).Error().Str("user_id", c.ID.String()).Msg("onboarding tips: mark failed failed")
				}
				continue
			}
			if err := j.repo.MarkSent(ctx, c.ID, step.Key); err != nil {
				// The mail is out; a ledger write failing is the one case
				// that can double-send. Log loudly so it is seen.
				j.log.WithError(err).Error().Str("user_id", c.ID.String()).Str("step", step.Key).Msg("onboarding tips: mark sent failed after delivery")
			}
			sent++
			// One step per person per run: two steps due at once (a stalled
			// job catching up) arrive an hour apart instead of together.
			break
		}
	}
	return sent, failed
}

func (j *OnboardingTips) send(c onboardingCandidate, step onboarding.Step) error {
	token := onboarding.UnsubscribeToken(j.secret, c.ID)
	unsubscribe := onboarding.UnsubscribeURL(j.apiURL, j.apiPrefix, token)
	msg := onboarding.Render(step, c.FirstName, onboarding.Links{AppURL: j.appURL, UnsubscribeURL: unsubscribe})
	headers := []mailservice.Header{
		{Name: "List-Unsubscribe", Value: "<" + unsubscribe + ">"},
		{Name: "List-Unsubscribe-Post", Value: "List-Unsubscribe=One-Click"},
	}
	return j.mail.SendHTMLWithHeaders(c.Email, msg.Subject, msg.HTML, msg.Text, headers)
}

// onboardingRepoImpl is the SQL behind the job.
type onboardingRepoImpl struct {
	db repositories.DBTX
}

func (r *onboardingRepoImpl) ListCandidates(ctx context.Context, createdAfter time.Time, limit int) ([]onboardingCandidate, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, email, first_name, created_at
		FROM users
		WHERE deleted_at IS NULL
		  AND is_active AND is_verified AND NOT is_guest
		  AND tips_emails_enabled
		  AND email <> ''
		  AND created_at >= $1
		ORDER BY created_at
		LIMIT $2
	`, createdAfter, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []onboardingCandidate
	for rows.Next() {
		var c onboardingCandidate
		if err := rows.Scan(&c.ID, &c.Email, &c.FirstName, &c.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *onboardingRepoImpl) LedgerFor(ctx context.Context, userID uuid.UUID) (map[string]onboardingLedgerEntry, error) {
	rows, err := r.db.Query(ctx, `
		SELECT step, sent_at IS NOT NULL, failed_attempts
		FROM onboarding_email_sends
		WHERE user_id = $1
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]onboardingLedgerEntry{}
	for rows.Next() {
		var key string
		var e onboardingLedgerEntry
		if err := rows.Scan(&key, &e.Sent, &e.FailedAttempts); err != nil {
			return nil, err
		}
		out[key] = e
	}
	return out, rows.Err()
}

func (r *onboardingRepoImpl) MarkSent(ctx context.Context, userID uuid.UUID, step string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO onboarding_email_sends (user_id, step, sent_at, last_error, updated_at)
		VALUES ($1, $2, now(), NULL, now())
		ON CONFLICT (user_id, step) DO UPDATE
		SET sent_at = now(), last_error = NULL, updated_at = now()
	`, userID, step)
	return err
}

func (r *onboardingRepoImpl) MarkFailed(ctx context.Context, userID uuid.UUID, step, reason string) error {
	if len(reason) > 500 {
		reason = reason[:500]
	}
	_, err := r.db.Exec(ctx, `
		INSERT INTO onboarding_email_sends (user_id, step, failed_attempts, last_error, updated_at)
		VALUES ($1, $2, 1, $3, now())
		ON CONFLICT (user_id, step) DO UPDATE
		SET failed_attempts = onboarding_email_sends.failed_attempts + 1,
		    last_error = EXCLUDED.last_error,
		    updated_at = now()
	`, userID, step, reason)
	return err
}
