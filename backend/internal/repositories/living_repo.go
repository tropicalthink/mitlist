package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/models"
)

var (
	ErrLivingThingNotFound = errors.New("living thing not found")
	ErrCareScheduleNotFound = errors.New("care schedule not found")
	ErrCareLogNotFound      = errors.New("care log not found")
	ErrSpeciesWikiNotFound  = errors.New("species wiki not found")
)

// LivingRepository provides data access for living things, care schedules,
// care logs, and species wiki entries.
type LivingRepository struct {
	pool DBTX
}

// NewLivingRepository creates a new LivingRepository.
func NewLivingRepository(pool DBTX) *LivingRepository {
	return &LivingRepository{pool: pool}
}

// ---------------------------------------------------------------------------
// LivingThing
// ---------------------------------------------------------------------------

// CreateLivingThing inserts a new living thing and returns the created record.
func (r *LivingRepository) CreateLivingThing(ctx context.Context, lt *models.LivingThing) (*models.LivingThing, error) {
	query := `
		INSERT INTO living_things (id, group_id, name, species, location, image_url, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, group_id, name, species, location, image_url, created_at, updated_at
	`

	now := time.Now().UTC()
	lt.ID = uuid.New()
	lt.CreatedAt = now
	lt.UpdatedAt = now

	row := r.pool.QueryRow(ctx, query,
		lt.ID, lt.GroupID, lt.Name, lt.Species, lt.Location, lt.ImageURL, lt.CreatedAt, lt.UpdatedAt,
	)

	var created models.LivingThing
	if err := row.Scan(&created.ID, &created.GroupID, &created.Name, &created.Species, &created.Location, &created.ImageURL, &created.CreatedAt, &created.UpdatedAt); err != nil {
		return nil, fmt.Errorf("create living thing: %w", err)
	}
	return &created, nil
}

// GetLivingThingByID retrieves a living thing by its ID.
func (r *LivingRepository) GetLivingThingByID(ctx context.Context, id uuid.UUID) (*models.LivingThing, error) {
	query := `
		SELECT id, group_id, name, species, location, image_url, created_at, updated_at
		FROM living_things
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var lt models.LivingThing
	if err := row.Scan(&lt.ID, &lt.GroupID, &lt.Name, &lt.Species, &lt.Location, &lt.ImageURL, &lt.CreatedAt, &lt.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrLivingThingNotFound
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	return &lt, nil
}

// ListLivingThingsByGroup returns paginated living things belonging to a group.
func (r *LivingRepository) ListLivingThingsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.LivingThing, error) {
	limit = clampLimit(limit)
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, group_id, name, species, location, image_url, created_at, updated_at
		FROM living_things
		WHERE group_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, groupID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list living things: %w", err)
	}
	defer rows.Close()

	return scanLivingThings(rows)
}

// UpdateLivingThing updates an existing living thing.
func (r *LivingRepository) UpdateLivingThing(ctx context.Context, lt *models.LivingThing) (*models.LivingThing, error) {
	query := `
		UPDATE living_things
		SET name = $1, species = $2, location = $3, image_url = $4, updated_at = $5
		WHERE id = $6
		RETURNING id, group_id, name, species, location, image_url, created_at, updated_at
	`

	lt.UpdatedAt = time.Now().UTC()

	row := r.pool.QueryRow(ctx, query,
		lt.Name, lt.Species, lt.Location, lt.ImageURL, lt.UpdatedAt, lt.ID,
	)

	var updated models.LivingThing
	if err := row.Scan(&updated.ID, &updated.GroupID, &updated.Name, &updated.Species, &updated.Location, &updated.ImageURL, &updated.CreatedAt, &updated.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrLivingThingNotFound
		}
		return nil, fmt.Errorf("update living thing: %w", err)
	}
	return &updated, nil
}

// DeleteLivingThing hard-deletes a living thing by ID.
func (r *LivingRepository) DeleteLivingThing(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM living_things WHERE id = $1`

	cmd, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("delete living thing: %w", err)
	}
	if cmd.RowsAffected() == 0 {
		return ErrLivingThingNotFound
	}
	return nil
}

