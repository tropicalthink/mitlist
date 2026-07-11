// Package observability wires the backend into Sentry/GlitchTip for error
// reporting and (optionally) performance tracing. It is a no-op unless a DSN is
// configured, so a fresh self-host runs cleanly without it.
package observability

import (
	"strings"
	"time"

	"github.com/getsentry/sentry-go"

	"github.com/mitlist-app/mitlist/internal/config"
)

// sensitiveHeaders are redacted from event request data before sending, so
// tokens and cookies never leave the host. This is defence-in-depth on top of
// SendDefaultPII=false (which already omits most of this).
var sensitiveHeaders = map[string]struct{}{
	"authorization":       {},
	"proxy-authorization": {},
	"cookie":              {},
	"set-cookie":          {},
	"x-csrf-token":        {},
}

// Init configures the Sentry/GlitchTip SDK from config. It returns a flush
// function to defer on shutdown, whether reporting was enabled, and any init
// error (so the caller can log it once the logger exists). An empty DSN
// disables reporting and returns a no-op flush.
func Init(cfg *config.Config, version string) (flush func(), enabled bool, err error) {
	noop := func() {}
	if cfg.SentryDSN == "" {
		return noop, false, nil
	}

	release := cfg.SentryRelease
	if release == "" {
		release = version
	}

	initErr := sentry.Init(sentry.ClientOptions{
		Dsn:              cfg.SentryDSN,
		Environment:      cfg.Environment,
		Release:          release,
		ServerName:       cfg.SentryServerName,
		Debug:            cfg.SentryDebug,
		AttachStacktrace: true,
		EnableTracing:    cfg.SentryTracesSampleRate > 0,
		TracesSampleRate: cfg.SentryTracesSampleRate,
		SendDefaultPII:   false,
		BeforeSend:       scrubEvent,
	})
	if initErr != nil {
		return noop, false, initErr
	}

	return func() { sentry.Flush(2 * time.Second) }, true, nil
}

// scrubEvent redacts sensitive request headers/cookies before an event is sent.
func scrubEvent(event *sentry.Event, _ *sentry.EventHint) *sentry.Event {
	if event.Request == nil {
		return event
	}
	for name := range event.Request.Headers {
		if _, ok := sensitiveHeaders[strings.ToLower(name)]; ok {
			event.Request.Headers[name] = "[redacted]"
		}
	}
	if event.Request.Cookies != "" {
		event.Request.Cookies = "[redacted]"
	}
	return event
}
