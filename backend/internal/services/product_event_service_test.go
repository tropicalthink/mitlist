package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
)

type fakeProductEventStore struct {
	stored []models.ProductEvent
	err    error
}

func (f *fakeProductEventStore) InsertEvents(_ context.Context, events []models.ProductEvent) error {
	if f.err != nil {
		return f.err
	}
	f.stored = append(f.stored, events...)
	return nil
}

// fakeEventGroups answers membership from a map of group → creator, for the
// members listed in members.
type fakeEventGroups struct {
	creators map[uuid.UUID]uuid.UUID
	members  map[uuid.UUID][]uuid.UUID
	lookups  int
}

func (f *fakeEventGroups) GetGroupByIDForUser(_ context.Context, id, userID uuid.UUID) (*models.Group, error) {
	f.lookups++
	for _, m := range f.members[id] {
		if m == userID {
			return &models.Group{ID: id, CreatedBy: f.creators[id]}, nil
		}
	}
	return nil, errors.New("no rows")
}

func newEventService(store *fakeProductEventStore, groups *fakeEventGroups, now time.Time) *ProductEventService {
	svc := NewProductEventService(store, groups)
	svc.now = func() time.Time { return now }
	return svc
}

func TestProductEventService_RequiresAnIdentity(t *testing.T) {
	svc := newEventService(&fakeProductEventStore{}, &fakeEventGroups{}, time.Now())
	_, err := svc.Record(context.Background(), nil, nil, []ProductEventInput{{Name: "welcome_shown"}})
	var verr *api.ValidationError
	require.ErrorAs(t, err, &verr)
}

func TestProductEventService_RejectsOversizedBatches(t *testing.T) {
	svc := newEventService(&fakeProductEventStore{}, &fakeEventGroups{}, time.Now())
	install := uuid.New()
	events := make([]ProductEventInput, ProductEventMaxBatch+1)
	for i := range events {
		events[i] = ProductEventInput{Name: "welcome_shown"}
	}
	_, err := svc.Record(context.Background(), nil, &install, events)
	var verr *api.ValidationError
	require.ErrorAs(t, err, &verr)
}

func TestProductEventService_DropsUnknownNamesAndFreeTextProps(t *testing.T) {
	store := &fakeProductEventStore{}
	svc := newEventService(store, &fakeEventGroups{}, time.Now())
	install := uuid.New()

	n, err := svc.Record(context.Background(), nil, &install, []ProductEventInput{
		{Name: "tour_skipped", Props: map[string]string{"page": "2"}},
		{Name: "made_up_event"},
		{Name: "tour_skipped", Props: map[string]string{"page": "Sam Smith <sam@example.com>"}},
		{Name: "tour_skipped", Props: map[string]string{"Bad Key": "1"}},
	})
	require.NoError(t, err)
	assert.Equal(t, 1, n)
	require.Len(t, store.stored, 1)
	assert.Equal(t, "tour_skipped", store.stored[0].Name)
	assert.Equal(t, map[string]string{"page": "2"}, store.stored[0].Props)
	assert.Equal(t, &install, store.stored[0].InstallID)
	assert.Nil(t, store.stored[0].UserID)
}

func TestProductEventService_KeepsSaneTimestampsOnly(t *testing.T) {
	now := time.Date(2026, 10, 5, 12, 0, 0, 0, time.UTC)
	store := &fakeProductEventStore{}
	svc := newEventService(store, &fakeEventGroups{}, now)
	install := uuid.New()
	recent := now.Add(-time.Hour)
	stale := now.Add(-30 * 24 * time.Hour)
	future := now.Add(time.Hour)

	_, err := svc.Record(context.Background(), nil, &install, []ProductEventInput{
		{Name: "welcome_shown", OccurredAt: &recent},
		{Name: "welcome_shown", OccurredAt: &stale},
		{Name: "welcome_shown", OccurredAt: &future},
	})
	require.NoError(t, err)
	require.Len(t, store.stored, 3)
	assert.Equal(t, recent, store.stored[0].OccurredAt)
	assert.Equal(t, now, store.stored[1].OccurredAt)
	assert.Equal(t, now, store.stored[2].OccurredAt)
}

func TestProductEventService_AttachesHouseholdOnlyForMembers(t *testing.T) {
	creator, joiner, stranger := uuid.New(), uuid.New(), uuid.New()
	group := uuid.New()
	groups := &fakeEventGroups{
		creators: map[uuid.UUID]uuid.UUID{group: creator},
		members:  map[uuid.UUID][]uuid.UUID{group: {creator, joiner}},
	}

	record := func(user uuid.UUID) models.ProductEvent {
		store := &fakeProductEventStore{}
		svc := newEventService(store, groups, time.Now())
		_, err := svc.Record(context.Background(), &user, nil, []ProductEventInput{
			{Name: "first_item_added", GroupID: &group, Props: map[string]string{"kind": "chore"}},
		})
		require.NoError(t, err)
		require.Len(t, store.stored, 1)
		return store.stored[0]
	}

	byCreator := record(creator)
	assert.Equal(t, &group, byCreator.GroupID)
	assert.Equal(t, "creator", byCreator.Role)

	byJoiner := record(joiner)
	assert.Equal(t, "invitee", byJoiner.Role)

	// Someone outside the household keeps the event, without the household.
	byStranger := record(stranger)
	assert.Nil(t, byStranger.GroupID)
	assert.Empty(t, byStranger.Role)
}

func TestProductEventService_LooksUpEachHouseholdOnce(t *testing.T) {
	user, group := uuid.New(), uuid.New()
	groups := &fakeEventGroups{
		creators: map[uuid.UUID]uuid.UUID{group: user},
		members:  map[uuid.UUID][]uuid.UUID{group: {user}},
	}
	svc := newEventService(&fakeProductEventStore{}, groups, time.Now())
	_, err := svc.Record(context.Background(), &user, nil, []ProductEventInput{
		{Name: "home_needs_you_action", GroupID: &group, Props: map[string]string{"type": "chore"}},
		{Name: "home_needs_you_action", GroupID: &group, Props: map[string]string{"type": "money"}},
	})
	require.NoError(t, err)
	assert.Equal(t, 1, groups.lookups)
}

func TestProductEventService_StoreFailureIsReturned(t *testing.T) {
	install := uuid.New()
	svc := newEventService(&fakeProductEventStore{err: errors.New("down")}, &fakeEventGroups{}, time.Now())
	_, err := svc.Record(context.Background(), nil, &install, []ProductEventInput{{Name: "welcome_shown"}})
	assert.Error(t, err)
}