// ---------------------------------------------------------------------------
// CareSchedule
// ---------------------------------------------------------------------------

// CreateCareSchedule inserts a new care schedule.
func (r *LivingRepository) CreateCareSchedule(ctx context.Context, cs *models.CareSchedule) (*models.CareSchedule, error) {
	query := `
		INSERT INTO care_schedules (id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at
	`

	now := time.Now().UTC()
	cs.ID = uuid.New()
	cs.CreatedAt = now
	cs.UpdatedAt = now

	row := r.pool.QueryRow(ctx, query,
		cs.ID, cs.LivingThingID, cs.FrequencyValue, cs.FrequencyUnit, cs.NextDue, cs.CreatedAt, cs.UpdatedAt,
	)

	var created models.CareSchedule
	if err := row.Scan(&created.ID, &created.LivingThingID, &created.FrequencyValue, &created.FrequencyUnit, &created.NextDue, &created.CreatedAt, &created.UpdatedAt); err != nil {
		return nil, fmt.Errorf("create care schedule: %w", err)
	}
	return &created, nil
}

// GetCareSchedule retrieves a care schedule by its ID.
func (r *LivingRepository) GetCareSchedule(ctx context.Context, id uuid.UUID) (*models.CareSchedule, error) {
	query := `
		SELECT id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at
		FROM care_schedules
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var cs models.CareSchedule
	if err := row.Scan(&cs.ID, &cs.LivingThingID, &cs.FrequencyValue, &cs.FrequencyUnit, &cs.NextDue, &cs.CreatedAt, &cs.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCareScheduleNotFound
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	return &cs, nil
}

// GetCareScheduleByLivingThingID retrieves a care schedule by living thing ID.
func (r *LivingRepository) GetCareScheduleByLivingThingID(ctx context.Context, livingThingID uuid.UUID) (*models.CareSchedule, error) {
	query := `
		SELECT id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at
		FROM care_schedules
		WHERE living_thing_id = $1
	`

	row := r.pool.QueryRow(ctx, query, livingThingID)

	var cs models.CareSchedule
	if err := row.Scan(&cs.ID, &cs.LivingThingID, &cs.FrequencyValue, &cs.FrequencyUnit, &cs.NextDue, &cs.CreatedAt, &cs.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCareScheduleNotFound
		}
		return nil, fmt.Errorf("get care schedule by living thing: %w", err)
	}
	return &cs, nil
}

// UpdateCareSchedule updates an existing care schedule.
func (r *LivingRepository) UpdateCareSchedule(ctx context.Context, cs *models.CareSchedule) (*models.CareSchedule, error) {
	query := `
		UPDATE care_schedules
		SET frequency_value = $1, frequency_unit = $2, next_due = $3, updated_at = $4
		WHERE id = $5
		RETURNING id, living_thing_id, frequency_value, frequency_unit, next_due, created_at, updated_at
	`

	cs.UpdatedAt = time.Now().UTC()

	row := r.pool.QueryRow(ctx, query,
		cs.FrequencyValue, cs.FrequencyUnit, cs.NextDue, cs.UpdatedAt, cs.ID,
	)

	var updated models.CareSchedule
	if err := row.Scan(&updated.ID, &updated.LivingThingID, &updated.FrequencyValue, &updated.FrequencyUnit, &updated.NextDue, &updated.CreatedAt, &updated.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrCareScheduleNotFound
		}
		return nil, fmt.Errorf("update care schedule: %w", err)
	}
	return &updated, nil
}

// ---------------------------------------------------------------------------
// CareLog
// ---------------------------------------------------------------------------

// CreateCareLog inserts a new care log entry.
func (r *LivingRepository) CreateCareLog(ctx context.Context, cl *models.CareLog) (*models.CareLog, error) {
	query := `
		INSERT INTO care_logs (id, care_schedule_id, user_id, notes, created_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, care_schedule_id, user_id, notes, created_at
	`

	cl.ID = uuid.New()
	cl.CreatedAt = time.Now().UTC()

	row := r.pool.QueryRow(ctx, query,
		cl.ID, cl.CareScheduleID, cl.UserID, cl.Notes, cl.CreatedAt,
	)

	var created models.CareLog
	if err := row.Scan(&created.ID, &created.CareScheduleID, &created.UserID, &created.Notes, &created.CreatedAt); err != nil {
		return nil, fmt.Errorf("create care log: %w", err)
	}
	return &created, nil
}

// ListCareLogs returns paginated care logs for a given care schedule.
func (r *LivingRepository) ListCareLogs(ctx context.Context, careScheduleID uuid.UUID, limit, offset int) ([]models.CareLog, error) {
	limit = clampLimit(limit)
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, care_schedule_id, user_id, notes, created_at
		FROM care_logs
		WHERE care_schedule_id = $1
		ORDER BY created_at DESC, id DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.pool.Query(ctx, query, careScheduleID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list care logs: %w", err)
	}
	defer rows.Close()

	return scanCareLogs(rows)
}

// ---------------------------------------------------------------------------
// SpeciesWiki
// ---------------------------------------------------------------------------

// CreateSpeciesWiki inserts a new species wiki entry.
func (r *LivingRepository) CreateSpeciesWiki(ctx context.Context, sw *models.SpeciesWiki) (*models.SpeciesWiki, error) {
	query := `
		INSERT INTO species_wikis (id, common_name, scientific_name, care_instructions, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, common_name, scientific_name, care_instructions, created_at, updated_at
	`

	now := time.Now().UTC()
	sw.ID = uuid.New()
	sw.CreatedAt = now
	sw.UpdatedAt = now

	row := r.pool.QueryRow(ctx, query,
		sw.ID, sw.CommonName, sw.ScientificName, sw.CareInstructions, sw.CreatedAt, sw.UpdatedAt,
	)

	var created models.SpeciesWiki
	if err := row.Scan(&created.ID, &created.CommonName, &created.ScientificName, &created.CareInstructions, &created.CreatedAt, &created.UpdatedAt); err != nil {
		return nil, fmt.Errorf("create species wiki: %w", err)
	}
	return &created, nil
}

// GetSpeciesWiki retrieves a species wiki entry by its ID.
func (r *LivingRepository) GetSpeciesWiki(ctx context.Context, id uuid.UUID) (*models.SpeciesWiki, error) {
	query := `
		SELECT id, common_name, scientific_name, care_instructions, created_at, updated_at
		FROM species_wikis
		WHERE id = $1
	`

	row := r.pool.QueryRow(ctx, query, id)

	var sw models.SpeciesWiki
	if err := row.Scan(&sw.ID, &sw.CommonName, &sw.ScientificName, &sw.CareInstructions, &sw.CreatedAt, &sw.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSpeciesWikiNotFound
		}
		return nil, fmt.Errorf("get species wiki: %w", err)
	}
	return &sw, nil
}

// ---------------------------------------------------------------------------
// Scanners
// ---------------------------------------------------------------------------

func scanLivingThings(rows pgx.Rows) ([]models.LivingThing, error) {
	var items []models.LivingThing
	for rows.Next() {
		var lt models.LivingThing
		if err := rows.Scan(&lt.ID, &lt.GroupID, &lt.Name, &lt.Species, &lt.Location, &lt.ImageURL, &lt.CreatedAt, &lt.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan living thing: %w", err)
		}
		items = append(items, lt)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate living things: %w", err)
	}
	return items, nil
}

func scanCareLogs(rows pgx.Rows) ([]models.CareLog, error) {
	var items []models.CareLog
	for rows.Next() {
		var cl models.CareLog
		if err := rows.Scan(&cl.ID, &cl.CareScheduleID, &cl.UserID, &cl.Notes, &cl.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan care log: %w", err)
		}
		items = append(items, cl)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate care logs: %w", err)
	}
	return items, nil
}
