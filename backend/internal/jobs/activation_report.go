package jobs

import (
	"context"
	"time"

	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// activationWindow is how long a new household has to get going.
const activationWindow = 7 * 24 * time.Hour

// activationCounts is one weekly cohort: the households created in a week.
type activationCounts struct {
	Households int
	// Activated: within activationWindow of the household's creation, at
	// least two distinct members each acted on a shared item.
	Activated int
	// Precursor: the creator added at least three things in the first hour
	// after creating the household (the single-player early sign).
	Precursor int
}

type activationRepo interface {
	// CountActivation measures the households created in [from, to).
	CountActivation(ctx context.Context, from, to time.Time) (activationCounts, error)
}

// ActivationReport logs the weekly activation number (plans/048 stage 8):
// of the households created in the week whose seven-day window has just
// closed, how many had two or more members each act on a shared item. It
// reads the existing household tables, so it measures the past as well as
// the future and needs no event tracking.
type ActivationReport struct {
	repo activationRepo
	log  *logger.Logger
	now  func() time.Time
}

func NewActivationReport(db repositories.DBTX, log *logger.Logger) *ActivationReport {
	return &ActivationReport{repo: &activationRepoImpl{db: db}, log: log, now: time.Now}
}

// Run reports the cohort created between 14 and 7 days ago: every household
// in it has had its full week.
func (j *ActivationReport) Run() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	j.run(ctx)
}

func (j *ActivationReport) run(ctx context.Context) (activationCounts, bool) {
	to := j.now().UTC().Add(-activationWindow)
	from := to.Add(-7 * 24 * time.Hour)
	counts, err := j.repo.CountActivation(ctx, from, to)
	if err != nil {
		j.log.WithError(err).Error().Msg("activation report: count failed")
		return activationCounts{}, false
	}
	rate := 0.0
	if counts.Households > 0 {
		rate = float64(counts.Activated) / float64(counts.Households)
	}
	j.log.Info().
		Time("cohort_from", from).
		Time("cohort_to", to).
		Int("households", counts.Households).
		Int("activated", counts.Activated).
		Float64("activation_rate", rate).
		Int("precursor", counts.Precursor).
		Msg("weekly household activation")
	return counts, true
}

type activationRepoImpl struct {
	db repositories.DBTX
}

// CountActivation counts "acting on a shared item" from the tables that
// record who did it and when: chore completions (completed_by), list items
// (added_by: check-offs record no actor, so adding to a shared list stands in
// for ticking one off), expenses (payer_id, the only actor an expense
// records) and settlements (created_by).
func (r *activationRepoImpl) CountActivation(ctx context.Context, from, to time.Time) (activationCounts, error) {
	var c activationCounts
	err := r.db.QueryRow(ctx, `
		WITH cohort AS (
			SELECT g.id, g.created_by, g.created_at
			FROM groups g
			WHERE g.created_at >= $1 AND g.created_at < $2
		),
		acts AS (
			SELECT ch.group_id, cc.completed_by AS user_id, cc.completed_at AS at
			FROM chore_completions cc
			JOIN chore_assignments ca ON ca.id = cc.assignment_id
			JOIN chores ch ON ch.id = ca.chore_id
			WHERE ch.group_id IN (SELECT id FROM cohort)
			UNION ALL
			SELECT l.group_id, li.added_by, li.created_at
			FROM list_items li
			JOIN lists l ON l.id = li.list_id
			WHERE li.added_by IS NOT NULL AND l.group_id IN (SELECT id FROM cohort)
			UNION ALL
			SELECT e.group_id, e.payer_id, e.created_at
			FROM expenses e
			WHERE e.group_id IN (SELECT id FROM cohort)
			UNION ALL
			SELECT s.group_id, s.created_by, s.created_at
			FROM settlements s
			WHERE s.group_id IN (SELECT id FROM cohort)
		),
		per_household AS (
			SELECT c.id,
			       COUNT(DISTINCT a.user_id) FILTER (
			           WHERE a.at < c.created_at + interval '7 days'
			       ) AS actors,
			       COUNT(*) FILTER (
			           WHERE a.user_id = c.created_by AND a.at < c.created_at + interval '1 hour'
			       ) AS creator_first_hour
			FROM cohort c
			LEFT JOIN acts a ON a.group_id = c.id
			GROUP BY c.id
		)
		SELECT COUNT(*),
		       COUNT(*) FILTER (WHERE actors >= 2),
		       COUNT(*) FILTER (WHERE creator_first_hour >= 3)
		FROM per_household
	`, from, to).Scan(&c.Households, &c.Activated, &c.Precursor)
	return c, err
}
