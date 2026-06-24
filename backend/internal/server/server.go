package server

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	sentryhttp "github.com/getsentry/sentry-go/http"
	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/container"
	"github.com/mitlist-app/mitlist/internal/jobs"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Server wraps the chi router and HTTP server with graceful shutdown.
type Server struct {
	cfg    *config.Config
	router *chi.Mux
	log    *logger.Logger
	http   *http.Server
	runner *jobs.Runner
}

// New creates a configured Server with all global middleware applied.
func New(cfg *config.Config, cnt *container.Container, runner *jobs.Runner) *Server {
	r := chi.NewRouter()

	if cfg.TrustedProxies != "" {
		middleware.SetTrustedProxies(strings.Split(cfg.TrustedProxies, ","))
	}
	r.Use(middleware.RealIPFromTrusted)

	// Inject logger into context — must be early so downstream middleware/handlers can use it
	r.Use(logger.Middleware(cnt.Logger()))

	// Custom middleware stack
	r.Use(middleware.RequestID)
	r.Use(middleware.Recovery)
	r.Use(middleware.SecurityHeaders)
	r.Use(middleware.CorsMiddleware(cfg.FrontendURL, cfg.Environment))
	r.Use(middleware.RateLimit(cnt.Redis().Client(), cfg.APIPrefix))
	r.Use(middleware.LoggingMiddleware())
	r.Use(sentryhttp.New(sentryhttp.Options{Repanic: true}).Handle)

	port := cfg.Port
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 15 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20, // 1MB
	}

	return &Server{
		cfg:    cfg,
		router: r,
		log:    cnt.Logger(),
		http:   srv,
		runner: runner,
	}
}

// Router exposes the chi mux so handlers can be mounted.
func (s *Server) Router() chi.Router {
	return s.router
}

// Run starts the HTTP server and blocks until a shutdown signal is received.
func (s *Server) Run() error {
	s.log.Info().Str("addr", s.http.Addr).Msg("starting http server")

	go func() {
		if err := s.http.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			s.log.Fatal().Err(err).Msg("http server error")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	s.log.Info().Msg("shutting down http server")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if s.runner != nil {
		s.runner.Stop(ctx)
	}
	return s.http.Shutdown(ctx)
}
