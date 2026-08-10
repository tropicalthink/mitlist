package handlers

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestFinance_CreateExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "fin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "Fin Group",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id":       group.ID.String(),
		"payer_id":       user.ID.String(),
		"amount":         10000,
		"description":    "Dinner",
		"category":       "Food",
		"currency":       "USD",
		"date":           time.Now().Format(time.RFC3339),
		"split_user_ids": []string{user.ID.String()},
	}
	rec := execRequest(t, router, "POST", "/api/v1/expenses", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Dinner", resp["description"])
}

func TestFinance_CreateExpense_ForeignCurrency(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "fx@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "FX Group",
		Currency:  "USD",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id":       group.ID.String(),
		"payer_id":       user.ID.String(),
		"amount":         5000,
		"fx_rate":        1.10,
		"description":    "Paris dinner",
		"category":       "Food",
		"currency":       "EUR",
		"date":           time.Now().Format(time.RFC3339),
		"split_user_ids": []string{user.ID.String()},
	}
	rec := execRequest(t, router, "POST", "/api/v1/expenses", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, float64(5500), resp["base_amount"])
	assert.InDelta(t, 1.10, resp["fx_rate"].(float64), 1e-9)
}

// TestFinance_SplitInvariant pins the end-to-end contract that a POST
// /expenses request flows through handler -> service -> repository and
// persists splits whose amounts sum EXACTLY to the expense amount, for every
// split mode. The split-sum invariant underlies all balance and settlement
// math; we assert on the sum (and count), not on which participant absorbs a
// rounding penny.
func TestFinance_SplitInvariant(t *testing.T) {
	cases := []struct {
		name             string
		mode             string
		amount           int64
		participants     int
		buildBody        func(payer uuid.UUID, members []uuid.UUID) map[string]any
		wantParticipants int
		assertSplits     func(t *testing.T, splits []models.Split)
	}{
		{
			name:             "equal",
			mode:             "equal",
			amount:           10000,
			participants:     3,
			wantParticipants: 3,
			buildBody: func(payer uuid.UUID, members []uuid.UUID) map[string]any {
				ids := make([]string, len(members))
				for i, m := range members {
					ids[i] = m.String()
				}
				return map[string]any{
					"split_mode":     "equal",
					"split_user_ids": ids,
				}
			},
			assertSplits: func(t *testing.T, splits []models.Split) {
				for _, s := range splits {
					assert.Truef(t, s.Amount == 3333 || s.Amount == 3334,
						"equal split must be 3333 or 3334, got %d", s.Amount)
				}
			},
		},
		{
			name:             "amount",
			mode:             "amount",
			amount:           10000,
			participants:     3,
			wantParticipants: 3,
			buildBody: func(payer uuid.UUID, members []uuid.UUID) map[string]any {
				return map[string]any{
					"split_mode": "amount",
					"splits": []map[string]any{
						{"user_id": members[0].String(), "amount": 5000},
						{"user_id": members[1].String(), "amount": 3000},
						{"user_id": members[2].String(), "amount": 2000},
					},
				}
			},
		},
		{
			name:             "shares",
			mode:             "shares",
			amount:           10000,
			participants:     3,
			wantParticipants: 3,
			buildBody: func(payer uuid.UUID, members []uuid.UUID) map[string]any {
				return map[string]any{
					"split_mode": "shares",
					"splits": []map[string]any{
						{"user_id": members[0].String(), "shares": 1},
						{"user_id": members[1].String(), "shares": 1},
						{"user_id": members[2].String(), "shares": 2},
					},
				}
			},
		},
		{
			name:             "percentage",
			mode:             "percentage",
			amount:           10001, // not divisible; proves remainder handling preserves total
			participants:     3,
			wantParticipants: 3,
			buildBody: func(payer uuid.UUID, members []uuid.UUID) map[string]any {
				return map[string]any{
					"split_mode": "percentage",
					"splits": []map[string]any{
						{"user_id": members[0].String(), "percentage": 5000},
						{"user_id": members[1].String(), "percentage": 3000},
						{"user_id": members[2].String(), "percentage": 2000},
					},
				}
			},
		},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			clearTables(t)
			router, _ := newFinanceRouter(t)
			groupRepo := newTestGroupRepo()

			// Payer/creator is the authenticated user.
			payer := createTestUser(t, "split-"+tc.name+"-0@example.com", "password123")
			token := generateTestToken(payer.ID)

			group := &models.Group{
				ID:        uuid.New(),
				Name:      "Split " + tc.name,
				CreatedBy: payer.ID,
				Currency:  "USD",
				CreatedAt: time.Now().UTC(),
				UpdatedAt: time.Now().UTC(),
			}
			require.NoError(t, groupRepo.CreateGroup(context.Background(), group))

			// Membership is required for every split participant (and the
			// payer). The creator is an admin; the rest are members.
			members := []uuid.UUID{payer.ID}
			require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
				GroupID: group.ID, UserID: payer.ID, Role: "admin",
			}))
			for i := 1; i < tc.participants; i++ {
				u := createTestUser(t, fmt.Sprintf("split-%s-%d@example.com", tc.name, i), "password123")
				require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
					GroupID: group.ID, UserID: u.ID, Role: "member",
				}))
				members = append(members, u.ID)
			}

			body := tc.buildBody(payer.ID, members)
			body["group_id"] = group.ID.String()
			body["payer_id"] = payer.ID.String()
			body["amount"] = tc.amount
			body["description"] = "Split " + tc.name
			body["category"] = "Food"
			body["currency"] = "USD"
			body["date"] = time.Now().Format(time.RFC3339)

			rec := execRequest(t, router, "POST", "/api/v1/expenses", body, token)
			requireStatus(t, rec, http.StatusCreated)

			var resp map[string]any
			parseJSONResponse(t, rec, &resp)
			expenseID := uuid.MustParse(resp["id"].(string))

			splits, err := newTestFinanceRepo().ListSplitsByExpense(context.Background(), expenseID)
			require.NoError(t, err)
			require.Len(t, splits, tc.wantParticipants)

			var sum int64
			for _, s := range splits {
				assert.Greaterf(t, s.Amount, int64(0), "split amount must be positive, got %d", s.Amount)
				sum += s.Amount
			}
			require.Equalf(t, tc.amount, sum, "splits must sum exactly to the expense amount")

			if tc.assertSplits != nil {
				tc.assertSplits(t, splits)
			}
		})
	}
}

