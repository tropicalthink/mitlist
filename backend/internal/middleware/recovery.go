package middleware

import (
	"net/http"
	"runtime/debug"

	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Recovery recovers from panics and logs the stack trace.
func Recovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				logger.FromContext(r.Context()).Error().
					// sentryhttp (inner middleware) already captured this panic
					// with request context and a stack; skip the bridge to avoid
					// a duplicate GlitchTip issue.
					Bool(logger.SentrySkipField, true).
					Interface("panic", rec).
					Str("stack", string(debug.Stack())).
					Msg("panic recovered")
				http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}
