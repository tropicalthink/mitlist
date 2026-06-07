package main

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/mitlist-app/mitlist/internal/api/handlers"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/container"
	"github.com/mitlist-app/mitlist/internal/db"
	"github.com/mitlist-app/mitlist/internal/jobs"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/redis"
	"github.com/mitlist-app/mitlist/internal/server"
	"github.com/mitlist-app/mitlist/internal/services"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		os.Stderr.WriteString("failed to load config: " + err.Error() + "\n")
		os.Exit(1)
	}
	cfg.LogMasked()

	log := logger.New(cfg.Environment)

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

	redisClient, err := redis.New(cfg)
	if err != nil {
		log.Fatal().Err(err).Msg("failed to connect to redis")
	}
	defer redisClient.Close()

	cnt := container.New(cfg, pool, redisClient, log)

	runner := jobs.NewRunner(pool, cnt.Push(), log)
	runner.RegisterAll()
	runner.Start()

	srv := server.New(cfg, cnt, runner)

	healthHandler := handlers.NewHealthHandler(pool, redisClient)
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
		if err := redisClient.Ping(ctx); err != nil {
			http.Error(w, "redis not ready", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
	})
	srv.Router().Mount("/internal/health", healthHandler)

	authHandler := handlers.NewAuthHandler(cfg, cnt.UserService(), cnt.GuestService(), cnt.OAuthService(), cnt.JWT(), cnt.Redis().Client())
	srv.Router().Route(cfg.APIPrefix+"/v1", func(r chi.Router) {
		authHandler.RegisterRoutes(r)

		// Public configuration endpoints
		r.Get("/vapid", handlers.NewVAPIDHandler(cfg).ServeHTTP)

		// OAuth (public initiation + callback)
		oauthHandler := handlers.NewOAuthHandler(cfg, cnt.OAuthService())
		r.Get("/oauth/google", oauthHandler.GetGoogle)
		r.Get("/oauth/google/callback", oauthHandler.GetGoogleCallback)
		r.Post("/oauth/google/callback", oauthHandler.PostGoogleCallback)
		r.Get("/oauth/apple", oauthHandler.GetApple)
		r.Get("/oauth/apple/callback", oauthHandler.GetAppleCallback)
		r.Post("/oauth/apple/callback", oauthHandler.PostAppleCallback)

		// Protected feature routes
		r.Group(func(r chi.Router) {
			r.Use(middleware.Auth(cnt.JWT(), cnt.UserService()))
			r.Use(middleware.UserRateLimit(cnt.Redis().Client()))

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

			// Recipes
			recipeScrapeSvc := services.NewRecipeScrapingService()
			recipeHandler := handlers.NewRecipeHandler(cnt.RecipeService(), recipeScrapeSvc, cnt.ListService())
			recipeHandler.RegisterRoutes(r)

			// Meal Plans
			mealPlanHandler := handlers.NewMealPlanHandler(cnt.MealPlanService())
		mealPlanHandler.RegisterRoutes(r)

		// Calendar
			calendarHandler := handlers.NewCalendarHandler(cnt.CalendarService())
			calendarHandler.RegisterRoutes(r)

			// Assistant
			assistantHandler := handlers.NewAssistantHandler(cnt.AssistantService())
		assistantHandler.RegisterRoutes(r)

		// Share Target
		shareHandler := handlers.NewShareHandler(cnt.ShareService())
		shareHandler.RegisterRoutes(r)
		})
	})

	if err := srv.Run(); err != nil {
		log.Fatal().Err(err).Msg("server shutdown error")
	}
}
