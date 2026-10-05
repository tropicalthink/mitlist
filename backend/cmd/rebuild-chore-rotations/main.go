// Command rebuild-chore-rotations is a one-off repair for plans/048 stage 1.
// Until that stage, joining or leaving a household never touched existing
// chore rotations, so a chore created before someone joined still rotates
// among the original members (and one created before someone left still
// hands them turns). It runs the same rebuild the API now runs after every
// membership change over every household that has chores. It is idempotent:
// a second run changes nothing.
//
//	DATABASE_URL=... rebuild-chore-rotations -dry-run   # log what would change
//	DATABASE_URL=... rebuild-chore-rotations            # write it
package main

import (
	"context"
	"flag"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
)

func main() {
	_ = godotenv.Load()

	dryRun := flag.Bool("dry-run", false, "log the rotations that would change without writing them")
	flag.Parse()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal().Msg("DATABASE_URL environment variable is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to database")
	}
	defer pool.Close()

	groupIDs, err := groupsWithRotations(ctx, pool)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to list households with chore rotations")
	}

	choreRepo := &recordingChoreRepo{ChoreRepo: repositories.NewChoreRepository(pool), dryRun: *dryRun}
	chores := services.NewChoreService(choreRepo, repositories.NewGroupRepository(pool), nil)

	failed := 0
	for _, groupID := range groupIDs {
		if err := chores.RebuildMemberOrdersForGroup(ctx, groupID); err != nil {
			failed++
			log.Error().Err(err).Str("group_id", groupID.String()).Msg("rebuild failed")
		}
	}

	log.Info().
		Bool("dry_run", *dryRun).
		Int("households", len(groupIDs)).
		Int("rotations_changed", choreRepo.changed).
		Int("households_failed", failed).
		Msg("chore rotation rebuild finished")
	if failed > 0 {
		os.Exit(1)
	}
}

// groupsWithRotations lists every household that has at least one chore
// rotation to rebuild.
func groupsWithRotations(ctx context.Context, db repositories.DBTX) ([]uuid.UUID, error) {
	rows, err := db.Query(ctx, `
		SELECT DISTINCT c.group_id
		FROM chores c
		JOIN chore_rotation_states s ON s.chore_id = c.id
		ORDER BY c.group_id
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// recordingChoreRepo logs and counts every rotation the rebuild rewrites and,
// in a dry run, stops there instead of writing.
type recordingChoreRepo struct {
	repositories.ChoreRepo
	dryRun  bool
	changed int
}

func (r *recordingChoreRepo) BulkUpdateRotationStates(ctx context.Context, states []models.ChoreRotationState) error {
	r.changed += len(states)
	for _, s := range states {
		log.Info().
			Bool("dry_run", r.dryRun).
			Str("chore_id", s.ChoreID.String()).
			Interface("member_order", s.MemberOrder).
			Int("current_index", s.CurrentIndex).
			Msg("rotation rebuilt")
	}
	if r.dryRun {
		return nil
	}
	return r.ChoreRepo.BulkUpdateRotationStates(ctx, states)
}
