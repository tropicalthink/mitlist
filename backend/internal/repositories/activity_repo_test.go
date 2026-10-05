package repositories

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
)

// A member joining shows in the household's activity (plans/048 stage 7),
// read from group_memberships like every other event is read from its own
// table, without the creator's own membership from when the household was
// made.
func TestActivityRepository_ListRecentActivity_IncludesJoins(t *testing.T) {
	mock := newMockDB(t)
	repo := NewActivityRepository(mock)
	groupID := uuid.New()
	joiner := uuid.New()
	membershipID := uuid.New()
	name := "Sam Okafor"

	rows := pgxmock.NewRows([]string{
		"id", "type", "title", "created_at", "user_id", "group_id",
		"entity_type", "entity_id", "context", "user_name",
	}).AddRow(
		membershipID.String(), "member_joined", "Sam", fixedTime(), &joiner, groupID,
		"member", joiner.String(), (*string)(nil), &name,
	)

	mock.ExpectQuery(`(?s)'member_joined'.*FROM group_memberships jm.*` +
		`NOT \(jm\.user_id = jg\.created_by AND jm\.joined_at <= jg\.created_at \+ INTERVAL '1 minute'\)`).
		WithArgs(groupID, 10).
		WillReturnRows(rows)

	events, err := repo.ListRecentActivity(context.Background(), groupID, 10)
	require.NoError(t, err)
	require.Len(t, events, 1)
	e := events[0]
	assert.Equal(t, models.ActivityTypeMemberJoined, e.Type)
	assert.Equal(t, "Sam", e.Title)
	assert.Equal(t, "member", e.EntityType)
	assert.Equal(t, joiner.String(), e.EntityId)
	require.NotNil(t, e.UserID)
	assert.Equal(t, joiner, *e.UserID)
	require.NotNil(t, e.UserName)
	assert.Equal(t, name, *e.UserName)
	assert.Nil(t, e.Context)
	assert.NoError(t, mock.ExpectationsWereMet())
}
