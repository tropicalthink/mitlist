package main

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

func TestRecordingChoreRepo_DryRunDoesNotWrite(t *testing.T) {
	inner := new(mocks.MockChoreRepo)
	repo := &recordingChoreRepo{ChoreRepo: inner, dryRun: true}

	err := repo.BulkUpdateRotationStates(context.Background(), []models.ChoreRotationState{
		{ID: uuid.New(), ChoreID: uuid.New(), MemberOrder: []uuid.UUID{uuid.New()}},
	})
	require.NoError(t, err)
	assert.Equal(t, 1, repo.changed)
	inner.AssertNotCalled(t, "BulkUpdateRotationStates")
}

func TestRecordingChoreRepo_WritesThrough(t *testing.T) {
	ctx := context.Background()
	inner := new(mocks.MockChoreRepo)
	repo := &recordingChoreRepo{ChoreRepo: inner}
	states := []models.ChoreRotationState{{ID: uuid.New(), ChoreID: uuid.New()}}
	inner.On("BulkUpdateRotationStates", ctx, states).Return(nil)

	err := repo.BulkUpdateRotationStates(ctx, states)
	require.NoError(t, err)
	assert.Equal(t, 1, repo.changed)
	inner.AssertExpectations(t)
}
