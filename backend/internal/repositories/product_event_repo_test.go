package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

func TestProductEventRepository_InsertEventsInOneStatement(t *testing.T) {
	mock := newMockDB(t)
	repo := NewProductEventRepository(mock)
	install := uuid.New()
	user := uuid.New()
	group := uuid.New()
	role := "creator"

	mock.ExpectExec(`INSERT INTO product_events \(occurred_at, name, user_id, install_id, group_id, role, props\) VALUES \(\$1, \$2, \$3, \$4, \$5, \$6, \$7\), \(\$8, \$9, \$10, \$11, \$12, \$13, \$14\)`).
		WithArgs(
			fixedTime(), "welcome_shown", (*uuid.UUID)(nil), &install, (*uuid.UUID)(nil), (*string)(nil), []byte("{}"),
			fixedTime(), "home_needs_you_action", &user, (*uuid.UUID)(nil), &group, &role, []byte(`{"type":"chore"}`),
		).
		WillReturnResult(pgxmock.NewResult("INSERT", 2))

	err := repo.InsertEvents(context.Background(), []models.ProductEvent{
		{OccurredAt: fixedTime(), Name: "welcome_shown", InstallID: &install},
		{OccurredAt: fixedTime(), Name: "home_needs_you_action", UserID: &user, GroupID: &group, Role: "creator", Props: map[string]string{"type": "chore"}},
	})
	require.NoError(t, err)
	require.NoError(t, mock.ExpectationsWereMet())
}

func TestProductEventRepository_EmptyBatchIsANoOp(t *testing.T) {
	mock := newMockDB(t)
	require.NoError(t, NewProductEventRepository(mock).InsertEvents(context.Background(), nil))
	require.NoError(t, mock.ExpectationsWereMet())
}
