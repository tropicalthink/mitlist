package jobs

import (
	"context"
	"time"

	"github.com/mitlist-app/mitlist/pkg/logger"
)

// ExternalCalendarRefresher is the part of the external calendar service
// the refresh job drives.
type ExternalCalendarRefresher interface {
	RefreshDueICS(ctx context.Context) (int, error)
	TrimEvents(ctx context.Context) (int64, error)
}

// ExternalCalendarRefresh polls members' ICS subscriptions that are due
// (each records its own outcome and backs off when its feed keeps failing)
// and trims synced events that left the stored window.
type ExternalCalendarRefresh struct {
	svc     ExternalCalendarRefresher
	log     *logger.Logger
	timeout time.Duration
}

func NewExternalCalendarRefresh(svc ExternalCalendarRefresher, log *logger.Logger) *ExternalCalendarRefresh {
	if svc == nil {
		return nil
	}
	return &ExternalCalendarRefresh{svc: svc, log: log, timeout: 25 * time.Minute}
}

func (j *ExternalCalendarRefresh) Run() {
	ctx, cancel := context.WithTimeout(context.Background(), j.timeout)
	defer cancel()
	n, err := j.svc.RefreshDueICS(ctx)
	if err != nil {
		j.log.Error().Err(err).Msg("external calendar refresh failed")
	}
	trimmed, err := j.svc.TrimEvents(ctx)
	if err != nil {
		j.log.Error().Err(err).Msg("external calendar trim failed")
	}
	if n > 0 || trimmed > 0 {
		j.log.Info().Int("feeds", n).Int64("trimmed", trimmed).Msg("external calendars refreshed")
	}
}
