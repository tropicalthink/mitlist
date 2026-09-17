package jobs

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type fakeActivityDigestRepo struct {
	batches []activityNotificationBatch
	deleted []uuid.UUID
}

func (r *fakeActivityDigestRepo) ClaimDueActivityNotificationBatches(context.Context, time.Time, int) ([]activityNotificationBatch, error) {
	return r.batches, nil
}

func (r *fakeActivityDigestRepo) DeleteClaimedActivityNotificationBatch(_ context.Context, id uuid.UUID, _ time.Time) error {
	r.deleted = append(r.deleted, id)
	return nil
}

type capturedImmediateDispatch struct {
	groupID uuid.UUID
	actorID uuid.UUID
	nType   string
	title   string
	body    string
	payload models.NotificationPayload
	calls   int
	err     error
}

func (d *capturedImmediateDispatch) DispatchToGroupNow(_ context.Context, groupID, actorID uuid.UUID, nType, title, body string, payload models.NotificationPayload) error {
	d.calls++
	d.groupID, d.actorID, d.nType, d.title, d.body, d.payload = groupID, actorID, nType, title, body, payload
	return d.err
}

func mealPlanPayloadJSON(t *testing.T, id uuid.UUID) json.RawMessage {
	t.Helper()
	data, err := json.Marshal(models.NotificationPayload{
		Screen: models.ScreenMealPlan, EntityType: models.EntityTypeMealPlan,
		ID: id.String(), ActorName: "Mina", EntityName: "Meal plan", ItemName: "Tacos",
		Copy: models.NewNotificationCopy(models.NotificationTemplateMealPlanChanged, map[string]string{
			"actor_name": "Mina", "group_name": "Flatmates",
		}),
	})
	require.NoError(t, err)
	return data
}

