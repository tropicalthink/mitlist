package repositories

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/models"
)

// WeeklySummaryRepository aggregates household activity into weekly counts.
type WeeklySummaryRepository struct {
	pool *pgxpool.Pool
}

// NewWeeklySummaryRepository creates a new WeeklySummaryRepository.
func NewWeeklySummaryRepository(pool *pgxpool.Pool) *WeeklySummaryRepository {
	return &WeeklySummaryRepository{pool: pool}
}

// weeklyEventsCTE is the single definition of "household activity". It is the
// same five-source union the activity feed and the weekly digest job use, so
// the summary screen counts the same kinds of events as the notification that
// opened it (the exact totals can still differ, because the digest's window is
// fixed at job time while the screen's rolls with the request).
//
// $1 group, $2 window start (inclusive), $3 window end (exclusive).
//
// Note on recipes: they are user-scoped, not group-scoped (see migration
// 000001), so a recipe is attributed to every household its author belongs to.
// A recipe written by someone in three households counts once in each. That is
// how the activity feed and the digest have always counted it; changing it here
// alone would desync the screen from the push.
const weeklyEventsCTE = `
	WITH events AS (
		SELECT 'lists' AS category, li.created_at AS at, li.added_by AS user_id
		FROM list_items li
		JOIN lists l ON l.id = li.list_id
		WHERE l.group_id = $1 AND li.created_at >= $2 AND li.created_at < $3
		UNION ALL
		SELECT 'expenses', e.created_at, e.payer_id
		FROM expenses e
		WHERE e.group_id = $1 AND e.created_at >= $2 AND e.created_at < $3
		UNION ALL
		SELECT 'chores', cc.completed_at, cc.completed_by
		FROM chore_completions cc
		JOIN chore_assignments ca ON ca.id = cc.assignment_id
		JOIN chores ch ON ch.id = ca.chore_id
		WHERE ch.group_id = $1 AND cc.completed_at >= $2 AND cc.completed_at < $3
		UNION ALL
		SELECT 'meals', mp.created_at, mp.cook_user_id
		FROM meal_plans mp
		WHERE mp.group_id = $1 AND mp.created_at >= $2 AND mp.created_at < $3
		UNION ALL
		SELECT 'recipes', rcp.created_at, rcp.user_id
		FROM recipes rcp
		JOIN group_memberships gm ON gm.user_id = rcp.user_id
		WHERE gm.group_id = $1 AND rcp.created_at >= $2 AND rcp.created_at < $3
	)`

// CountByCategory returns per-category counts for the current week
// [currentStart, end) and the preceding week [start, currentStart), along with
// the requesting user's own share of each.
//
// Categories with no activity in either week are absent from the result; the
// service fills them in so the client always receives the full set.
func (r *WeeklySummaryRepository) CountByCategory(
	ctx context.Context, groupID, userID uuid.UUID, start, currentStart, end time.Time,
) ([]models.WeeklyCategoryCount, error) {
	query := weeklyEventsCTE + `
		SELECT category,
			COUNT(*) FILTER (WHERE at >= $4)                    AS current_count,
			COUNT(*) FILTER (WHERE at <  $4)                    AS previous_count,
			COUNT(*) FILTER (WHERE at >= $4 AND user_id = $5)   AS current_mine
		FROM events
		GROUP BY category
	`
	rows, err := r.pool.Query(ctx, query, groupID, start, end, currentStart, userID)
	if err != nil {
		return nil, fmt.Errorf("query weekly categories: %w", err)
	}
	defer rows.Close()

	var out []models.WeeklyCategoryCount
	for rows.Next() {
		var c models.WeeklyCategoryCount
		if err := rows.Scan(&c.Category, &c.Count, &c.Previous, &c.Mine); err != nil {
			return nil, fmt.Errorf("scan weekly category: %w", err)
		}
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("weekly category rows: %w", err)
	}
	return out, nil
}

// CountMine returns the requesting user's own totals for the current and
// previous week. Kept separate from CountByCategory because meal plans carry a
// nullable cook_user_id: an unassigned meal has no actor, so per-category
// "mine" sums do not necessarily reconcile with a household total.
func (r *WeeklySummaryRepository) CountMine(
	ctx context.Context, groupID, userID uuid.UUID, start, currentStart, end time.Time,
) (current int, previous int, err error) {
	query := weeklyEventsCTE + `
		SELECT
			COUNT(*) FILTER (WHERE at >= $4 AND user_id = $5),
			COUNT(*) FILTER (WHERE at <  $4 AND user_id = $5)
		FROM events
	`
	err = r.pool.QueryRow(ctx, query, groupID, start, end, currentStart, userID).
		Scan(&current, &previous)
	if err != nil {
		return 0, 0, fmt.Errorf("query weekly own totals: %w", err)
	}
	return current, previous, nil
}

// CountByDay returns one row per day that had activity in [currentStart, end),
// bucketed against the caller's own clock so the sparkline lines up with the
// household's calendar rather than UTC. The service pads missing days.
//
// offsetMinutes is a fixed UTC offset rather than an IANA zone: the app has no
// timezone database and `DateTime.timeZoneOffset` is the only zone information
// available to it without a new dependency. The cost is that a DST transition
// inside the reported week shifts one day boundary by an hour, which is not
// worth a tzdata dependency to avoid on a seven-bar sparkline.
func (r *WeeklySummaryRepository) CountByDay(
	ctx context.Context, groupID uuid.UUID, currentStart, end time.Time, offsetMinutes int,
) ([]models.WeeklyDayCount, error) {
	// AT TIME ZONE 'UTC' first: date_trunc/::date on a bare TIMESTAMPTZ would
	// bucket in the Postgres session's TimeZone, so a self-hosted instance
	// with a non-UTC server default would shift days regardless of tz_offset.
	query := weeklyEventsCTE + `
		SELECT ((at AT TIME ZONE 'UTC') + make_interval(mins => $4))::date AS day, COUNT(*)
		FROM events
		GROUP BY day
		ORDER BY day
	`
	rows, err := r.pool.Query(ctx, query, groupID, currentStart, end, offsetMinutes)
	if err != nil {
		return nil, fmt.Errorf("query weekly days: %w", err)
	}
	defer rows.Close()

	var out []models.WeeklyDayCount
	for rows.Next() {
		var d models.WeeklyDayCount
		if err := rows.Scan(&d.Date, &d.Count); err != nil {
			return nil, fmt.Errorf("scan weekly day: %w", err)
		}
		out = append(out, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("weekly day rows: %w", err)
	}
	return out, nil
}

// CountActiveMembers returns how many distinct members are attributed with at
// least one activity in [currentStart, end), and the household size. Rows with
// a NULL actor (an unassigned meal plan) are excluded from the active count.
func (r *WeeklySummaryRepository) CountActiveMembers(
	ctx context.Context, groupID uuid.UUID, currentStart, end time.Time,
) (active int, total int, err error) {
	query := weeklyEventsCTE + `
		SELECT
			(SELECT COUNT(DISTINCT user_id) FROM events WHERE user_id IS NOT NULL),
			(SELECT COUNT(*) FROM group_memberships WHERE group_id = $1)
	`
	err = r.pool.QueryRow(ctx, query, groupID, currentStart, end).Scan(&active, &total)
	if err != nil {
		return 0, 0, fmt.Errorf("query weekly active members: %w", err)
	}
	return active, total, nil
}