func TestFinance_ListExpenses(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "lsfin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")
	financeRepo := newTestFinanceRepo()
	require.NoError(t, financeRepo.CreateExpense(context.Background(), &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      5000,
		Description: "Lunch",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/expenses?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}

func TestFinance_GetExpense_NotFound(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "nffin@example.com", "password123")
	token := generateTestToken(user.ID)

	rec := execRequest(t, router, "GET", "/api/v1/expenses/"+uuid.New().String(), nil, token)
	requireStatus(t, rec, http.StatusNotFound)
}

func TestFinance_DeleteExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "delfin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      5000,
		Description: "X",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	rec := execRequest(t, router, "DELETE", "/api/v1/expenses/"+expense.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusNoContent)
}

// Optimistic concurrency on expense update. Without this an offline edit that
// drains after somebody else's edit silently overwrites it — and unlike a list
// item, a clobbered expense costs somebody money.
func TestFinance_UpdateExpense_OptimisticConcurrency(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "occfin@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	financeRepo := newTestFinanceRepo()
	updatedAt := time.Now().UTC()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      5000,
		Description: "Groceries",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   updatedAt,
		UpdatedAt:   updatedAt,
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	url := "/api/v1/expenses/" + expense.ID.String()

	// Stale base (someone else edited since) -> 409 carrying the server's row,
	// which is what the client's conflict sheet renders as "theirs".
	rec := execRequest(t, router, "PATCH", url, map[string]any{
		"amount":              9900,
		"expected_updated_at": updatedAt.Add(-time.Hour),
	}, token)
	requireStatus(t, rec, http.StatusConflict)
	var conflict map[string]any
	parseJSONResponse(t, rec, &conflict)
	assert.Equal(t, "conflict", conflict["error"])
	assert.NotNil(t, conflict["current"], "409 must carry the current expense")

	// Correct base truncated to the second -> succeeds. Same regression guard as
	// the list-item case: Drift stores DateTime as unix SECONDS, so the base the
	// client sends back has lost its sub-second component and must not 409.
	rec = execRequest(t, router, "PATCH", url, map[string]any{
		"amount":              9900,
		"expected_updated_at": updatedAt.Truncate(time.Second),
	}, token)
	requireStatus(t, rec, http.StatusOK)

	// Omitting the base entirely stays last-write-wins, so existing clients and
	// non-offline callers are unaffected.
	rec = execRequest(t, router, "PATCH", url, map[string]any{"amount": 12300}, token)
	requireStatus(t, rec, http.StatusOK)
}

