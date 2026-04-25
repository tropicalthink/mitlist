package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// LivingService provides business logic for living things.
type LivingService struct {
	livingRepo repositories.LivingRepo
	groupRepo  repositories.GroupRepo
}

// NewLivingService creates a new LivingService.
func NewLivingService(
	livingRepo repositories.LivingRepo,
	groupRepo repositories.GroupRepo,
) *LivingService {
	return &LivingService{
		livingRepo: livingRepo,
		groupRepo:  groupRepo,
	}
}

func (s *LivingService) requireGroupMember(ctx context.Context, groupID, userID uuid.UUID) error {
	_, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &api.PermissionDeniedError{Action: "access group"}
		}
		return fmt.Errorf("check membership: %w", err)
	}
	return nil
}

// CreateLivingThing creates a new living thing.
func (s *LivingService) CreateLivingThing(ctx context.Context, userID uuid.UUID, lt *models.LivingThing) (*models.LivingThing, error) {
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	return s.livingRepo.CreateLivingThing(ctx, lt)
}

// GetLivingThing retrieves a living thing by ID.
func (s *LivingService) GetLivingThing(ctx context.Context, userID, ltID uuid.UUID) (*models.LivingThing, error) {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, ltID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: ltID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	return lt, nil
}

// ListLivingThings lists living things for a group.
func (s *LivingService) ListLivingThings(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.LivingThing, error) {
	if err := s.requireGroupMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.livingRepo.ListLivingThingsByGroup(ctx, groupID, limit, offset)
}

// UpdateLivingThing updates a living thing.
func (s *LivingService) UpdateLivingThing(ctx context.Context, userID uuid.UUID, lt *models.LivingThing) (*models.LivingThing, error) {
	existing, err := s.livingRepo.GetLivingThingByID(ctx, lt.ID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: lt.ID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, existing.GroupID, userID); err != nil {
		return nil, err
	}
	// Prevent changing the group.
	lt.GroupID = existing.GroupID
	return s.livingRepo.UpdateLivingThing(ctx, lt)
}

// DeleteLivingThing deletes a living thing.
func (s *LivingService) DeleteLivingThing(ctx context.Context, userID, ltID uuid.UUID) error {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, ltID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return &api.NotFoundError{Resource: "living thing", ID: ltID.String()}
		}
		return fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return err
	}
	return s.livingRepo.DeleteLivingThing(ctx, ltID)
}

// CreateCareSchedule creates a care schedule for a living thing.
func (s *LivingService) CreateCareSchedule(ctx context.Context, userID uuid.UUID, cs *models.CareSchedule) (*models.CareSchedule, error) {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, cs.LivingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: cs.LivingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	return s.livingRepo.CreateCareSchedule(ctx, cs)
}

// GetCareSchedule retrieves a care schedule by ID.
func (s *LivingService) GetCareSchedule(ctx context.Context, userID, csID uuid.UUID) (*models.CareSchedule, error) {
	cs, err := s.livingRepo.GetCareSchedule(ctx, csID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule", ID: csID.String()}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	lt, err := s.livingRepo.GetLivingThingByID(ctx, cs.LivingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: cs.LivingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	return cs, nil
}

// UpdateCareSchedule updates a care schedule.
func (s *LivingService) UpdateCareSchedule(ctx context.Context, userID uuid.UUID, cs *models.CareSchedule) (*models.CareSchedule, error) {
	existing, err := s.livingRepo.GetCareSchedule(ctx, cs.ID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule", ID: cs.ID.String()}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	lt, err := s.livingRepo.GetLivingThingByID(ctx, existing.LivingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: existing.LivingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	// Prevent changing the living thing.
	cs.LivingThingID = existing.LivingThingID
	return s.livingRepo.UpdateCareSchedule(ctx, cs)
}

// GetCareScheduleByLivingThing retrieves the care schedule for a living thing.
func (s *LivingService) GetCareScheduleByLivingThing(ctx context.Context, userID, livingThingID uuid.UUID) (*models.CareSchedule, error) {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: livingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	cs, err := s.livingRepo.GetCareScheduleByLivingThingID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule"}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	return cs, nil
}

// UpdateCareScheduleByLivingThing updates the care schedule for a living thing.
func (s *LivingService) UpdateCareScheduleByLivingThing(ctx context.Context, userID, livingThingID uuid.UUID, cs *models.CareSchedule) (*models.CareSchedule, error) {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: livingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	existing, err := s.livingRepo.GetCareScheduleByLivingThingID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule"}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	cs.ID = existing.ID
	cs.LivingThingID = existing.LivingThingID
	return s.livingRepo.UpdateCareSchedule(ctx, cs)
}

// ListCareLogsByLivingThing lists care logs for a living thing's care schedule.
func (s *LivingService) ListCareLogsByLivingThing(ctx context.Context, userID, livingThingID uuid.UUID, limit, offset int) ([]models.CareLog, error) {
	lt, err := s.livingRepo.GetLivingThingByID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: livingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	cs, err := s.livingRepo.GetCareScheduleByLivingThingID(ctx, livingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule"}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	return s.livingRepo.ListCareLogs(ctx, cs.ID, limit, offset)
}

// LogCare logs care for a schedule.
func (s *LivingService) LogCare(ctx context.Context, userID uuid.UUID, cl *models.CareLog) (*models.CareLog, error) {
	cs, err := s.livingRepo.GetCareSchedule(ctx, cl.CareScheduleID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule", ID: cl.CareScheduleID.String()}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	lt, err := s.livingRepo.GetLivingThingByID(ctx, cs.LivingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: cs.LivingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	if cl.UserID == uuid.Nil {
		cl.UserID = userID
	}
	return s.livingRepo.CreateCareLog(ctx, cl)
}

// ListCareLogs lists care logs for a schedule.
func (s *LivingService) ListCareLogs(ctx context.Context, userID, scheduleID uuid.UUID, limit, offset int) ([]models.CareLog, error) {
	cs, err := s.livingRepo.GetCareSchedule(ctx, scheduleID)
	if err != nil {
		if errors.Is(err, repositories.ErrCareScheduleNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "care schedule", ID: scheduleID.String()}
		}
		return nil, fmt.Errorf("get care schedule: %w", err)
	}
	lt, err := s.livingRepo.GetLivingThingByID(ctx, cs.LivingThingID)
	if err != nil {
		if errors.Is(err, repositories.ErrLivingThingNotFound) || errors.Is(err, pgx.ErrNoRows) {
			return nil, &api.NotFoundError{Resource: "living thing", ID: cs.LivingThingID.String()}
		}
		return nil, fmt.Errorf("get living thing: %w", err)
	}
	if err := s.requireGroupMember(ctx, lt.GroupID, userID); err != nil {
		return nil, err
	}
	return s.livingRepo.ListCareLogs(ctx, scheduleID, limit, offset)
}
