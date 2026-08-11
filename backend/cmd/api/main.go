package main

import (
	"context"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/api/handlers"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/container"
	"github.com/mitlist-app/mitlist/internal/db"
	"github.com/mitlist-app/mitlist/internal/jobs"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/observability"
	"github.com/mitlist-app/mitlist/internal/server"
	"github.com/mitlist-app/mitlist/internal/services"
	appcheckservice "github.com/mitlist-app/mitlist/internal/services/appcheck"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// version is the build version reported to Sentry/GlitchTip as the release.
// Override at build time with: -ldflags="-X main.version=$VERSION".
// A SENTRY_RELEASE env var takes precedence over this at runtime.
var version = "dev"

func main() {
	cfg, err := config.Load()
	if err != nil {
		os.Stderr.WriteString("failed to load config: " + err.Error() + "\n")
		os.Exit(1)
	}
	cfg.LogMasked()
	cfg.LogIntegrationStatus()

	// Initialize error reporting before the logger so the logger's Sentry bridge
	// can attach to a live client.
	flushSentry, sentryOn, sentryErr := observability.Init(cfg, version)
	defer flushSentry()

	var logOpts []logger.Option
	if sentryOn {
		logOpts = append(logOpts, logger.WithSentryBridge())
	}
	log := logger.New(cfg.Environment, logOpts...)
	if sentryErr != nil {
		log.Warn().Err(sentryErr).Msg("sentry initialization failed; continuing without error reporting")
	}

	pool, err := db.New(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to database")
	}
	defer db.Close(pool)

	if cfg.RunMigrationsOnStartup {
		if err := db.RunMigrations(cfg, log); err != nil {
			log.Fatal().Err(err).Msg("failed to run startup migrations")
		}
	}

	cnt := container.New(cfg, pool, log)

	runner := jobs.NewRunnerWithDispatcher(pool, cnt.NotificationService(), log)
	runner.EnableSentryMonitoring(sentryOn)
	runner.RegisterAll()
	runner.RegisterAttachmentCleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
		defer cancel()
		cleaned, err := cnt.AttachmentService().CleanupExpiredUploads(ctx)
		if err != nil {
			log.Error().Err(err).Msg("attachment cleanup failed")
			return
		}
		if cleaned > 0 {
			log.Info().Int("cleaned", cleaned).Msg("expired attachments cleaned")
		}
	})
	runner.Start()

	srv := server.New(cfg, cnt, runner)

	healthHandler := handlers.NewHealthHandler(pool)
	srv.Router().Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	srv.Router().Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		if err := pool.Ping(ctx); err != nil {
			http.Error(w, "db not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	srv.Router().Mount("/internal/health", healthHandler)

	// Polar billing webhook. Public (signature-verified, not JWT-gated) since
	// Polar calls this directly.
	polarWebhookHandler, err := handlers.NewPolarWebhookHandler(cfg, cnt.BillingService(), log)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to initialize polar webhook handler")
	}
	polarWebhookHandler.RegisterRoutes(srv.Router())

	// Operational endpoints, admin-guarded (IP allowlist via DEBUG_ALLOWLIST or
	// HTTP Basic via ADMIN_USER/ADMIN_PASS). pprof and debug wrap AdminGuard
	// internally; metrics is wrapped here.
	srv.Router().Handle("/metrics", handlers.AdminGuard(handlers.NewMetricsHandler()))
	srv.Router().Mount("/debug/pprof", handlers.NewPprofHandler())
	srv.Router().Mount("/internal/debug", handlers.NewDebugHandler(cfg, srv.Router()).Routes())

	// Canonicalize legacy/API invite URLs to the Flutter web app. The app host
	// serves the same /join/<code> route to browsers and is covered by the native
	// association files for Android App Links and iOS Universal Links.
	srv.Router().Get("/join/{code}", func(w http.ResponseWriter, r *http.Request) {
		code := chi.URLParam(r, "code")
		if len(code) < 4 {
			http.Error(w, "invalid invite code", http.StatusBadRequest)
			return
		}
		target := strings.TrimRight(cfg.FrontendURL, "/") + "/join/" + url.PathEscape(code)
		http.Redirect(w, r, target, http.StatusFound)
	})

	appCheckVerifier, err := appcheckservice.New(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to initialize Firebase App Check verifier")
	}
	authHandler := handlers.NewAuthHandler(cfg, cnt.UserService(), cnt.GuestService(), cnt.OAuthService(), cnt.JWT(), appCheckVerifier)
	srv.Router().Route(cfg.APIPrefix+"/v1", func(r chi.Router) {
		authHandler.RegisterRoutes(r)

		// Public configuration endpoints
		r.Get("/vapid", handlers.NewVAPIDHandler(cfg).ServeHTTP)

		// OAuth (public initiation + callback)
		oauthHandler := handlers.NewOAuthHandler(cfg, cnt.OAuthService())
		r.Get("/oauth/providers", oauthHandler.GetProviders)
		r.Get("/oauth/google", oauthHandler.GetGoogle)
		r.Get("/oauth/google/callback", oauthHandler.GetGoogleCallback)
		r.Post("/oauth/google/callback", oauthHandler.PostGoogleCallback)
		r.Get("/oauth/apple", oauthHandler.GetApple)
		r.Get("/oauth/apple/callback", oauthHandler.GetAppleCallback)
		r.Post("/oauth/apple/callback", oauthHandler.PostAppleCallback)
		r.Post("/oauth/handoff/exchange", oauthHandler.ExchangeHandoff)

		// SSE (Server-Sent Events) — auth handled inside the handler to skip UserRateLimit
		sseHandler := handlers.NewSSEHandler(cnt.SSEHub(), cnt.JWT(), cnt.UserService(), cnt.GroupRepo())
		sseHandler.RegisterRoutes(r)

		// Protected feature routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(cnt.JWT(), cnt.UserService()))
			r.Use(middleware.UserRateLimit())
			r.Use(middleware.Idempotency(cnt.DB()))

			// Notifications
			notificationHandler := handlers.NewNotificationHandler(cnt.NotificationService())
			notificationHandler.RegisterRoutes(r)

			// Activity logs
			activityHandler := handlers.NewActivityHandler(cnt.ActivityService())
			activityHandler.RegisterRoutes(r)

			// Pinwall
			pinwallHandler := handlers.NewPinwallHandler(cnt.PinwallService())
			pinwallHandler.RegisterRoutes(r)

			pinwallMediaHandler := handlers.NewPinwallMediaHandler(cnt.PinwallMediaService())
			pinwallMediaHandler.RegisterRoutes(r)

			// Attachments
			attachmentHandler := handlers.NewAttachmentHandler(cnt.AttachmentService())
			attachmentHandler.RegisterRoutes(r)

			// Groups
			groupHandler := handlers.NewGroupHandler(cnt.GroupService())
			groupHandler.RegisterRoutes(r)

			// Billing (household premium)
			billingHandler := handlers.NewBillingHandler(cnt.BillingService())
			billingHandler.RegisterRoutes(r)

			// Lists
			listHandler := handlers.NewListHandler(cnt.ListService(), cnt.FinanceService())
			listItemPhotoHandler := handlers.NewListItemPhotoHandler(cnt.ListItemPhotoService())
			listHandler.RegisterRoutes(r)
			listItemPhotoHandler.RegisterRoutes(r)

			// Templates
			templateHandler := handlers.NewTemplateHandler(cnt.TemplateService())
			templateHandler.RegisterRoutes(r)

			// Chores
			choreHandler := handlers.NewChoreHandler(cnt.ChoreService())
			choreHandler.RegisterRoutes(r)

			// Finance
			financeHandler := handlers.NewFinanceHandler(cnt.FinanceService())
			receiptHandler := handlers.NewExpenseReceiptHandler(cnt.ExpenseReceiptService())
			financeHandler.RegisterRoutes(r)
			receiptHandler.RegisterRoutes(r)

			// FX rate advisory (opt-in; disabled when FX_RATE_API_URL is unset)
			fxHandler := handlers.NewFxHandler(cnt.FxService())
			fxHandler.RegisterRoutes(r)

			// Recipes
			recipeScrapeSvc := services.NewRecipeScrapingService()
			recipeHandler := handlers.NewRecipeHandler(cnt.RecipeService(), recipeScrapeSvc, cnt.ListService())
			recipeHandler.SetGroceryService(cnt.GroceryService())
			recipeHandler.RegisterRoutes(r)

			// Meal Plans
			mealPlanHandler := handlers.NewMealPlanHandler(cnt.MealPlanService())
			mealPlanHandler.RegisterRoutes(r)

			// Calendar
			calendarHandler := handlers.NewCalendarHandler(cnt.CalendarService())
			calendarHandler.RegisterRoutes(r)

			// Grocery graph sync
			groceryHandler := handlers.NewGroceryHandler(cnt.GroceryService())
			groceryHandler.RegisterRoutes(r)

			// Share Target
			shareHandler := handlers.NewShareHandler(cnt.ShareService())
			shareHandler.RegisterRoutes(r)
		})
	})

	if err := srv.Run(); err != nil {
		log.Fatal().Err(err).Msg("server shutdown error")
	}
}
