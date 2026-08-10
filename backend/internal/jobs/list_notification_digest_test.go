package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fakeListDigestRepo struct {
	batches []listNotificationBatch
	deleted []uuid.UUID
}

func (r *fakeListDigestRepo) ClaimDueListNotificationBatches(context.Context, time.Time, int) ([]listNotificationBatch, error) {
	return r.batches, nil
}

func (r *fakeListDigestRepo) DeleteClaimedListNotificationBatch(_ context.Context, id uuid.UUID, _ time.Time) error {
	r.deleted = append(r.deleted, id)
	return nil
}

type capturedDispatch struct {
	title   string
	body    string
	nType   string
	payload models.NotificationPayload
	err     error
}

func (d *capturedDispatch) DispatchToGroup(_ context.Context, _, _ uuid.UUID, nType, title, body string, payload models.NotificationPayload) error {
	d.title, d.body, d.nType, d.payload = title, body, nType, payload
	return d.err
}

func (d *capturedDispatch) DispatchToUsers(context.Context, []uuid.UUID, uuid.UUID, string, string, string, models.NotificationPayload) error {
	return nil
}

func TestListNotificationDigest_Run(t *testing.T) {
	t.Run("summarizes a burst with actor list and household", func(t *testing.T) {
		batchID := uuid.New()
		repo := &fakeListDigestRepo{batches: []listNotificationBatch{{
			ID: batchID, GroupID: uuid.New(), ActorID: uuid.New(), ListID: uuid.New(),
			ActorName: "Mina", ListName: "Groceries", LastItemName: "Milk",
			GroupName: "Flatmates", ItemCount: 4, UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedDispatch{}
		job := &ListNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		assert.Equal(t, "Groceries updated", dispatcher.title)
		assert.Equal(t, "Mina added 4 items to Groceries in Flatmates.", dispatcher.body)
		assert.Equal(t, models.NotificationTypeListItemsAddedDigest, dispatcher.nType)
		assert.Equal(t, models.ScreenListDetail, dispatcher.payload.Screen)
		require.NotNil(t, dispatcher.payload.Copy)
		assert.Equal(t, models.NotificationTemplateListItemsAdded, dispatcher.payload.Copy.Template)
		assert.Equal(t, "4", dispatcher.payload.Copy.Params["item_count"])
		assert.Equal(t, []uuid.UUID{batchID}, repo.deleted)
	})

	t.Run("keeps a claimed batch when dispatch fails", func(t *testing.T) {
		repo := &fakeListDigestRepo{batches: []listNotificationBatch{{
			ID: uuid.New(), GroupID: uuid.New(), ActorID: uuid.New(), ListID: uuid.New(),
			ActorName: "Mina", ListName: "Groceries", LastItemName: "Milk",
			GroupName: "Flatmates", ItemCount: 1, UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedDispatch{err: errors.New("delivery failed")}
		job := &ListNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		require.Empty(t, repo.deleted)
		assert.Equal(t, "Mina added Milk to Groceries in Flatmates.", dispatcher.body)
	})
}
