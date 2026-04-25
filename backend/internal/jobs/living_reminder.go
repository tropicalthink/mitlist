package jobs

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/pkg/logger"
)

// LivingReminder queries care schedules that are due and sends push
// notifications. Run hourly.
type LivingReminder struct {
	repo livingReminderRepo
	push Pusher
	log  *logger.Logger
}

// NewLivingReminder creates a new LivingReminder.
func NewLivingReminder(pool *pgxpool.Pool, push Pusher, log *logger.Logger) *LivingReminder {
	return &LivingReminder{repo: &livingReminderRepoImpl{pool: pool}, push: push, log: log}
}

func newLivingReminder(repo livingReminderRepo, push Pusher, log *logger.Logger) *LivingReminder {
	return &LivingReminder{repo: repo, push: push, log: log}
}

type livingPushPayload struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

// Run executes the living reminder job.
func (r *LivingReminder) Run() {
	ctx := context.Background()
	r.log.Info().Msg("living reminder job started")

	schedules, err := r.repo.ListDueCareSchedules(ctx)
	if err != nil {
		r.log.Error().Err(err).Msg("failed to list due care schedules")
		return
	}

	for _, cs := range schedules {
		if err := r.processSchedule(ctx, cs); err != nil {
			r.log.Error().Err(err).Str("schedule_id", cs.ID.String()).Msg("failed to process care schedule")
		}
	}
}

func (r *LivingReminder) processSchedule(ctx context.Context, cs models.CareSchedule) error {
	ltName, groupID, err := r.repo.GetLivingThingNameAndGroupID(ctx, cs.LivingThingID)
	if err != nil {
		return fmt.Errorf("get living thing: %w", err)
	}

	livingPushPayload := livingPushPayload{Title: "Care Reminder", Body: "Time to care for " + ltName}
	data, _ := json.Marshal(livingPushPayload)
	pushErr := r.push.BroadcastToGroup(groupID, string(data))
	if pushErr != nil {
		r.log.Warn().Err(pushErr).Str("schedule_id", cs.ID.String()).Msg("failed to send living reminder push")
	} else {
		r.log.Info().Str("schedule_id", cs.ID.String()).Msg("living reminder sent")
	}

	nextDue := advanceNextDue(cs.NextDue, cs.FrequencyValue, cs.FrequencyUnit)
	if err := r.repo.UpdateCareScheduleNextDue(ctx, cs.ID, nextDue); err != nil {
		return fmt.Errorf("update care schedule: %w", err)
	}

	r.log.Info().
		Str("schedule_id", cs.ID.String()).
		Time("next_due", nextDue).
		Bool("push_sent", pushErr == nil).
		Msg("care schedule processed")
	return nil
}

func advanceNextDue(current time.Time, value int, unit string) time.Time {
	switch unit {
	case "hours":
		return current.Add(time.Duration(value) * time.Hour)
	case "days":
		return current.AddDate(0, 0, value)
	case "weeks":
		return current.AddDate(0, 0, value*7)
	case "months":
		return current.AddDate(0, value, 0)
	default:
		return current.AddDate(0, 0, value)
	}
}

type livingReminderRepoImpl struct {
	pool *pgxpool.Pool
}

func (r *livingReminderRepoImpl) ListDueCareSchedules(ctx context.Context) ([]models.CareSchedule, error) {
	query := `
		SELECT id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at
		FROM care_schedules
		WHERE next_due <= NOW()
	`
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query due care schedules: %w", err)
	}
	defer rows.Close()

	var schedules []models.CareSchedule
	for rows.Next() {
		var s models.CareSchedule
		if err := rows.Scan(
			&s.ID, &s.LivingThingID, &s.FrequencyValue, &s.FrequencyUnit,
			&s.NextDue, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan care schedule: %w", err)
		}
		schedules = append(schedules, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}
	return schedules, nil
}

func (r *livingReminderRepoImpl) GetLivingThingNameAndGroupID(ctx context.Context, id uuid.UUID) (string, uuid.UUID, error) {
	var ltName string
	var groupID uuid.UUID
	err := r.pool.QueryRow(ctx, `
		SELECT name, group_id FROM living_things WHERE id = $1
	`, id).Scan(&ltName, &groupID)
	if err != nil {
		return "", uuid.Nil, err
	}
	return ltName, groupID, nil
}

func (r *livingReminderRepoImpl) UpdateCareScheduleNextDue(ctx context.Context, id uuid.UUID, nextDue time.Time) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE care_schedules
		SET next_due = $1, updated_at = NOW()
		WHERE id = $2
	`, nextDue, id)
	if err != nil {
		return fmt.Errorf("update care schedule: %w", err)
	}
	return nil
}
