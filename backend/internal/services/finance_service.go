package services

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/sse"
)

// FinanceService implements business logic for expenses, splits, settlements
// and recurring expenses with permission checks and known bug fixes.
type FinanceService struct {
	financeRepo repositories.FinanceRepoIface
	groupRepo   repositories.GroupRepo
	dispatcher  NotificationDispatcher // optional; nil disables persist+push dispatch
	hub         *sse.Hub               // optional; nil disables SSE broadcasts
}

// ExpenseSplitInput describes one requested participant share for an expense.
type ExpenseSplitInput struct {
	UserID     uuid.UUID
	Amount     int64
	Shares     int64
	Percentage int64
}

// NewFinanceService creates a new FinanceService.
func NewFinanceService(financeRepo repositories.FinanceRepoIface, groupRepo repositories.GroupRepo) *FinanceService {
	return &FinanceService{
		financeRepo: financeRepo,
		groupRepo:   groupRepo,
	}
}

// SetDispatcher injects the notification dispatcher for persist+push broadcasts.
func (s *FinanceService) SetDispatcher(d NotificationDispatcher) { s.dispatcher = d }

// SetHub injects the SSE hub for real-time event broadcasts.
func (s *FinanceService) SetHub(h *sse.Hub) { s.hub = h }

func (s *FinanceService) requireMember(ctx context.Context, groupID, userID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *FinanceService) requireAdmin(ctx context.Context, groupID, userID uuid.UUID) error {
	return requireGroupAdmin(ctx, s.groupRepo, groupID, userID)
}

// ------------------------------------------------------------------
// Expenses
// ------------------------------------------------------------------

// CreateExpense creates an expense and optionally generates equal splits.
// It fixes the ZERO-SUM bug by auto-settling the payer's split and the
// EQUAL split bug with deterministic penny distribution by user_id ASC.
func (s *FinanceService) CreateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense, splitUserIDs []uuid.UUID) error {
	inputs := make([]ExpenseSplitInput, 0, len(splitUserIDs))
	for _, splitUserID := range splitUserIDs {
		inputs = append(inputs, ExpenseSplitInput{UserID: splitUserID})
	}
	return s.CreateExpenseWithSplitMode(ctx, userID, expense, "equal", inputs)
}

// CreateExpenseWithSplitMode creates an expense using equal, exact amount,
// percentage, or share-based splitting. Final split amounts are persisted so
// balance math remains simple and deterministic.
func (s *FinanceService) CreateExpenseWithSplitMode(ctx context.Context, userID uuid.UUID, expense *models.Expense, splitMode string, splitInputs []ExpenseSplitInput) error {
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	// Only allow setting a different payer if the user is an admin.
	if expense.PayerID != userID {
		if err := s.requireAdmin(ctx, expense.GroupID, userID); err != nil {
			return &api.ValidationError{Message: "payer must be the current user or you must be an admin"}
		}
	}
	if err := s.requireMember(ctx, expense.GroupID, expense.PayerID); err != nil {
		return &api.ValidationError{Message: "payer must be a member of this group"}
	}
	if expense.Amount <= 0 {
		return api.ErrValidation
	}
	if expense.Currency == "" {
		return api.ErrValidation
	}
	if err := s.normalizeBaseAmount(ctx, expense); err != nil {
		return err
	}

	splits, err := buildSplits(expense.BaseAmount, expense.PayerID, splitMode, splitInputs)
	if err != nil {
		return err
	}
	for _, split := range splits {
		if err := s.requireMember(ctx, expense.GroupID, split.UserID); err != nil {
			return &api.ValidationError{Message: "split user must be a member of this group"}
		}
	}
	if err := s.financeRepo.CreateExpenseWithSplits(ctx, expense, splits); err != nil {
		return err
	}
	if s.dispatcher != nil && expense.ID != uuid.Nil {
		actorName := s.memberDisplayName(ctx, expense.GroupID, userID)
		householdName := s.householdName(ctx, expense.GroupID)
		notifPayload := models.NotificationPayload{
			Screen:     models.ScreenExpenseDetail,
			EntityType: models.EntityTypeExpense,
			ID:         expense.ID.String(),
			GroupID:    expense.GroupID.String(),
			ActorName:  actorName,
			EntityName: expense.Description,
			Copy: models.NewNotificationCopy(models.NotificationTemplateExpenseCreated, map[string]string{
				"actor_name":   actorName,
				"expense_name": expense.Description,
				"group_name":   householdName,
			}),
		}
		_ = s.dispatcher.DispatchToGroup(ctx, expense.GroupID, userID, models.NotificationTypeExpenseCreated,
			"Expense added", actorName+" added "+expense.Description+" in "+householdName+".", notifPayload)
	}
	return nil
}

