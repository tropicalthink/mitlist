package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/middleware"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	passwordservice "github.com/mitlist-app/mitlist/internal/services/password"
	pushservice "github.com/mitlist-app/mitlist/internal/services/push"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

var (
	testDB  *pgxpool.Pool
	testCfg *config.Config
	testJWT *jwtservice.Service
)

func TestMain(m *testing.M) {
	code := 1
	defer func() { os.Exit(code) }()

	testCfg = mustLoadTestConfig()

	db, err := tryConnectDB(testCfg.DatabaseURL)
	if err != nil {
		if os.Getenv("CI") != "" {
			fmt.Fprintf(os.Stderr, "ERROR: test database unavailable in CI: %v\n", err)
			return
		}
		fmt.Fprintf(os.Stderr, "SKIP: local test database unavailable: %v\n", err)
		code = 0
		return
	}
	testDB = db
	defer db.Close()

	if err := runMigrations(testCfg.DatabaseURL); err != nil {
		if os.Getenv("CI") != "" {
			fmt.Fprintf(os.Stderr, "ERROR: migrations failed in CI: %v\n", err)
			return
		}
		fmt.Fprintf(os.Stderr, "SKIP: local migrations unavailable: %v\n", err)
		code = 0
		return
	}

	testJWT = jwtservice.New(testCfg, testDB)

	code = m.Run()
}

func mustLoadTestConfig() *config.Config {
	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://mitlist:mitlist@localhost:5432/mitlist_test?sslmode=disable"
	}
	return &config.Config{
		DatabaseURL:              dbURL,
		SecretKey:                "test-secret-key-min-32-chars-long!!!",
		SessionSecretKey:         "test-session-secret-key-min-32-chars!",
		Environment:              "test",
		FrontendURL:              "http://localhost:5173",
		APIPrefix:                "/api",
		AccessTokenExpireMinutes: 60,
		PasswordAuthEnabled:      true,
		GuestAuthEnabled:         true,
	}
}

func tryConnectDB(databaseURL string) (*pgxpool.Pool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, err
	}
	cfg.MaxConns = 10
	cfg.MinConns = 1

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}

func runMigrations(databaseURL string) error {
	dsn := databaseURL
	if strings.HasPrefix(dsn, "postgres://") {
		dsn = "pgx5" + dsn[len("postgres"):]
	}
	if strings.HasPrefix(dsn, "postgresql://") {
		dsn = "pgx5" + dsn[len("postgresql"):]
	}

	mig, err := migrate.New("file://../../../migrations", dsn)
	if err != nil {
		return err
	}
	if err := mig.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}
	return nil
}

func clearTables(t *testing.T) {
	if testDB == nil {
		t.Skip("test database not connected")
	}
	ctx := context.Background()
	tables := []string{
		"collection_recipes", "collections",
		"recipe_shares", "recipe_steps", "recipe_ingredients", "recipes",
		"settlement_methods", "payment_methods",
		"splits", "settlements", "recurring_expenses", "expenses", "expense_categories",
		"chore_completions", "chore_assignments", "chore_rotation_states", "chores",
		"chore_template_items", "chore_templates", "template_items", "templates",
		"list_items", "lists",
		"item_aliases", "store_aisles", "purchase_history",
		"item_cooccurrence", "corrections", "canonical_items", "grocery_versions",
		"activity_logs", "notifications", "notification_preferences",
		"chat_messages", "chat_sessions",
		"pending_claims", "group_invites", "group_memberships", "groups",
		"auth_access_revocations", "auth_login_limits", "oauth_handoffs", "email_verification_tokens", "auth_sessions",
		"push_subscriptions", "oauth_accounts", "password_reset_tokens",
		"users",
	}
	for _, table := range tables {
		_, err := testDB.Exec(ctx, fmt.Sprintf("DELETE FROM %s", table))
		if err != nil {
			t.Logf("failed to clear table %s: %v", table, err)
		}
	}
}

// ---------------------------------------------------------------------------
// Repository / Service helpers
// ---------------------------------------------------------------------------

