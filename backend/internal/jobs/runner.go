package jobs

import (
	"context"
	"encoding/json"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/robfig/cron/v3"
)

// Runner manages all background jobs using robfig/cron/v3.
type Runner struct {
	cron       *cron.Cron
	db         repositories.DBTX
	push       Pusher
	dispatcher NotificationDispatcher
	log        *logger.Logger
	jobs       []jobMeta
	entryNames map[cron.EntryID]string
	sentryOn   bool
}

// EnableSentryMonitoring turns on GlitchTip cron check-ins and panic capture for
// scheduled jobs. Call before Start. It is a no-op unless Sentry is initialized.
func (r *Runner) EnableSentryMonitoring(on bool) { r.sentryOn = on }

type jobMeta struct {
	Name     string    `json:"name"`
	Schedule string    `json:"schedule"`
	Enabled  bool      `json:"enabled"`
	NextRun  time.Time `json:"next_run,omitempty"`
}

// NewRunner creates a new job runner.
func NewRunner(db repositories.DBTX, pushSvc Pusher, log *logger.Logger) *Runner {
	return &Runner{
		cron:       cron.New(cron.WithChain(cron.SkipIfStillRunning(nil), cron.Recover(cron.DefaultLogger))),
		db:         db,
		push:       pushSvc,
		log:        log,
		entryNames: make(map[cron.EntryID]string),
	}
}

// NewRunnerWithDispatcher creates a Runner that routes notifications through the dispatcher.
func NewRunnerWithDispatcher(db repositories.DBTX, dispatcher NotificationDispatcher, log *logger.Logger) *Runner {
	return &Runner{
		cron:       cron.New(cron.WithChain(cron.SkipIfStillRunning(nil), cron.Recover(cron.DefaultLogger))),
		db:         db,
		dispatcher: dispatcher,
		log:        log,
		entryNames: make(map[cron.EntryID]string),
	}
}

// RegisterAll registers all background jobs with their schedules.
func (r *Runner) RegisterAll() {
	// T82: Chore scheduler — daily at 00:01
	cs := NewChoreScheduler(r.db, r.log)
	r.register("chore-scheduler", "1 0 * * *", cs.Run, true)

	// T84: Recurring expense — hourly
	var re *RecurringExpenseJob
	if r.dispatcher != nil {
		re = NewRecurringExpenseJobWithDispatcher(r.db, r.dispatcher, r.log)
	} else {
		re = NewRecurringExpenseJob(r.db, r.push, r.log)
	}
	r.register("recurring-expense", "0 * * * *", re.Run, true)

	// T86: Chore reminder — daily at 09:00
	var cr *ChoreReminder
	if r.dispatcher != nil {
		cr = NewChoreReminderWithDispatcher(r.db, r.dispatcher, r.log)
	} else {
		cr = NewChoreReminder(r.db, r.push, r.log)
	}
	r.register("chore-reminder", "0 9 * * *", cr.Run, true)

	// T87: Weekly summary — disabled by default (Monday 09:00)
	var ws *WeeklySummary
	if r.dispatcher != nil {
		ws = NewWeeklySummaryWithDispatcher(r.db, r.dispatcher, r.log)
	} else {
		ws = NewWeeklySummary(r.db, r.push, r.log)
	}
	r.register("weekly-summary", "0 9 * * 1", ws.Run, true)

	// Pinwall reminders — every minute
	var pr *PinwallReminder
	if r.dispatcher != nil {
		pr = NewPinwallReminderWithDispatcher(r.db, r.dispatcher, r.log)
	} else {
		pr = NewPinwallReminder(r.db, r.push, r.log)
	}
	r.register("pinwall-reminder", "* * * * *", pr.Run, true)
}

// RegisterAttachmentCleanup adds the storage reservation sweeper. It is kept
// separate from RegisterAll because it depends on the configured object store.
func (r *Runner) RegisterAttachmentCleanup(fn func()) {
	if fn == nil {
		return
	}
	r.register("attachment-cleanup", "*/15 * * * *", fn, true)
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

	id, err := r.cron.AddFunc(spec, r.wrapJob(name, spec, fn))
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

// wrapJob adds structured start/finish logging, panic capture, and (when Sentry
// monitoring is enabled) GlitchTip cron check-ins around a job's run function.
// A panic is captured and logged but not re-thrown, so one job failing never
// takes down the scheduler.
func (r *Runner) wrapJob(name, spec string, fn func()) func() {
	monitorConfig := &sentry.MonitorConfig{Schedule: sentry.CrontabSchedule(spec)}

	return func() {
		hub := sentry.CurrentHub().Clone()
		hub.Scope().SetTag("job", name)
		ctx := sentry.SetHubOnContext(context.Background(), hub)

		var checkInID *sentry.EventID
		if r.sentryOn {
			checkInID = hub.CaptureCheckIn(&sentry.CheckIn{
				MonitorSlug: name,
				Status:      sentry.CheckInStatusInProgress,
			}, monitorConfig)
		}

		start := time.Now()
		r.log.Info().Str("job", name).Time("start", start).Msg("job started")

		status := sentry.CheckInStatusOK
		func() {
			defer func() {
				if rec := recover(); rec != nil {
					status = sentry.CheckInStatusError
					hub.RecoverWithContext(ctx, rec)
					r.log.Error().
						// Already captured via hub.RecoverWithContext above.
						Bool(logger.SentrySkipField, true).
						Str("job", name).
						Interface("panic", rec).
						Str("stack", string(debug.Stack())).
						Msg("job panic recovered")
				}
			}()
			fn()
		}()

		duration := time.Since(start)
		if r.sentryOn && checkInID != nil {
			hub.CaptureCheckIn(&sentry.CheckIn{
				ID:          *checkInID,
				MonitorSlug: name,
				Status:      status,
				Duration:    duration,
			}, monitorConfig)
		}
		r.log.Info().Str("job", name).Dur("duration", duration).Msg("job finished")
	}
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