// normalizeBaseAmount converts the expense's entered amount into the group's
// base currency, capturing the FX rate. When the expense currency matches the
// group's base currency the rate is forced to 1 and base_amount = amount. For a
// foreign currency a positive FxRate is required and
// base_amount = round(amount * fx_rate). The integer BaseAmount is the stored
// truth used by all balance math; FxRate is retained for display only.
func (s *FinanceService) normalizeBaseAmount(ctx context.Context, expense *models.Expense) error {
	group, err := s.groupRepo.GetGroupByID(ctx, expense.GroupID)
	if err != nil {
		return err
	}
	if expense.Currency == group.Currency {
		expense.FxRate = 1
		expense.BaseAmount = expense.Amount
		return nil
	}
	if expense.FxRate <= 0 {
		return api.ErrValidation
	}
	expense.BaseAmount = int64(math.Round(float64(expense.Amount) * expense.FxRate))
	return nil
}

// GetExpense returns an expense by ID.
func (s *FinanceService) GetExpense(ctx context.Context, userID, expenseID uuid.UUID) (*models.Expense, error) {
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
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

// ListAllExpenses returns the full group expense ledger for exports.
func (s *FinanceService) ListAllExpenses(ctx context.Context, userID, groupID uuid.UUID) ([]models.Expense, error) {
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.financeRepo.ListAllExpensesByGroup(ctx, groupID)
}

// GetFinanceSummary returns the canonical group balance and reimbursement view.
// It uses a single aggregate SQL query instead of loading all historical rows.
func (s *FinanceService) GetFinanceSummary(ctx context.Context, userID, groupID uuid.UUID) (*models.FinanceSummary, error) {
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}

	aggregates, err := s.financeRepo.GetGroupBalanceAggregates(ctx, groupID)
	if err != nil {
		return nil, err
	}
	profiles, err := s.groupRepo.ListMemberProfilesByGroup(ctx, groupID)
	if err != nil {
		return nil, err
	}

	balances := balancesFromAggregates(aggregates)
	applyDisplayNames(balances, profiles)
	return &models.FinanceSummary{
		Balances:       balances,
		Reimbursements: suggestReimbursements(balances),
	}, nil
}

// balancesFromAggregates converts database aggregates into BalanceEntry slice
// using the same semantics as calculateBalances:
//
//	Paid  = ExpensePaid + SettledOut  (payer credits + settlements sent)
//	Owed  = SplitOwed  + SettledIn   (split debits  + settlements received)
//	Total = Paid - Owed
//
// Sort order: UserID.String() ascending — matches calculateBalances.
func balancesFromAggregates(aggregates []models.BalanceAggregate) []models.BalanceEntry {
	balances := make([]models.BalanceEntry, 0, len(aggregates))
	for _, agg := range aggregates {
		paid := agg.ExpensePaid + agg.SettledOut
		owed := agg.SplitOwed + agg.SettledIn
		balances = append(balances, models.BalanceEntry{
			UserID: agg.UserID,
			Paid:   paid,
			Owed:   owed,
			Total:  paid - owed,
		})
	}
	// The SQL query returns rows ORDER BY user_id ASC, which is uuid string sort.
	// UUIDs are stored as bytes in PostgreSQL; to guarantee identical ordering
	// with calculateBalances (which sorts on uuid.String()), we re-sort here.
	sort.Slice(balances, func(i, j int) bool {
		return balances[i].UserID.String() < balances[j].UserID.String()
	})
	return balances
}

