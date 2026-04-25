package services

import (
	"context"
	"errors"
	"sort"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/yourorg/mitlist/internal/api"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
)

// FinanceService implements business logic for expenses, splits, settlements
// and recurring expenses with permission checks and known bug fixes.
type FinanceService struct {
	financeRepo repositories.FinanceRepoIface
	groupRepo   repositories.GroupRepo
}

// NewFinanceService creates a new FinanceService.
func NewFinanceService(financeRepo repositories.FinanceRepoIface, groupRepo repositories.GroupRepo) *FinanceService {
	return &FinanceService{
		financeRepo: financeRepo,
		groupRepo:   groupRepo,
	}
}

func (s *FinanceService) requireMember(ctx context.Context, groupID, userID uuid.UUID) error {
	m, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrPermissionDenied
		}
		return err
	}
	if m.Role != "admin" && m.Role != "member" {
		return api.ErrPermissionDenied
	}
	return nil
}

func (s *FinanceService) requireAdmin(ctx context.Context, groupID, userID uuid.UUID) error {
	m, err := s.groupRepo.GetMembership(ctx, groupID, userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrPermissionDenied
		}
		return err
	}
	if m.Role != "admin" {
		return api.ErrPermissionDenied
	}
	return nil
}

// ------------------------------------------------------------------
// Expenses
// ------------------------------------------------------------------

// CreateExpense creates an expense and optionally generates equal splits.
// It fixes the ZERO-SUM bug by auto-settling the payer's split and the
// EQUAL split bug with deterministic penny distribution by user_id ASC.
func (s *FinanceService) CreateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense, splitUserIDs []uuid.UUID) error {
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	if expense.Amount <= 0 {
		return api.ErrValidation
	}
	if expense.Currency == "" {
		return api.ErrValidation
	}

	var splits []models.Split
	if len(splitUserIDs) > 0 {
		sorted := make([]uuid.UUID, len(splitUserIDs))
		copy(sorted, splitUserIDs)
		sort.Slice(sorted, func(i, j int) bool {
			return sorted[i].String() < sorted[j].String()
		})

		n := int64(len(sorted))
		base := expense.Amount / n
		rem := expense.Amount % n

		splits = make([]models.Split, 0, len(sorted))
		for i, uid := range sorted {
			amount := base
			if int64(i) < rem {
				amount++
			}
			s := models.Split{
				UserID: uid,
				Amount: amount,
			}
			if uid == expense.PayerID {
				s.IsSettled = true // ZERO-SUM fix
			}
			splits = append(splits, s)
		}
	}

	return s.financeRepo.CreateExpenseWithSplits(ctx, expense, splits)
}

// GetExpense returns an expense by ID.
func (s *FinanceService) GetExpense(ctx context.Context, userID, expenseID uuid.UUID) (*models.Expense, error) {
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if err.Error() == "expense not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return nil, err
	}
	return expense, nil
}

// ListExpenses returns paginated expenses for a group.
func (s *FinanceService) ListExpenses(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.Expense, error) {
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.financeRepo.ListExpensesByGroup(ctx, groupID, limit, offset)
}

