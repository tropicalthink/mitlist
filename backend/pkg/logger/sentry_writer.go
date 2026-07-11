package logger

import (
	"encoding/json"
	"time"

	"github.com/getsentry/sentry-go"
	"github.com/rs/zerolog"
)

// SentrySkipField, when set truthy on a zerolog event, tells the Sentry bridge
// to NOT forward that event. Use it for logs that are already captured with
// higher fidelity elsewhere (HTTP-handler panics via sentryhttp, handled 500s
// via api.WriteError, job panics via the runner) to avoid duplicate issues.
const SentrySkipField = "_sentry_skip"

// mappedFields are handled explicitly and kept out of the generic context bag.
var mappedFields = map[string]struct{}{
	zerolog.LevelFieldName:     {}, // "level"
	zerolog.MessageFieldName:   {}, // "message"
	zerolog.ErrorFieldName:     {}, // "error"
	zerolog.TimestampFieldName: {}, // "time"
	SentrySkipField:            {},
	"user_id":                  {},
}

// tagFields are promoted to searchable Sentry tags.
var tagFields = map[string]struct{}{
	"request_id": {},
	"method":     {},
	"path":       {},
	"job":        {},
}

// sentryWriter is a zerolog.LevelWriter that forwards Error-and-above events to
// Sentry/GlitchTip. It parses the serialized JSON event so structured fields
// survive as tags/context, which a plain zerolog.Hook cannot access.
type sentryWriter struct{}

func newSentryWriter() zerolog.LevelWriter { return sentryWriter{} }

// Write handles level-less writes (zerolog fallback path); nothing to capture.
func (sentryWriter) Write(p []byte) (int, error) { return len(p), nil }

func (w sentryWriter) WriteLevel(level zerolog.Level, p []byte) (int, error) {
	n := len(p)
	if level < zerolog.ErrorLevel {
		return n, nil
	}
	w.capture(level, p)
	// zerolog's Fatal/Panic paths call os.Exit / panic immediately after this
	// write returns — before main's deferred sentry.Flush can run — so flush
	// synchronously here to make sure the final event is actually delivered.
	if level >= zerolog.FatalLevel {
		sentry.Flush(2 * time.Second)
	}
	return n, nil
}

func (sentryWriter) capture(level zerolog.Level, p []byte) {
	var fields map[string]interface{}
	if err := json.Unmarshal(p, &fields); err != nil {
		return
	}
	if v, ok := fields[SentrySkipField]; ok {
		if b, isBool := v.(bool); !isBool || b {
			return
		}
	}

	msg, _ := fields[zerolog.MessageFieldName].(string)
	errStr, _ := fields[zerolog.ErrorFieldName].(string)

	event := sentry.NewEvent()
	event.Level = sentryLevel(level)
	event.Message = msg
	event.Logger = "zerolog"

	// Synthesize an exception so GlitchTip renders a grouped issue (by type +
	// value) instead of a flat log line. Group by the error value when present,
	// falling back to the message.
	value := errStr
	if value == "" {
		value = msg
	}
	if value != "" {
		exType := "error"
		if errStr != "" && msg != "" {
			exType = msg
		}
		event.Exception = []sentry.Exception{{
			Type:       exType,
			Value:      value,
			Stacktrace: sentry.NewStacktrace(),
		}}
	}

	logCtx := sentry.Context{}
	for k, v := range fields {
		if _, mapped := mappedFields[k]; mapped {
			continue
		}
		if _, isTag := tagFields[k]; isTag {
			s := stringify(v)
			event.Tags[k] = s
			if k == "path" {
				event.Transaction = s
			}
			continue
		}
		logCtx[k] = v
	}
	if uid, ok := fields["user_id"].(string); ok && uid != "" && uid != "anonymous" {
		event.User = sentry.User{ID: uid}
	}
	if len(logCtx) > 0 {
		event.Contexts["log"] = logCtx
	}

	sentry.CaptureEvent(event)
}

func stringify(v interface{}) string {
	switch t := v.(type) {
	case string:
		return t
	case nil:
		return ""
	default:
		b, err := json.Marshal(v)
		if err != nil {
			return ""
		}
		return string(b)
	}
}

func sentryLevel(l zerolog.Level) sentry.Level {
	switch l {
	case zerolog.WarnLevel:
		return sentry.LevelWarning
	case zerolog.FatalLevel, zerolog.PanicLevel:
		return sentry.LevelFatal
	default:
		return sentry.LevelError
	}
}
