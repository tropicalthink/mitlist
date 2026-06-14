package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

type flushRecorder struct {
	*httptest.ResponseRecorder
	flushed bool
}

func (f *flushRecorder) Flush() {
	f.flushed = true
}

func TestLoggingMiddlewarePreservesFlusher(t *testing.T) {
	t.Parallel()

	inner := &flushRecorder{ResponseRecorder: httptest.NewRecorder()}
	var sawFlusher bool

	handler := LoggingMiddleware()(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f, ok := w.(http.Flusher)
		sawFlusher = ok
		if ok {
			f.Flush()
		}
	}))

	handler.ServeHTTP(inner, httptest.NewRequest(http.MethodGet, "/api/v1/events", nil))

	if !sawFlusher {
		t.Fatal("expected wrapped ResponseWriter to implement http.Flusher")
	}
	if !inner.flushed {
		t.Fatal("expected Flush to delegate to underlying writer")
	}
}