// UpdateExpense updates an existing expense.
func (s *FinanceService) UpdateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense) error {
	existing, err := s.financeRepo.GetExpenseByID(ctx, expense.ID)
	if err != nil {
		if err.Error() == "expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	expense.GroupID = existing.GroupID
	return s.financeRepo.UpdateExpense(ctx, expense)
}

// DeleteExpense removes an expense (admin only).
func (s *FinanceService) DeleteExpense(ctx context.Context, userID, expenseID uuid.UUID) error {
	existing, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if err.Error() == "expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireAdmin(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	return s.financeRepo.DeleteExpense(ctx, expenseID)
}

// ------------------------------------------------------------------
// Splits
// ------------------------------------------------------------------

// GetSplit retrieves a split by ID.
func (s *FinanceService) GetSplit(ctx context.Context, userID uuid.UUID, splitID uuid.UUID) (*models.Split, error) {
	split, err := s.financeRepo.GetSplitByID(ctx, splitID)
	if err != nil {
		if err.Error() == "split not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, split.ExpenseID)
	if err != nil {
		return nil, err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return nil, err
	}
	return split, nil
}

// CreateSplit adds a split to an expense. The payer's split is auto-settled.
func (s *FinanceService) CreateSplit(ctx context.Context, userID uuid.UUID, split *models.Split) error {
	expense, err := s.financeRepo.GetExpenseByID(ctx, split.ExpenseID)
	if err != nil {
		if err.Error() == "expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	if split.UserID == expense.PayerID {
		split.IsSettled = true
	}
	return s.financeRepo.CreateSplit(ctx, split)
}

// UpdateSplit modifies an existing split.
func (s *FinanceService) UpdateSplit(ctx context.Context, userID uuid.UUID, split *models.Split) error {
	existing, err := s.financeRepo.GetSplitByID(ctx, split.ID)
	if err != nil {
		if err.Error() == "split not found" {
			return api.ErrNotFound
		}
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, existing.ExpenseID)
	if err != nil {
		if err.Error() == "expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	split.ExpenseID = existing.ExpenseID
	return s.financeRepo.UpdateSplit(ctx, split)
}

// DeleteSplit removes a split (admin only).
func (s *FinanceService) DeleteSplit(ctx context.Context, userID, splitID uuid.UUID) error {
	existing, err := s.financeRepo.GetSplitByID(ctx, splitID)
	if err != nil {
		if err.Error() == "split not found" {
			return api.ErrNotFound
		}
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, existing.ExpenseID)
	if err != nil {
		if err.Error() == "expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireAdmin(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	return s.financeRepo.DeleteSplit(ctx, splitID)
}

// ------------------------------------------------------------------
// Settlements
// ------------------------------------------------------------------

// CreateSettlement records a settlement. The repository uses SELECT FOR UPDATE
// to prevent race conditions.
func (s *FinanceService) CreateSettlement(ctx context.Context, userID uuid.UUID, settlement *models.Settlement) error {
	if err := s.requireMember(ctx, settlement.GroupID, userID); err != nil {
		return err
	}
	if settlement.Amount <= 0 {
		return api.ErrValidation
	}
	return s.financeRepo.CreateSettlement(ctx, settlement)
}

// DeleteSettlement removes a settlement (admin only).
func (s *FinanceService) DeleteSettlement(ctx context.Context, userID, settlementID uuid.UUID) error {
	settlement, err := s.financeRepo.GetSettlementByID(ctx, settlementID)
	if err != nil {
		if err.Error() == "settlement not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireAdmin(ctx, settlement.GroupID, userID); err != nil {
		return err
	}
	return s.financeRepo.DeleteSettlement(ctx, settlementID)
}

// ------------------------------------------------------------------
// Recurring Expenses
// ------------------------------------------------------------------

// CreateRecurringExpense creates a recurring expense.
func (s *FinanceService) CreateRecurringExpense(ctx context.Context, userID uuid.UUID, re *models.RecurringExpense) error {
	if err := s.requireMember(ctx, re.GroupID, userID); err != nil {
		return err
	}
	if re.Amount <= 0 {
		return api.ErrValidation
	}
	return s.financeRepo.CreateRecurringExpense(ctx, re)
}

// GetRecurringExpense returns a recurring expense.
func (s *FinanceService) GetRecurringExpense(ctx context.Context, userID, id uuid.UUID) (*models.RecurringExpense, error) {
	re, err := s.financeRepo.GetRecurringExpenseByID(ctx, id)
	if err != nil {
		if err.Error() == "recurring expense not found" {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireMember(ctx, re.GroupID, userID); err != nil {
		return nil, err
	}
	return re, nil
}

// ListRecurringExpenses returns paginated recurring expenses.
func (s *FinanceService) ListRecurringExpenses(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.RecurringExpense, error) {
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.financeRepo.ListRecurringExpenses(ctx, groupID, limit, offset)
}

// UpdateRecurringExpense updates a recurring expense.
func (s *FinanceService) UpdateRecurringExpense(ctx context.Context, userID uuid.UUID, re *models.RecurringExpense) error {
	existing, err := s.financeRepo.GetRecurringExpenseByID(ctx, re.ID)
	if err != nil {
		if err.Error() == "recurring expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	re.GroupID = existing.GroupID
	return s.financeRepo.UpdateRecurringExpense(ctx, re)
}

// DeleteRecurringExpense removes a recurring expense (admin only).
func (s *FinanceService) DeleteRecurringExpense(ctx context.Context, userID, id uuid.UUID) error {
	existing, err := s.financeRepo.GetRecurringExpenseByID(ctx, id)
	if err != nil {
		if err.Error() == "recurring expense not found" {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireAdmin(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	return s.financeRepo.DeleteRecurringExpense(ctx, id)
}