func TestFinance_CreateSplit(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "split@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Dinner",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	body := map[string]any{"user_id": user.ID.String(), "amount": 5000}
	rec := execRequest(t, router, "POST", "/api/v1/expenses/"+expense.ID.String()+"/splits", body, token)
	requireStatus(t, rec, http.StatusCreated)
}

func TestFinance_CreateSettlement(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "settle@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")
	member := createTestUser(t, "settle-member@example.com", "password123")
	addTestMembership(t, group.ID, member.ID, "member")
	financeRepo := newTestFinanceRepo()
	expense := &models.Expense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Dinner",
		Category:    "Food",
		Currency:    "USD",
		Date:        time.Now().UTC(),
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}
	require.NoError(t, financeRepo.CreateExpense(context.Background(), expense))

	body := map[string]any{
		"from_user_id": member.ID.String(),
		"to_user_id":   user.ID.String(),
		"amount":       5000,
	}
	rec := execRequest(t, router, "POST", "/api/v1/expenses/"+expense.ID.String()+"/settle", body, token)
	requireStatus(t, rec, http.StatusCreated)
}

func TestFinance_CreateRecurringExpense(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "rec@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")

	body := map[string]any{
		"group_id":    group.ID.String(),
		"payer_id":    user.ID.String(),
		"amount":      10000,
		"description": "Rent",
		"category":    "Housing",
		"frequency":   "monthly",
		"next_due":    time.Now().Add(24 * time.Hour).Format(time.RFC3339),
		"is_active":   true,
	}
	rec := execRequest(t, router, "POST", "/api/v1/recurring-expenses", body, token)
	requireStatus(t, rec, http.StatusCreated)

	var resp map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Equal(t, "Rent", resp["description"])
}

func TestFinance_ListRecurringExpenses(t *testing.T) {
	clearTables(t)
	router, _ := newFinanceRouter(t)
	user := createTestUser(t, "lsrec@example.com", "password123")
	token := generateTestToken(user.ID)

	groupRepo := newTestGroupRepo()
	group := &models.Group{
		ID:        uuid.New(),
		Name:      "G",
		CreatedBy: user.ID,
		CreatedAt: time.Now().UTC(),
		UpdatedAt: time.Now().UTC(),
	}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	addTestMembership(t, group.ID, user.ID, "admin")
	financeRepo := newTestFinanceRepo()
	require.NoError(t, financeRepo.CreateRecurringExpense(context.Background(), &models.RecurringExpense{
		ID:          uuid.New(),
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      10000,
		Description: "Rent",
		Category:    "Housing",
		Frequency:   "monthly",
		NextDue:     time.Now().Add(24 * time.Hour),
		IsActive:    true,
		CreatedAt:   time.Now().UTC(),
	}))

	rec := execRequest(t, router, "GET", "/api/v1/recurring-expenses?group_id="+group.ID.String(), nil, token)
	requireStatus(t, rec, http.StatusOK)

	var resp []map[string]any
	parseJSONResponse(t, rec, &resp)
	assert.Len(t, resp, 1)
}