func newTestUserRepo() *repositories.UserRepository   { return repositories.NewUserRepository(testDB) }
func newTestAuthRepo() *repositories.AuthRepository   { return repositories.NewAuthRepository(testDB) }
func newTestGroupRepo() *repositories.GroupRepository { return repositories.NewGroupRepository(testDB) }
func newTestListRepo() *repositories.ListRepository   { return repositories.NewListRepository(testDB) }
func newTestTemplateRepo() *repositories.TemplateRepository {
	return repositories.NewTemplateRepository(testDB)
}
func newTestChoreRepo() *repositories.ChoreRepository { return repositories.NewChoreRepository(testDB) }
func newTestFinanceRepo() *repositories.FinanceRepo   { return repositories.NewFinanceRepo(testDB) }
func newTestRecipeRepo() *repositories.RecipeRepo     { return repositories.NewRecipeRepo(testDB) }
func newTestNotificationRepo() *repositories.NotificationRepository {
	return repositories.NewNotificationRepository(testDB)
}
func newTestActivityRepo() *repositories.ActivityRepository {
	return repositories.NewActivityRepository(testDB)
}
func newTestGroceryRepo() *repositories.GroceryRepository {
	return repositories.NewGroceryRepository(testDB)
}
func newTestGroceryService() *services.GroceryService {
	return services.NewGroceryService(newTestGroceryRepo(), newTestGroupRepo())
}
func newTestPasswordService() *passwordservice.Service { return passwordservice.New() }
func newTestMailService() *mailservice.Service         { return mailservice.New(testCfg, logger.New("test")) }
func newTestPushService() *pushservice.Service {
	return pushservice.New(testCfg, logger.New("test"), newTestAuthRepo(), newTestGroupRepo(), newTestNotificationRepo())
}

// ---------------------------------------------------------------------------
// User / Auth helpers
// ---------------------------------------------------------------------------

func createTestUser(t *testing.T, email, password string) *models.User {
	ctx := context.Background()
	userRepo := newTestUserRepo()
	ps := newTestPasswordService()
	hash, err := ps.Hash(password)
	require.NoError(t, err)

	user := &models.User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: hash,
		FirstName:    "Test",
		LastName:     "User",
		IsActive:     true,
		IsVerified:   true,
		IsGuest:      false,
	}
	require.NoError(t, userRepo.Create(ctx, user))
	return user
}

func addTestMembership(t *testing.T, groupID, userID uuid.UUID, role string) {
	t.Helper()
	require.NoError(t, newTestGroupRepo().CreateMembership(context.Background(),
		&models.GroupMembership{GroupID: groupID, UserID: userID, Role: role}))
}

func generateTestToken(userID uuid.UUID) string {
	access, _, err := testJWT.GenerateTokenPair(userID.String(), nil)
	if err != nil {
		panic(err)
	}
	return access
}

// testAuthMiddleware validates the Bearer token, loads the user from DB,
// and injects both the string user ID (for currentUserID) and the full
// user object (for UserFromContext / api.UserFromContext).
func testAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := ""
		if cookie, err := r.Cookie("access_token"); err == nil && cookie.Value != "" {
			token = cookie.Value
		} else if bearer := r.Header.Get("Authorization"); strings.HasPrefix(bearer, "Bearer ") {
			token = strings.TrimPrefix(bearer, "Bearer ")
		}
		if token == "" {
			api.WriteError(w, api.ErrUnauthorized)
			return
		}
		claims, err := testJWT.ValidateAccessToken(token)
		if err != nil {
			api.WriteError(w, api.ErrUnauthorized)
			return
		}
		userID, err := uuid.Parse(claims.Subject)
		if err != nil {
			api.WriteError(w, api.ErrUnauthorized)
			return
		}
		userRepo := newTestUserRepo()
		user, err := userRepo.GetByID(r.Context(), userID)
		if err != nil {
			api.WriteError(w, api.ErrUnauthorized)
			return
		}
		ctx := middleware.WithUserID(r.Context(), claims.Subject)
		ctx = api.WithUser(ctx, user)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// ---------------------------------------------------------------------------