// UpdateExpense updates an existing expense.
func (s *FinanceService) UpdateExpense(ctx context.Context, userID uuid.UUID, expense *models.Expense) error {
	existing, err := s.financeRepo.GetExpenseByID(ctx, expense.ID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	// Only allow reassigning the payer if the user is an admin.
	if expense.PayerID != existing.PayerID && expense.PayerID != userID {
		if err := s.requireAdmin(ctx, existing.GroupID, userID); err != nil {
			return &api.ValidationError{Message: "payer must be the current user or you must be an admin"}
		}
	}
	if expense.PayerID != existing.PayerID {
		if err := s.requireMember(ctx, existing.GroupID, expense.PayerID); err != nil {
			return &api.ValidationError{Message: "payer must be a member of this group"}
		}
	}
	if expense.Amount <= 0 {
		return api.ErrValidation
	}
	expense.GroupID = existing.GroupID
	if err := s.normalizeBaseAmount(ctx, expense); err != nil {
		return err
	}

	// base_amount unchanged → splits already consistent, plain update is enough.
	if expense.BaseAmount == existing.BaseAmount {
		return s.financeRepo.UpdateExpense(ctx, expense)
	}

	// base_amount changed → rescale existing splits proportionally so their
	// sum stays equal to base_amount (the invariant all balance math relies on).
	existingSplits, err := s.financeRepo.ListSplitsByExpense(ctx, expense.ID)
	if err != nil {
		return err
	}
	rescaled := rescaleSplits(existingSplits, existing.BaseAmount, expense.BaseAmount)
	return s.financeRepo.UpdateExpenseWithSplits(ctx, expense, rescaled)
}

// rescaleSplits proportionally rescales splits from oldTotal to newTotal,
// preserving each split's share and guaranteeing the new amounts sum to
// newTotal. is_settled and user are preserved. Safe when oldTotal == 0.
func rescaleSplits(splits []models.Split, oldTotal, newTotal int64) []models.Split {
	out := make([]models.Split, len(splits))
	copy(out, splits)
	if len(out) == 0 {
		return out
	}
	var assigned int64
	largest := 0
	for i := range out {
		var amt int64
		if oldTotal > 0 {
			amt = int64(math.Round(float64(out[i].Amount) * float64(newTotal) / float64(oldTotal)))
		} else {
			amt = newTotal / int64(len(out))
		}
		out[i].Amount = amt
		assigned += amt
		if out[i].Amount > out[largest].Amount {
			largest = i
		}
	}
	out[largest].Amount += newTotal - assigned
	return out
}

// DeleteExpense removes an expense (admin only).
func (s *FinanceService) DeleteExpense(ctx context.Context, userID, expenseID uuid.UUID) error {
	existing, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
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
		if errors.Is(err, pgx.ErrNoRows) {
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
		if errors.Is(err, pgx.ErrNoRows) {
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
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, existing.ExpenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return err
	}
	if split.Amount <= 0 {
		return &api.ValidationError{Message: "split amount must be positive"}
	}
	// Only allow reassigning the split to another user if the actor is an admin.
	if split.UserID != existing.UserID {
		if err := s.requireAdmin(ctx, expense.GroupID, userID); err != nil {
			return err
		}
	}
	split.ExpenseID = existing.ExpenseID
	return s.financeRepo.UpdateSplit(ctx, split)
}

// DeleteSplit removes a split (admin only).
func (s *FinanceService) DeleteSplit(ctx context.Context, userID, splitID uuid.UUID) error {
	existing, err := s.financeRepo.GetSplitByID(ctx, splitID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	expense, err := s.financeRepo.GetExpenseByID(ctx, existing.ExpenseID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
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

// CreateSettlement records a pending settlement. Only a participant (payer or
// receiver) may record it, and the counterparty must confirm it before it
// affects balances. The repository uses SELECT FOR UPDATE to prevent races.
func (s *FinanceService) CreateSettlement(ctx context.Context, userID uuid.UUID, settlement *models.Settlement) error {
	if err := s.requireMember(ctx, settlement.GroupID, userID); err != nil {
		return err
	}
	if settlement.Amount <= 0 {
		return api.ErrValidation
	}
	if settlement.FromUserID == settlement.ToUserID {
		return &api.ValidationError{Message: "settlement must be between two different members"}
	}
	if userID != settlement.FromUserID && userID != settlement.ToUserID {
		return &api.ValidationError{Message: "only the payer or the receiver can record a settlement"}
	}
	if err := s.requireMember(ctx, settlement.GroupID, settlement.FromUserID); err != nil {
		return &api.ValidationError{Message: "from user must be a group member"}
	}
	if err := s.requireMember(ctx, settlement.GroupID, settlement.ToUserID); err != nil {
		return &api.ValidationError{Message: "to user must be a group member"}
	}
	settlement.CreatedBy = userID
	settlement.Status = models.SettlementStatusPending
	if err := s.financeRepo.CreateSettlement(ctx, settlement); err != nil {
		return err
	}

	if s.dispatcher != nil {
		creatorName := s.memberDisplayName(ctx, settlement.GroupID, settlement.CreatedBy)
		householdName := s.householdName(ctx, settlement.GroupID)
		amount := s.formatGroupAmount(ctx, settlement.GroupID, settlement.Amount)
		var body string
		var template string
		if settlement.CreatedBy == settlement.FromUserID {
			body = creatorName + " says they paid you " + amount + " in " + householdName + ". Confirm to update balances."
			template = models.NotificationTemplateSettlementPaidYou
		} else {
			body = creatorName + " says you paid them " + amount + " in " + householdName + ". Confirm to update balances."
			template = models.NotificationTemplateSettlementYouPaid
		}
		payload := s.settlementPayload(settlement)
		payload.Copy = models.NewNotificationCopy(template, map[string]string{
			"actor_name": creatorName,
			"amount":     amount,
			"group_name": householdName,
		})
		_ = s.dispatcher.DispatchToUsers(ctx, []uuid.UUID{settlement.Counterparty()}, settlement.GroupID,
			models.NotificationTypeSettlementRequested, "Settlement to confirm", body, payload)
	}
	s.publishSettlement("settlement:created", settlement.GroupID, settlement.ID)
	return nil
}

// ListSettlements returns paginated settlements for a group.
func (s *FinanceService) ListSettlements(ctx context.Context, userID, groupID uuid.UUID, limit, offset int) ([]models.Settlement, error) {
	if err := s.requireMember(ctx, groupID, userID); err != nil {
		return nil, err
	}
	return s.financeRepo.ListSettlementsByGroup(ctx, groupID, limit, offset)
}

// RespondToSettlement lets the counterparty confirm or decline a pending
// settlement. Only the participant who did not record it may respond.
func (s *FinanceService) RespondToSettlement(ctx context.Context, userID, settlementID uuid.UUID, approve bool) (*models.Settlement, error) {
	settlement, err := s.financeRepo.GetSettlementByID(ctx, settlementID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, api.ErrNotFound
		}
		return nil, err
	}
	if err := s.requireMember(ctx, settlement.GroupID, userID); err != nil {
		return nil, err
	}
	if userID != settlement.Counterparty() {
		return nil, &api.PermissionDeniedError{}
	}
	if settlement.Status != models.SettlementStatusPending {
		return nil, api.ErrConflict
	}

	status := models.SettlementStatusDeclined
	if approve {
		status = models.SettlementStatusConfirmed
	}
	now := time.Now().UTC()
	if err := s.financeRepo.UpdateSettlementStatus(ctx, settlementID, status, now); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Lost a race with a concurrent response or cancellation.
			return nil, api.ErrConflict
		}
		return nil, err
	}
	settlement.Status = status
	settlement.RespondedAt = &now

	if s.dispatcher != nil {
		responderName := s.memberDisplayName(ctx, settlement.GroupID, userID)
		householdName := s.householdName(ctx, settlement.GroupID)
		amount := s.formatGroupAmount(ctx, settlement.GroupID, settlement.Amount)
		nType, title, verb := models.NotificationTypeSettlementConfirmed, "Settlement confirmed", "confirmed"
		if !approve {
			nType, title, verb = models.NotificationTypeSettlementDeclined, "Settlement declined", "declined"
		}
		body := responderName + " " + verb + " your settlement of " + amount + " in " + householdName + "."
		payload := s.settlementPayload(settlement)
		template := models.NotificationTemplateSettlementConfirmed
		if !approve {
			template = models.NotificationTemplateSettlementDeclined
		}
		payload.Copy = models.NewNotificationCopy(template, map[string]string{
			"actor_name": responderName,
			"amount":     amount,
			"group_name": householdName,
		})
		_ = s.dispatcher.DispatchToUsers(ctx, []uuid.UUID{settlement.CreatedBy}, settlement.GroupID,
			nType, title, body, payload)
	}
	s.publishSettlement("settlement:updated", settlement.GroupID, settlement.ID)
	return settlement, nil
}

// DeleteSettlement removes a settlement. The creator can cancel their own
// pending settlement; anything else requires a group admin.
func (s *FinanceService) DeleteSettlement(ctx context.Context, userID, settlementID uuid.UUID) error {
	settlement, err := s.financeRepo.GetSettlementByID(ctx, settlementID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	creatorCancel := settlement.Status == models.SettlementStatusPending && settlement.CreatedBy == userID
	if !creatorCancel {
		if err := s.requireAdmin(ctx, settlement.GroupID, userID); err != nil {
			return err
		}
	}
	if err := s.financeRepo.DeleteSettlement(ctx, settlementID); err != nil {
		return err
	}
	s.publishSettlement("settlement:deleted", settlement.GroupID, settlement.ID)
	return nil
}

// settlementPayload builds the deep-link payload for settlement notifications.
func (s *FinanceService) settlementPayload(settlement *models.Settlement) models.NotificationPayload {
	return models.NotificationPayload{
		Screen:     models.ScreenSettlements,
		EntityType: models.EntityTypeSettlement,
		ID:         settlement.ID.String(),
		GroupID:    settlement.GroupID.String(),
	}
}

// memberDisplayName resolves a member's display name, falling back to
// "A group member" so notification bodies never show raw UUIDs.
func (s *FinanceService) memberDisplayName(ctx context.Context, groupID, userID uuid.UUID) string {
	profiles, err := s.groupRepo.ListMemberProfilesByGroup(ctx, groupID)
	if err == nil {
		for _, p := range profiles {
			if p.UserID == userID && strings.TrimSpace(p.DisplayName) != "" {
				return p.DisplayName
			}
		}
	}
	return "A group member"
}

func (s *FinanceService) householdName(ctx context.Context, groupID uuid.UUID) string {
	group, err := s.groupRepo.GetGroupByID(ctx, groupID)
	if err == nil && strings.TrimSpace(group.Name) != "" {
		return group.Name
	}
	return "your household"
}

// formatGroupAmount renders an integer minor-unit amount in the group currency.
func (s *FinanceService) formatGroupAmount(ctx context.Context, groupID uuid.UUID, amount int64) string {
	currency := ""
	if group, err := s.groupRepo.GetGroupByID(ctx, groupID); err == nil {
		currency = group.Currency
	}
	value := strconv.FormatFloat(float64(amount)/100, 'f', 2, 64)
	if currency == "" {
		return value
	}
	return value + " " + currency
}

// publishSettlement emits an SSE event for a settlement state change.
func (s *FinanceService) publishSettlement(eventType string, groupID, settlementID uuid.UUID) {
	if s.hub == nil {
		return
	}
	data, _ := json.Marshal(map[string]string{"settlement_id": settlementID.String()})
	s.hub.Publish(groupID.String(), sse.Event{
		Type:    eventType,
		GroupID: groupID.String(),
		Payload: data,
	})
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
	if err := s.validateRecurringSplitConfig(ctx, re); err != nil {
		return err
	}
	return s.financeRepo.CreateRecurringExpense(ctx, re)
}

// GetRecurringExpense returns a recurring expense.
func (s *FinanceService) GetRecurringExpense(ctx context.Context, userID, id uuid.UUID) (*models.RecurringExpense, error) {
	re, err := s.financeRepo.GetRecurringExpenseByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
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
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireMember(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	if re.Amount <= 0 {
		return api.ErrValidation
	}
	// Only allow reassigning the payer if the user is an admin.
	if re.PayerID != existing.PayerID && re.PayerID != userID {
		if err := s.requireAdmin(ctx, existing.GroupID, userID); err != nil {
			return &api.ValidationError{Message: "payer must be the current user or you must be an admin"}
		}
	}
	re.GroupID = existing.GroupID
	if err := s.validateRecurringSplitConfig(ctx, re); err != nil {
		return err
	}
	return s.financeRepo.UpdateRecurringExpense(ctx, re)
}

// validateRecurringSplitConfig validates split_mode and split_inputs if a non-payer-only mode is set.
func (s *FinanceService) validateRecurringSplitConfig(ctx context.Context, re *models.RecurringExpense) error {
	if re.SplitMode == "" || re.SplitMode == "payer_only" {
		return nil
	}
	// Validate every referenced user is a group member.
	for _, si := range re.SplitInputs {
		if err := s.requireMember(ctx, re.GroupID, si.UserID); err != nil {
			return &api.ValidationError{Message: "split user must be a member of this group"}
		}
	}
	// Validate the split math by attempting a dry-run build.
	inputs := toExpenseSplitInputs(re.SplitInputs)
	if _, err := buildSplits(re.Amount, re.PayerID, re.SplitMode, inputs); err != nil {
		return err
	}
	return nil
}

func toExpenseSplitInputs(in []models.RecurringSplitInput) []ExpenseSplitInput {
	out := make([]ExpenseSplitInput, len(in))
	for i, si := range in {
		out[i] = ExpenseSplitInput{
			UserID:     si.UserID,
			Amount:     si.Amount,
			Shares:     si.Shares,
			Percentage: si.Percentage,
		}
	}
	return out
}

// DeleteRecurringExpense removes a recurring expense (admin only).
func (s *FinanceService) DeleteRecurringExpense(ctx context.Context, userID, id uuid.UUID) error {
	existing, err := s.financeRepo.GetRecurringExpenseByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return api.ErrNotFound
		}
		return err
	}
	if err := s.requireAdmin(ctx, existing.GroupID, userID); err != nil {
		return err
	}
	return s.financeRepo.DeleteRecurringExpense(ctx, id)
}

// ListExpenseSplits returns all splits for an expense.
func (s *FinanceService) ListExpenseSplits(ctx context.Context, userID, expenseID uuid.UUID) ([]models.Split, error) {
	expense, err := s.financeRepo.GetExpenseByID(ctx, expenseID)
	if err != nil {
		return nil, err
	}
	if err := s.requireMember(ctx, expense.GroupID, userID); err != nil {
		return nil, err
	}
	return s.financeRepo.ListSplitsByExpense(ctx, expenseID)
}

func calculateBalances(expenses []models.Expense, splits []models.Split, settlements []models.Settlement) []models.BalanceEntry {
	byUser := map[uuid.UUID]*models.BalanceEntry{}
	ensure := func(userID uuid.UUID) *models.BalanceEntry {
		if _, ok := byUser[userID]; !ok {
			byUser[userID] = &models.BalanceEntry{UserID: userID}
		}
		return byUser[userID]
	}

	for _, expense := range expenses {
		balance := ensure(expense.PayerID)
		balance.Paid += expense.BaseAmount
	}
	for _, split := range splits {
		balance := ensure(split.UserID)
		balance.Owed += split.Amount
	}
	for _, settlement := range settlements {
		if settlement.Status != models.SettlementStatusConfirmed {
			continue
		}
		from := ensure(settlement.FromUserID)
		to := ensure(settlement.ToUserID)
		from.Paid += settlement.Amount
		to.Owed += settlement.Amount
	}

	balances := make([]models.BalanceEntry, 0, len(byUser))
	for _, balance := range byUser {
		balance.Total = balance.Paid - balance.Owed
		balances = append(balances, *balance)
	}
	sort.Slice(balances, func(i, j int) bool {
		return balances[i].UserID.String() < balances[j].UserID.String()
	})
	return balances
}

func applyDisplayNames(balances []models.BalanceEntry, profiles []models.GroupMemberProfile) {
	names := map[uuid.UUID]string{}
	for _, profile := range profiles {
		names[profile.UserID] = profile.DisplayName
	}
	for i := range balances {
		if name := strings.TrimSpace(names[balances[i].UserID]); name != "" {
			balances[i].DisplayName = name
		} else {
			balances[i].DisplayName = balances[i].UserID.String()
		}
	}
}

func suggestReimbursements(balances []models.BalanceEntry) []models.ReimbursementSuggestion {
	working := make([]models.BalanceEntry, 0, len(balances))
	for _, balance := range balances {
		if balance.Total != 0 {
			working = append(working, balance)
		}
	}
	sort.Slice(working, func(i, j int) bool {
		left, right := working[i], working[j]
		if left.Total > 0 && right.Total < 0 {
			return true
		}
		if right.Total > 0 && left.Total < 0 {
			return false
		}
		return left.UserID.String() < right.UserID.String()
	})

	reimbursements := []models.ReimbursementSuggestion{}
	for len(working) > 1 {
		first := &working[0]
		last := &working[len(working)-1]
		if first.Total <= 0 || last.Total >= 0 {
			break
		}

		amount := first.Total
		if -last.Total < amount {
			amount = -last.Total
		}
		if amount > 0 {
			reimbursements = append(reimbursements, models.ReimbursementSuggestion{
				FromUserID:      last.UserID,
				FromDisplayName: last.DisplayName,
				ToUserID:        first.UserID,
				ToDisplayName:   first.DisplayName,
				Amount:          amount,
			})
		}

		first.Total -= amount
		last.Total += amount
		if last.Total == 0 {
			working = working[:len(working)-1]
		}
		if len(working) > 0 && working[0].Total == 0 {
			working = working[1:]
		}
	}
	return reimbursements
}

func buildSplits(total int64, payerID uuid.UUID, splitMode string, inputs []ExpenseSplitInput) ([]models.Split, error) {
	if len(inputs) == 0 {
		return nil, nil
	}
	mode := strings.ToLower(strings.TrimSpace(splitMode))
	if mode == "" {
		mode = "equal"
	}

	sort.Slice(inputs, func(i, j int) bool {
		return inputs[i].UserID.String() < inputs[j].UserID.String()
	})
	seen := map[uuid.UUID]struct{}{}
	for _, input := range inputs {
		if input.UserID == uuid.Nil {
			return nil, &api.ValidationError{Message: "split user is required"}
		}
		if _, ok := seen[input.UserID]; ok {
			return nil, &api.ValidationError{Message: "duplicate split user"}
		}
		seen[input.UserID] = struct{}{}
	}

	amounts := make([]int64, len(inputs))
	switch mode {
	case "equal", "evenly":
		base := total / int64(len(inputs))
		rem := total % int64(len(inputs))
		for i := range inputs {
			amounts[i] = base
			if int64(i) < rem {
				amounts[i]++
			}
		}
	case "amount", "exact":
		var sum int64
		for i, input := range inputs {
			if input.Amount <= 0 {
				return nil, &api.ValidationError{Message: "split amounts must be positive"}
			}
			amounts[i] = input.Amount
			sum += input.Amount
		}
		if sum != total {
			return nil, &api.ValidationError{Message: "split amounts must equal expense amount"}
		}
	case "shares":
		var shareSum int64
		for _, input := range inputs {
			if input.Shares <= 0 {
				return nil, &api.ValidationError{Message: "shares must be positive"}
			}
			shareSum += input.Shares
		}
		distributeByWeight(total, inputs, amounts, func(input ExpenseSplitInput) int64 { return input.Shares }, shareSum)
	case "percentage":
		var percentageSum int64
		for _, input := range inputs {
			if input.Percentage <= 0 {
				return nil, &api.ValidationError{Message: "percentages must be positive basis points"}
			}
			percentageSum += input.Percentage
		}
		if percentageSum != 10000 {
			return nil, &api.ValidationError{Message: "percentages must total 100% (basis points: 10000)"}
		}
		distributeByWeight(total, inputs, amounts, func(input ExpenseSplitInput) int64 { return input.Percentage }, percentageSum)
	default:
		return nil, &api.ValidationError{Message: "unsupported split mode"}
	}

	splits := make([]models.Split, 0, len(inputs))
	for i, input := range inputs {
		split := models.Split{UserID: input.UserID, Amount: amounts[i]}
		if input.UserID == payerID {
			split.IsSettled = true
		}
		splits = append(splits, split)
	}
	return splits, nil
}

// BuildExpenseSplits exposes split computation for jobs.
func BuildExpenseSplits(total int64, payerID uuid.UUID, splitMode string, inputs []ExpenseSplitInput) ([]models.Split, error) {
	return buildSplits(total, payerID, splitMode, inputs)
}

func distributeByWeight(total int64, inputs []ExpenseSplitInput, amounts []int64, weight func(ExpenseSplitInput) int64, weightSum int64) {
	var assigned int64
	for i, input := range inputs {
		if i == len(inputs)-1 {
			amounts[i] = total - assigned
			break
		}
		amount := total * weight(input) / weightSum
		amounts[i] = amount
		assigned += amount
	}
}
