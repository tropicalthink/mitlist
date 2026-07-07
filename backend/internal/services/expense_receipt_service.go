package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
)

type ExpenseReceiptService struct {
	financeRepo   repositories.FinanceRepoIface
	groupRepo     repositories.GroupRepo
	attachRepo    repositories.AttachmentRepo
	expAttachRepo *repositories.ExpenseAttachmentRepository
	storage       *storagesvc.Service
}

func NewExpenseReceiptService(
	financeRepo repositories.FinanceRepoIface,
	groupRepo repositories.GroupRepo,
	attachRepo repositories.AttachmentRepo,
	expAttachRepo *repositories.ExpenseAttachmentRepository,
	storage *storagesvc.Service,
) *ExpenseReceiptService {
	return &ExpenseReceiptService{
		financeRepo:   financeRepo,
		groupRepo:     groupRepo,
		attachRepo:    attachRepo,
		expAttachRepo: expAttachRepo,
		storage:       storage,
	}
}

type ExpenseReceipt struct {
	AttachmentID string `json:"attachment_id"`
	ContentType  string `json:"content_type"`
	ByteSize     int64  `json:"byte_size"`
	CreatedAt    string `json:"created_at"`
	URL          string `json:"url"`
}

func (s *ExpenseReceiptService) requireMember(ctx context.Context, groupID, userID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *ExpenseReceiptService) Attach(ctx context.Context, userID, groupID, expenseID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if expense.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "expense does not belong to this group"}
	}

	att, err := s.attachRepo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	if att.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}
	if att.Status != models.AttachmentStatusReady {
		return &api.ValidationError{Message: "attachment not ready"}
	}

	return s.expAttachRepo.Add(ctx, expenseID, attachmentID)
}

func (s *ExpenseReceiptService) List(ctx context.Context, userID, groupID, expenseID uuid.UUID) ([]ExpenseReceipt, error) {
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if expense.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "expense does not belong to this group"}
	}

	atts, err := s.expAttachRepo.ListReadyAttachmentsByExpense(ctx, expenseID)
	if err != nil {
		return nil, err
	}

	out := make([]ExpenseReceipt, 0, len(atts))
	for _, a := range atts {
		if a.GroupID != groupID {
			continue
		}
		url := s.storage.GetURL(a.ObjectKey)
		if url == "" {
			return nil, fmt.Errorf("failed to presign receipt url")
		}
		out = append(out, ExpenseReceipt{
			AttachmentID: a.ID.String(),
			ContentType:  a.ContentType,
			ByteSize:     a.ByteSize,
			CreatedAt:    a.CreatedAt.Format(time.RFC3339),
			URL:          url,
		})
	}
	return out, nil
}

func (s *ExpenseReceiptService) Detach(ctx context.Context, userID, groupID, expenseID, attachmentID uuid.UUID) error {
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if expense.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "expense does not belong to this group"}
	}

	if err := s.expAttachRepo.Remove(ctx, expenseID, attachmentID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "expense attachment", ID: attachmentID.String()}
		}
		return err
	}
	return nil
}
