package logger

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/rs/zerolog"
)

// Logger is a thin wrapper around zerolog.Logger.
type Logger struct {
	zerolog.Logger
}

// New creates a new Logger configured for the given environment.
//   - "dev" or "development": pretty console output, Debug level.
//   - anything else (e.g. "prod", "production"): JSON output, Info level.
func New(env string) *Logger {
	var zlog zerolog.Logger

	switch env {
	case "dev", "development":
		zerolog.SetGlobalLevel(zerolog.DebugLevel)
		output := zerolog.ConsoleWriter{
			Out:        os.Stdout,
			TimeFormat: time.RFC3339,
			NoColor:    false,
		}
		zlog = zerolog.New(output).With().Timestamp().Logger()
	default:
		zerolog.SetGlobalLevel(zerolog.InfoLevel)
		zlog = zerolog.New(os.Stdout).With().Timestamp().Logger()
	}

	return &Logger{Logger: zlog}
}

// WithError returns a new Logger with the error field attached.
func (l *Logger) WithError(err error) *Logger {
	return &Logger{Logger: l.With().AnErr(zerolog.ErrorFieldName, err).Logger()}
}

// contextKey is a private type to avoid context key collisions.
type contextKey struct{}

var loggerCtxKey = &contextKey{}

// ToContext injects the provided Logger into the context.
func ToContext(ctx context.Context, l *Logger) context.Context {
	return context.WithValue(ctx, loggerCtxKey, l)
}

// FromContext retrieves the Logger from the context.
// If no Logger is present, a no-op logger is returned.
func FromContext(ctx context.Context) *Logger {
	if l, ok := ctx.Value(loggerCtxKey).(*Logger); ok {
		return l
	}
	nop := zerolog.Nop()
	return &Logger{Logger: nop}
}

// Middleware returns an HTTP middleware that injects a request-scoped Logger
// into the request context. The logger is enriched with the request ID (from
// the X-Request-ID header if present) and basic request metadata.
func Middleware(l *Logger) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			reqID := r.Header.Get("X-Request-ID")
			reqLogger := l.With().
				Str("request_id", reqID).
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Logger()

			next.ServeHTTP(w, r.WithContext(ToContext(r.Context(), &Logger{Logger: reqLogger})))
		})
	}
}
