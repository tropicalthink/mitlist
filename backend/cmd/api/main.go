package main

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/yourorg/mitlist/internal/api/handlers"
	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/container"
	"github.com/yourorg/mitlist/internal/db"
	"github.com/yourorg/mitlist/internal/jobs"
	"github.com/yourorg/mitlist/internal/middleware"
	"github.com/yourorg/mitlist/internal/redis"
	"github.com/yourorg/mitlist/internal/server"
	"github.com/yourorg/mitlist/pkg/logger"
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

	authHandler := handlers.NewAuthHandler(cfg, cnt)
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

			// Notifications
			notificationHandler := handlers.NewNotificationHandler(cnt.NotificationService())
			notificationHandler.RegisterRoutes(r)

			// Activity logs
			activityHandler := handlers.NewActivityHandler(cnt.ActivityService())
			activityHandler.RegisterRoutes(r)

			// Groups
			groupHandler := handlers.NewGroupHandler(cnt.GroupService())
			r.Post("/groups", groupHandler.CreateGroup)
			r.Get("/groups", groupHandler.ListGroups)
			r.Get("/groups/{id}", groupHandler.GetGroup)
			r.Patch("/groups/{id}", groupHandler.UpdateGroup)
			r.Delete("/groups/{id}", groupHandler.DeleteGroup)
			r.Post("/groups/{id}/members", groupHandler.InviteMember)
			r.Post("/groups/join", groupHandler.JoinGroup)
			r.Delete("/groups/{id}/members/{user_id}", groupHandler.RemoveMember)
			r.Patch("/groups/{id}/members/{user_id}", groupHandler.UpdateMemberRole)
			r.Get("/groups/{id}/pending-claims", groupHandler.GetPendingClaims)
			r.Post("/groups/{id}/pending-claims/{claim_id}/approve", groupHandler.ApproveClaim)
			r.Post("/groups/{id}/pending-claims/{claim_id}/reject", groupHandler.RejectClaim)

			// Lists
			listHandler := handlers.NewListHandler(cnt.ListService())
			r.Post("/lists", listHandler.CreateList)
			r.Get("/lists", listHandler.ListLists)
			r.Get("/lists/{id}", listHandler.GetList)
			r.Patch("/lists/{id}", listHandler.UpdateList)
			r.Delete("/lists/{id}", listHandler.DeleteList)
			r.Post("/lists/{id}/items", listHandler.CreateItem)
			r.Get("/lists/{id}/items", listHandler.ListItems)
			r.Patch("/lists/{id}/items/{item_id}", listHandler.UpdateItem)
			r.Delete("/lists/{id}/items/{item_id}", listHandler.DeleteItem)
			r.Post("/lists/{id}/reorder", listHandler.ReorderItems)

			// Templates
			templateHandler := handlers.NewTemplateHandler(cnt.TemplateService())
			r.Post("/templates", templateHandler.CreateTemplate)
			r.Get("/templates", templateHandler.ListTemplates)
			r.Get("/templates/{id}", templateHandler.GetTemplate)
			r.Patch("/templates/{id}", templateHandler.UpdateTemplate)
			r.Delete("/templates/{id}", templateHandler.DeleteTemplate)
			r.Post("/templates/{id}/apply", templateHandler.ApplyTemplate)
			r.Post("/chore-templates", templateHandler.CreateChoreTemplate)
			r.Get("/chore-templates", templateHandler.ListChoreTemplates)
			r.Get("/chore-templates/{id}", templateHandler.GetChoreTemplate)
			r.Patch("/chore-templates/{id}", templateHandler.UpdateChoreTemplate)
			r.Delete("/chore-templates/{id}", templateHandler.DeleteChoreTemplate)

			// Chores
			choreHandler := handlers.NewChoreHandler(cnt.ChoreService())
			r.Post("/chores", choreHandler.CreateChore)
			r.Get("/chores", choreHandler.ListChores)
			r.Get("/chores/{id}", choreHandler.GetChore)
			r.Patch("/chores/{id}", choreHandler.UpdateChore)
			r.Delete("/chores/{id}", choreHandler.DeleteChore)
			r.Post("/chores/{id}/rotate", choreHandler.RotateChore)
			r.Post("/chores/{id}/complete", choreHandler.CompleteChore)
			r.Post("/chores/{id}/skip", choreHandler.SkipChore)
			r.Get("/chores/{id}/assignments", choreHandler.GetAssignments)

			// Finance
			financeHandler := handlers.NewFinanceHandler(cnt.FinanceService())
			r.Post("/expenses", financeHandler.CreateExpense)
			r.Get("/expenses", financeHandler.ListExpenses)
			r.Get("/expenses/{id}", financeHandler.GetExpense)
			r.Patch("/expenses/{id}", financeHandler.UpdateExpense)
			r.Delete("/expenses/{id}", financeHandler.DeleteExpense)
			r.Post("/expenses/{id}/splits", financeHandler.CreateSplit)
			r.Patch("/expenses/{id}/splits/{split_id}", financeHandler.UpdateSplit)
			r.Delete("/expenses/{id}/splits/{split_id}", financeHandler.DeleteSplit)
			r.Post("/expenses/{id}/settle", financeHandler.CreateSettlement)
			r.Delete("/expenses/{id}/settle/{settlement_id}", financeHandler.DeleteSettlement)
			r.Post("/recurring-expenses", financeHandler.CreateRecurringExpense)
			r.Get("/recurring-expenses", financeHandler.ListRecurringExpenses)
			r.Get("/recurring-expenses/{id}", financeHandler.GetRecurringExpense)
			r.Patch("/recurring-expenses/{id}", financeHandler.UpdateRecurringExpense)
			r.Delete("/recurring-expenses/{id}", financeHandler.DeleteRecurringExpense)

			// Recipes
			recipeHandler := handlers.NewRecipeHandler(cnt.RecipeService())
			recipeHandler.RegisterRoutes(r)

			// Assistant
			assistantHandler := handlers.NewAssistantHandler(cnt.AssistantService())
			assistantHandler.Routes(r)

			// Share Target
			shareHandler := handlers.NewShareHandler(cnt.ShareService())
			shareHandler.Routes(r)
		})
	})

	if err := srv.Run(); err != nil {
		log.Fatal().Err(err).Msg("server shutdown error")
	}
}