// HTTP request helpers
// ---------------------------------------------------------------------------

func buildRequest(t *testing.T, method, path string, body any, token string) *http.Request {
	var bodyReader *bytes.Reader
	if body != nil {
		b, err := json.Marshal(body)
		require.NoError(t, err)
		bodyReader = bytes.NewReader(b)
	} else {
		bodyReader = bytes.NewReader(nil)
	}
	req := httptest.NewRequest(method, path, bodyReader)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	return req
}

func execRequest(t *testing.T, handler http.Handler, method, path string, body any, token string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	req := buildRequest(t, method, path, body, token)
	handler.ServeHTTP(rec, req)
	return rec
}

func requireStatus(t *testing.T, rec *httptest.ResponseRecorder, expected int) {
	require.Equalf(t, expected, rec.Code, "body: %s", rec.Body.String())
}

func parseJSONResponse(t *testing.T, rec *httptest.ResponseRecorder, v any) {
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), v))
}

func parseErrorResponse(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	var result map[string]any
	parseJSONResponse(t, rec, &result)
	return result
}

// ---------------------------------------------------------------------------
// Router helpers
// ---------------------------------------------------------------------------

// captureMailService records messages instead of delivering them. The real mail
// service has no SMTP configuration under test, so every send fails; capturing
// also lets a test read the verification code, which exists nowhere else (the
// database stores only its hash).
type captureMailService struct {
	messages []capturedMail
}

type capturedMail struct{ to, subject, body string }

// SendHTML keeps the text part: that is where verificationCodeFor looks.
func (m *captureMailService) SendHTML(to, subject, html, text string) error {
	return m.Send(to, subject, text, false)
}

func (m *captureMailService) Send(to, subject, body string, isHTML bool) error {
	m.messages = append(m.messages, capturedMail{to: to, subject: subject, body: body})
	return nil
}

func (m *captureMailService) SendTemplate(to, subject, tmplStr string, data any) error {
	return m.Send(to, subject, tmplStr, false)
}

// verificationCodeFor returns the code from the most recent message sent to the
// address, matching the "code is: XXXXXXXX" line built by verificationMessage.
func (m *captureMailService) verificationCodeFor(t *testing.T, to string) string {
	t.Helper()
	const marker = "verification code is: "
	for i := len(m.messages) - 1; i >= 0; i-- {
		msg := m.messages[i]
		if msg.to != to {
			continue
		}
		idx := strings.Index(msg.body, marker)
		require.GreaterOrEqual(t, idx, 0, "no verification code in message to %s", to)
		code := msg.body[idx+len(marker):]
		if nl := strings.IndexAny(code, "\r\n"); nl >= 0 {
			code = code[:nl]
		}
		return strings.TrimSpace(code)
	}
	t.Fatalf("no message captured for %s", to)
	return ""
}

// The new*Router helpers mount each handler's own RegisterRoutes under
// /api/v1, as the server does, so a new endpoint is reachable in tests
// without a second route table to keep in step (a hand-copied one missed
// PUT /lists/{id}/reminder).

func newAuthRouter(t *testing.T) (chi.Router, *AuthHandler) {
	r, h, _ := newAuthRouterWithMail(t)
	return r, h
}

func newAuthRouterWithMail(t *testing.T) (chi.Router, *AuthHandler, *captureMailService) {
	return newAuthRouterWithConfig(t, testCfg)
}