func TestActivityNotificationDigest_Run(t *testing.T) {
	groupID, actorID, mealPlanID := uuid.New(), uuid.New(), uuid.New()

	t.Run("replays a single event exactly as it would have been sent", func(t *testing.T) {
		batchID := uuid.New()
		repo := &fakeActivityDigestRepo{batches: []activityNotificationBatch{{
			ID: batchID, GroupID: groupID, ActorID: actorID, Type: models.NotificationTypeMealPlanChanged,
			ActorName: "Mina", LastItemName: "Tacos", ItemNames: []string{"Tacos"}, ItemCount: 1,
			Title: "Meal plan updated", Body: "Mina updated the meal plan in Flatmates.",
			Payload: mealPlanPayloadJSON(t, mealPlanID), GroupName: "Flatmates", UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedImmediateDispatch{}
		job := &ActivityNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		assert.Equal(t, 1, dispatcher.calls)
		assert.Equal(t, groupID, dispatcher.groupID)
		assert.Equal(t, actorID, dispatcher.actorID)
		assert.Equal(t, models.NotificationTypeMealPlanChanged, dispatcher.nType)
		assert.Equal(t, "Meal plan updated", dispatcher.title)
		assert.Equal(t, "Mina updated the meal plan in Flatmates.", dispatcher.body)
		assert.Equal(t, mealPlanID.String(), dispatcher.payload.ID)
		assert.Equal(t, groupID.String(), dispatcher.payload.GroupID)
		require.NotNil(t, dispatcher.payload.Copy)
		assert.Equal(t, models.NotificationTemplateMealPlanChanged, dispatcher.payload.Copy.Template)
		assert.Equal(t, []uuid.UUID{batchID}, repo.deleted)
	})

	t.Run("summarizes a burst of meal plan edits with the recipes", func(t *testing.T) {
		repo := &fakeActivityDigestRepo{batches: []activityNotificationBatch{{
			ID: uuid.New(), GroupID: groupID, ActorID: actorID, Type: models.NotificationTypeMealPlanChanged,
			ActorName: "Mina", LastItemName: "Tacos", ItemNames: []string{"Pasta", "Curry", "Tacos"}, ItemCount: 5,
			Title: "Meal plan updated", Body: "Mina updated the meal plan in Flatmates.",
			Payload: mealPlanPayloadJSON(t, mealPlanID), GroupName: "Flatmates", UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedImmediateDispatch{}
		job := &ActivityNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		assert.Equal(t, models.NotificationTypeMealPlanChanged, dispatcher.nType)
		assert.Equal(t, "Meal plan updated", dispatcher.title)
		assert.Equal(t, "Mina made 5 changes to the meal plan in Flatmates: Pasta, Curry, Tacos, …", dispatcher.body)
		assert.Equal(t, models.ScreenMealPlan, dispatcher.payload.Screen)
		assert.Equal(t, mealPlanID.String(), dispatcher.payload.ID)
		require.NotNil(t, dispatcher.payload.Copy)
		assert.Equal(t, models.NotificationTemplateMealPlanChangedDigest, dispatcher.payload.Copy.Template)
		assert.Equal(t, "5", dispatcher.payload.Copy.Params["change_count"])
		assert.Equal(t, "Pasta, Curry, Tacos, …", dispatcher.payload.Copy.Params["item_names"])
		assert.Equal(t, "Flatmates", dispatcher.payload.Copy.Params["group_name"])
	})

	t.Run("summarizes a run of expenses", func(t *testing.T) {
		expenseID := uuid.New()
		payload, err := json.Marshal(models.NotificationPayload{
			Screen: models.ScreenExpenseDetail, EntityType: models.EntityTypeExpense,
			ID: expenseID.String(), ActorName: "Mina", EntityName: "Pizza",
		})
		require.NoError(t, err)
		repo := &fakeActivityDigestRepo{batches: []activityNotificationBatch{{
			ID: uuid.New(), GroupID: groupID, ActorID: actorID, Type: models.NotificationTypeExpenseCreated,
			ActorName: "Mina", LastItemName: "Pizza", ItemNames: []string{"Groceries", "Petrol", "Pizza"}, ItemCount: 3,
			Title: "Expense added", Body: "Mina added Pizza in Flatmates.",
			Payload: payload, GroupName: "Flatmates", UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedImmediateDispatch{}
		job := &ActivityNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		assert.Equal(t, models.NotificationTypeExpenseCreated, dispatcher.nType)
		assert.Equal(t, "Expenses added", dispatcher.title)
		assert.Equal(t, "Mina added 3 expenses in Flatmates: Groceries, Petrol, Pizza", dispatcher.body)
		assert.Equal(t, models.ScreenExpenseDetail, dispatcher.payload.Screen)
		assert.Equal(t, expenseID.String(), dispatcher.payload.ID)
		require.NotNil(t, dispatcher.payload.Copy)
		assert.Equal(t, models.NotificationTemplateExpensesCreatedDigest, dispatcher.payload.Copy.Template)
		assert.Equal(t, "3", dispatcher.payload.Copy.Params["expense_count"])
		assert.Equal(t, "Groceries, Petrol, Pizza", dispatcher.payload.Copy.Params["expense_names"])
	})

	t.Run("keeps a claimed batch when dispatch fails", func(t *testing.T) {
		repo := &fakeActivityDigestRepo{batches: []activityNotificationBatch{{
			ID: uuid.New(), GroupID: groupID, ActorID: actorID, Type: models.NotificationTypeMealPlanChanged,
			ActorName: "Mina", ItemCount: 2, Title: "Meal plan updated", Body: "b",
			Payload: mealPlanPayloadJSON(t, mealPlanID), GroupName: "Flatmates", UpdatedAt: time.Now(),
		}}}
		dispatcher := &capturedImmediateDispatch{err: errors.New("delivery failed")}
		job := &ActivityNotificationDigest{repo: repo, dispatcher: dispatcher, log: logger.New("test")}

		job.Run()

		require.Empty(t, repo.deleted)
		assert.Equal(t, 1, dispatcher.calls)
	})
}
