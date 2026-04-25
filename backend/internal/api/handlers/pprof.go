package handlers

import (
	"net/http"
	"net/http/pprof"

	"github.com/go-chi/chi/v5"
)

// NewPprofHandler returns a chi router exposing pprof endpoints guarded by AdminGuard.
func NewPprofHandler() http.Handler {
	r := chi.NewRouter()
	r.Use(AdminGuard)
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		pprof.Index(w, r)
	})
	r.Get("/cmdline", func(w http.ResponseWriter, r *http.Request) {
		pprof.Cmdline(w, r)
	})
	r.Get("/profile", func(w http.ResponseWriter, r *http.Request) {
		pprof.Profile(w, r)
	})
	r.Get("/symbol", func(w http.ResponseWriter, r *http.Request) {
		pprof.Symbol(w, r)
	})
	r.Get("/trace", func(w http.ResponseWriter, r *http.Request) {
		pprof.Trace(w, r)
	})
	r.Get("/goroutine", pprof.Handler("goroutine").ServeHTTP)
	r.Get("/heap", pprof.Handler("heap").ServeHTTP)
	r.Get("/threadcreate", pprof.Handler("threadcreate").ServeHTTP)
	r.Get("/block", pprof.Handler("block").ServeHTTP)
	r.Get("/mutex", pprof.Handler("mutex").ServeHTTP)
	return r
}
