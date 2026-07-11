package middleware

import (
	"net/http"
	"time"

	"github.com/mitlist-app/mitlist/pkg/logger"
)

// LoggingMiddleware logs structured request details using zerolog.
func LoggingMiddleware() func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			rec := &logRecorder{ResponseWriter: w, statusCode: http.StatusOK}
			next.ServeHTTP(rec, r)
			duration := time.Since(start)

			log := logger.FromContext(r.Context())
			reqID := r.Header.Get("X-Request-ID")
			if reqID == "" {
				reqID = "-"
			}
			userID := UserIDFromContext(r.Context())
			if userID == "" {
				userID = "anonymous"
			}

			event := log.Info().
				Str("method", r.Method).
				Str("path", r.URL.Path).
				Int("status", rec.statusCode).
				Dur("duration", duration).
				Str("request_id", reqID).
				Str("user_id", userID)

			if rec.statusCode >= 500 {
				event = log.Error().
					// The underlying error is captured richer via api.WriteError;
					// skip the bridge so this summary line doesn't collapse every
					// 5xx into one badly-grouped GlitchTip issue.
					Bool(logger.SentrySkipField, true).
					Str("method", r.Method).
					Str("path", r.URL.Path).
					Int("status", rec.statusCode).
					Dur("duration", duration).
					Str("request_id", reqID).
					Str("user_id", userID)
			} else if rec.statusCode >= 400 {
				event = log.Warn().
					Str("method", r.Method).
					Str("path", r.URL.Path).
					Int("status", rec.statusCode).
					Dur("duration", duration).
					Str("request_id", reqID).
					Str("user_id", userID)
			}

			event.Msg("http_request")
		})
	}
}

type logRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (lr *logRecorder) WriteHeader(code int) {
	lr.statusCode = code
	lr.ResponseWriter.WriteHeader(code)
}

// Flush delegates to the underlying writer so SSE/streaming handlers work.
func (lr *logRecorder) Flush() {
	if f, ok := lr.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// Unwrap exposes the underlying writer for http.NewResponseController.
func (lr *logRecorder) Unwrap() http.ResponseWriter {
	return lr.ResponseWriter
}
