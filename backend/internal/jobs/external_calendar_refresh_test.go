package jobs

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/mitlist-app/mitlist/pkg/logger"
)

type fakeCalendarRefresher struct {
	refreshed, trimmed int
	refreshErr         error
}

func (f *fakeCalendarRefresher) RefreshDueICS(ctx context.Context) (int, error) {
	f.refreshed++
	if _, ok := ctx.Deadline(); !ok {
		panic("refresh must run with a deadline")
	}
	return 3, f.refreshErr
}

func (f *fakeCalendarRefresher) TrimEvents(context.Context) (int64, error) {
	f.trimmed++
	return 7, nil
}

func TestExternalCalendarRefresh_RefreshesAndTrims(t *testing.T) {
	f := &fakeCalendarRefresher{}
	NewExternalCalendarRefresh(f, logger.New("test")).Run()
	assert.Equal(t, 1, f.refreshed)
	assert.Equal(t, 1, f.trimmed)
}

func TestExternalCalendarRefresh_TrimsEvenWhenRefreshFails(t *testing.T) {
	f := &fakeCalendarRefresher{refreshErr: errors.New("db down")}
	NewExternalCalendarRefresh(f, logger.New("test")).Run()
	assert.Equal(t, 1, f.trimmed)
}

func TestRunner_RegisterExternalCalendarRefresh(t *testing.T) {
	r := NewRunner(nil, nil, logger.New("test"))
	r.RegisterAll()
	r.RegisterExternalCalendarRefresh(NewExternalCalendarRefresh(&fakeCalendarRefresher{}, logger.New("test")))
	r.RegisterExternalCalendarRefresh(nil)

	assert.Len(t, r.jobs, 9)
	last := r.jobs[len(r.jobs)-1]
	assert.Equal(t, "external-calendar-refresh", last.Name)
	assert.Equal(t, "*/30 * * * *", last.Schedule)
	assert.True(t, last.Enabled)
	assert.Nil(t, NewExternalCalendarRefresh(nil, logger.New("test")))
}