func newAuthRouterWithConfig(t *testing.T, cfg *config.Config) (chi.Router, *AuthHandler, *captureMailService) {
	userRepo := newTestUserRepo()
	authRepo := newTestAuthRepo()
	ps := newTestPasswordService()
	ms := &captureMailService{}
	jwtSvc := testJWT

	userSvc := services.NewUserService(userRepo, authRepo, jwtSvc, ps, ms)
	guestSvc := services.NewGuestServiceWithAuth(userRepo, jwtSvc, ps, authRepo, ms)
	userSvc.SetFrontendURL(cfg.FrontendURL)
	guestSvc.SetFrontendURL(cfg.FrontendURL)
	oauthSvc := services.NewOAuthService(userRepo, authRepo, jwtSvc, nil, nil)

	h := NewAuthHandler(cfg, userSvc, guestSvc, oauthSvc, jwtSvc)

	// The handler's own routes, gates and real auth middleware, as the
	// server mounts them: the password surface sits behind
	// PASSWORD_AUTH_ENABLED, and registration hands back no tokens, so a test
	// that needs an authenticated user has to complete verification.
	r := chi.NewRouter()
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h, ms
}

func newGroupRouter(t *testing.T) (chi.Router, *GroupHandler) {
	groupRepo := newTestGroupRepo()
	userRepo := newTestUserRepo()
	svc := services.NewGroupService(groupRepo, userRepo)
	h := NewGroupHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newListRouter(t *testing.T) (chi.Router, *ListHandler) {
	listRepo := newTestListRepo()
	groupRepo := newTestGroupRepo()
	svc := services.NewListService(listRepo, groupRepo)
	h := NewListHandler(svc, nil)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newTemplateRouter(t *testing.T) (chi.Router, *TemplateHandler) {
	templateRepo := newTestTemplateRepo()
	groupRepo := newTestGroupRepo()
	listRepo := newTestListRepo()
	svc := services.NewTemplateService(templateRepo, groupRepo, listRepo)
	h := NewTemplateHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newChoreRouter(t *testing.T) (chi.Router, *ChoreHandler) {
	choreRepo := newTestChoreRepo()
	groupRepo := newTestGroupRepo()
	listRepo := newTestListRepo()
	svc := services.NewChoreService(choreRepo, groupRepo, listRepo)
	h := NewChoreHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newFinanceRouter(t *testing.T) (chi.Router, *FinanceHandler) {
	financeRepo := newTestFinanceRepo()
	groupRepo := newTestGroupRepo()
	svc := services.NewFinanceService(financeRepo, groupRepo)
	h := NewFinanceHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newRecipeRouterWithGrocery(t *testing.T) (chi.Router, *RecipeHandler) {
	recipeRepo := newTestRecipeRepo()
	svc := services.NewRecipeService(recipeRepo, newTestGroupRepo(), newTestUserRepo())
	listSvc := services.NewListService(newTestListRepo(), newTestGroupRepo())
	h := NewRecipeHandler(svc, services.NewRecipeScrapingService(), listSvc)
	h.SetGroceryService(newTestGroceryService())

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newRecipeRouter(t *testing.T) (chi.Router, *RecipeHandler) {
	recipeRepo := newTestRecipeRepo()
	svc := services.NewRecipeService(recipeRepo, newTestGroupRepo(), newTestUserRepo())
	listSvc := services.NewListService(newTestListRepo(), newTestGroupRepo())
	h := NewRecipeHandler(svc, services.NewRecipeScrapingService(), listSvc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	r.Route("/api/v1", h.RegisterRoutes)
	return r, h
}

func newNotificationRouter(t *testing.T) (chi.Router, *NotificationHandler) {
	notificationRepo := newTestNotificationRepo()
	pushSvc := newTestPushService()
	// Real activity and group repos, not nil: GetPreferences reads the caller's
	// groups to fill in defaults, so a nil groupRepo panics rather than 500s.
	svc := services.NewNotificationService(notificationRepo, newTestActivityRepo(), newTestGroupRepo(), pushSvc)
	h := NewNotificationHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	return r, h
}

func newShareRouter(t *testing.T) (chi.Router, *ShareHandler) {
	listRepo := newTestListRepo()
	recipeRepo := newTestRecipeRepo()
	groupRepo := newTestGroupRepo()
	svc := services.NewShareService(listRepo, recipeRepo, groupRepo)
	h := NewShareHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)
	return r, h
}
