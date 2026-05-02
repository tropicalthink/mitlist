package jobs

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/robfig/cron/v3"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Runner manages all background jobs using robfig/cron/v3.
type Runner struct {
	cron       *cron.Cron
	pool       *pgxpool.Pool
	push       Pusher
	log        *logger.Logger
	jobs       []jobMeta
	entryNames map[cron.EntryID]string
}

type jobMeta struct {
	Name     string    `json:"name"`
	Schedule string    `json:"schedule"`
	Enabled  bool      `json:"enabled"`
	NextRun  time.Time `json:"next_run,omitempty"`
}

// NewRunner creates a new job runner.
func NewRunner(pool *pgxpool.Pool, pushSvc Pusher, log *logger.Logger) *Runner {
	return &Runner{
		cron:       cron.New(cron.WithChain(cron.SkipIfStillRunning(nil), cron.Recover(cron.DefaultLogger))),
		pool:       pool,
		push:       pushSvc,
		log:        log,
		entryNames: make(map[cron.EntryID]string),
	}
}

// RegisterAll registers all background jobs with their schedules.
func (r *Runner) RegisterAll() {
	// T82: Chore scheduler — daily at 00:01
	cs := NewChoreScheduler(r.pool, r.log)
	r.register("chore-scheduler", "1 0 * * *", cs.Run, true)

	// T84: Recurring expense — hourly
	re := NewRecurringExpenseJob(r.pool, r.push, r.log)
	r.register("recurring-expense", "0 * * * *", re.Run, true)

	// T86: Chore reminder — daily at 09:00
	cr := NewChoreReminder(r.pool, r.push, r.log)
	r.register("chore-reminder", "0 9 * * *", cr.Run, true)

	// T87: Weekly summary — disabled by default (Monday 09:00)
	ws := NewWeeklySummary(r.pool, r.push, r.log)
	r.register("weekly-summary", "0 9 * * 1", ws.Run, true)

	// Pinwall reminders — every minute
	pr := NewPinwallReminder(r.pool, r.push, r.log)
	r.register("pinwall-reminder", "* * * * *", pr.Run, true)
}

func (r *Runner) register(name, spec string, fn func(), enabled bool) {
	meta := jobMeta{
		Name:     name,
		Schedule: spec,
		Enabled:  enabled,
	}

	if !enabled {
		r.log.Info().Str("job", name).Msg("job registered but disabled")
		r.jobs = append(r.jobs, meta)
		return
	}

	wrapped := func() {
		start := time.Now()
		r.log.Info().Str("job", name).Time("start", start).Msg("job started")
		fn()
		r.log.Info().Str("job", name).Dur("duration", time.Since(start)).Msg("job finished")
	}

	id, err := r.cron.AddFunc(spec, wrapped)
	if err != nil {
		r.log.Error().Err(err).Str("job", name).Str("schedule", spec).Msg("failed to register job")
		r.jobs = append(r.jobs, meta)
		return
	}

	r.entryNames[id] = name
	entry := r.cron.Entry(id)
	meta.NextRun = entry.Next
	r.jobs = append(r.jobs, meta)
	r.log.Info().Str("job", name).Str("schedule", spec).Time("next_run", entry.Next).Msg("job registered")
}

// Start begins the cron scheduler.
func (r *Runner) Start() {
	r.cron.Start()
	r.log.Info().Msg("job runner started")
}

// Stop gracefully shuts down the runner, waiting for running jobs to finish.
func (r *Runner) Stop(shutdownCtx context.Context) {
	r.log.Info().Msg("stopping job runner")
	doneCtx := r.cron.Stop()
	select {
	case <-doneCtx.Done():
	case <-shutdownCtx.Done():
		r.log.Warn().Msg("shutdown timeout exceeded while waiting for jobs")
	}
	r.log.Info().Msg("job runner stopped")
}

// DebugHandler exposes registered job schedules as JSON.
func (r *Runner) DebugHandler(w http.ResponseWriter, req *http.Request) {
	type jobStatus struct {
		Name     string     `json:"name"`
		Schedule string     `json:"schedule"`
		Enabled  bool       `json:"enabled"`
		NextRun  *time.Time `json:"next_run,omitempty"`
	}

	statuses := make([]jobStatus, 0, len(r.jobs))
	for _, j := range r.jobs {
		s := jobStatus{
			Name:     j.Name,
			Schedule: j.Schedule,
			Enabled:  j.Enabled,
		}
		for id, name := range r.entryNames {
			if name == j.Name {
				entry := r.cron.Entry(id)
				if !entry.Next.IsZero() {
					next := entry.Next
					s.NextRun = &next
				}
				break
			}
		}
		statuses = append(statuses, s)
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(statuses); err != nil {
		r.log.Warn().Err(err).Msg("failed to encode debug jobs response")
	}
}
