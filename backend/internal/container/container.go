package container

import (
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/redis"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	jwtservice "github.com/mitlist-app/mitlist/internal/services/jwt"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	oauthclient "github.com/mitlist-app/mitlist/internal/services/oauth"
	passwordservice "github.com/mitlist-app/mitlist/internal/services/password"
	pushservice "github.com/mitlist-app/mitlist/internal/services/push"
	"github.com/mitlist-app/mitlist/internal/sse"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Container owns application infrastructure and lazily-created singletons.
type Container struct {
	cfg    *config.Config
	db     *pgxpool.Pool
	redis  *redis.RedisClient
	logger *logger.Logger

	passwordOnce    sync.Once
	passwordService *passwordservice.Service

	jwtOnce    sync.Once
	jwtService *jwtservice.Service

	mailOnce    sync.Once
	mailService *mailservice.Service

	pushOnce    sync.Once
	pushService *pushservice.Service

	storageOnce    sync.Once
	storageService *storagesvc.Service

	userRepoOnce sync.Once
	userRepo     *repositories.UserRepository

	authRepoOnce sync.Once
	authRepo     *repositories.AuthRepository

	groupRepoOnce sync.Once
	groupRepo     *repositories.GroupRepository

	listRepoOnce sync.Once
	listRepo     *repositories.ListRepository

	templateRepoOnce sync.Once
	templateRepo     *repositories.TemplateRepository

	choreRepoOnce sync.Once
	choreRepo     *repositories.ChoreRepository

	financeRepoOnce sync.Once
	financeRepo     *repositories.FinanceRepo

	recipeRepoOnce sync.Once
	recipeRepo     *repositories.RecipeRepo

	mealPlanRepoOnce sync.Once
	mealPlanRepo     *repositories.MealPlanRepo

	notificationRepoOnce sync.Once
	notificationRepo     *repositories.NotificationRepository

	activityRepoOnce sync.Once
	activityRepo     *repositories.ActivityRepository

	pinwallRepoOnce sync.Once
	pinwallRepo     *repositories.PinwallRepository

	attachmentRepoOnce sync.Once
	attachmentRepo     *repositories.AttachmentRepository

	expenseAttachmentRepoOnce sync.Once
	expenseAttachmentRepo     *repositories.ExpenseAttachmentRepository

	pinwallAttachmentRepoOnce sync.Once
	pinwallAttachmentRepo     *repositories.PinwallAttachmentRepository

	listItemAttachmentRepoOnce sync.Once
	listItemAttachmentRepo     *repositories.ListItemAttachmentRepository

	userServiceOnce sync.Once
	userService     *services.UserService

	groupServiceOnce sync.Once
	groupService     *services.GroupService

	googleClientOnce sync.Once
	googleClient     *oauthclient.GoogleClient

	appleClientOnce sync.Once
	appleClient     *oauthclient.AppleClient

	guestServiceOnce sync.Once
	guestService     *services.GuestService

	oauthServiceOnce sync.Once
	oauthService     *services.OAuthService

	listServiceOnce sync.Once
	listService     *services.ListService

	templateServiceOnce sync.Once
	templateService     *services.TemplateService

	choreServiceOnce sync.Once
	choreService     *services.ChoreService

	financeServiceOnce sync.Once
	financeService     *services.FinanceService

	recipeServiceOnce sync.Once
	recipeService     *services.RecipeService

	mealPlanServiceOnce sync.Once
	mealPlanService     *services.MealPlanService

	calendarServiceOnce sync.Once
	calendarService     *services.CalendarService

	shareServiceOnce sync.Once
	shareService     *services.ShareService

	activityServiceOnce sync.Once
	activityService     *services.ActivityService

	notificationServiceOnce sync.Once
	notificationService     *services.NotificationService

	pinwallServiceOnce sync.Once
	pinwallService     *services.PinwallService

	attachmentServiceOnce sync.Once
	attachmentService     *services.AttachmentService

	expenseReceiptServiceOnce sync.Once
	expenseReceiptService     *services.ExpenseReceiptService

	pinwallMediaServiceOnce sync.Once
	pinwallMediaService     *services.PinwallMediaService

	listItemPhotoServiceOnce sync.Once
	listItemPhotoService     *services.ListItemPhotoService

	groceryRepoOnce sync.Once
	groceryRepo     *repositories.GroceryRepository

	groceryServiceOnce sync.Once
	groceryService     *services.GroceryService

	sseHub *sse.Hub
}

// New wires shared infrastructure into a dependency container.
func New(cfg *config.Config, dbPool *pgxpool.Pool, redisClient *redis.RedisClient, log *logger.Logger) *Container {
	return &Container{
		cfg:    cfg,
		db:     dbPool,
		redis:  redisClient,
		logger: log,
	}
}

// Config returns the application configuration.
func (c *Container) Config() *config.Config {
	return c.cfg
}

// DB returns the PostgreSQL connection pool.
func (c *Container) DB() *pgxpool.Pool {
	return c.db
}

// Redis returns the Redis client wrapper.
func (c *Container) Redis() *redis.RedisClient {
	return c.redis
}

// Logger returns the application logger.
func (c *Container) Logger() *logger.Logger {
	return c.logger
}

// Password returns the singleton password service.
func (c *Container) Password() *passwordservice.Service {
	c.passwordOnce.Do(func() {
		c.passwordService = passwordservice.New()
	})
	return c.passwordService
}

// JWT returns the singleton JWT service.
func (c *Container) JWT() *jwtservice.Service {
	c.jwtOnce.Do(func() {
		c.jwtService = jwtservice.New(c.cfg, c.redis)
	})
	return c.jwtService
}

// Mail returns the singleton mail service.
func (c *Container) Mail() *mailservice.Service {
	c.mailOnce.Do(func() {
		c.mailService = mailservice.New(c.cfg, c.logger)
	})
	return c.mailService
}

// Push returns the singleton push notification service.
func (c *Container) Push() *pushservice.Service {
	c.pushOnce.Do(func() {
		c.pushService = pushservice.New(c.cfg, c.logger, c.AuthRepo(), c.GroupRepo(), c.NotificationRepo())
	})
	return c.pushService
}

// Storage returns the singleton S3-compatible storage service.
func (c *Container) Storage() *storagesvc.Service {
	c.storageOnce.Do(func() {
		c.storageService = storagesvc.New(c.cfg)
	})
	return c.storageService
}

// UserRepo returns the singleton user repository.
func (c *Container) UserRepo() *repositories.UserRepository {
	c.userRepoOnce.Do(func() {
		c.userRepo = repositories.NewUserRepository(c.db)
	})
	return c.userRepo
}

// AuthRepo returns the singleton auth repository.
func (c *Container) AuthRepo() *repositories.AuthRepository {
	c.authRepoOnce.Do(func() {
		c.authRepo = repositories.NewAuthRepository(c.db)
	})
	return c.authRepo
}

// GroupRepo returns the singleton group repository.
func (c *Container) GroupRepo() *repositories.GroupRepository {
	c.groupRepoOnce.Do(func() {
		c.groupRepo = repositories.NewGroupRepository(c.db)
	})
	return c.groupRepo
}

// ListRepo returns the singleton list repository.
func (c *Container) ListRepo() *repositories.ListRepository {
	c.listRepoOnce.Do(func() {
		c.listRepo = repositories.NewListRepository(c.db)
	})
	return c.listRepo
}

// TemplateRepo returns the singleton template repository.
func (c *Container) TemplateRepo() *repositories.TemplateRepository {
	c.templateRepoOnce.Do(func() {
		c.templateRepo = repositories.NewTemplateRepository(c.db)
	})
	return c.templateRepo
}

// ChoreRepo returns the singleton chore repository.
func (c *Container) ChoreRepo() *repositories.ChoreRepository {
	c.choreRepoOnce.Do(func() {
		c.choreRepo = repositories.NewChoreRepository(c.db)
	})
	return c.choreRepo
}

// FinanceRepo returns the singleton finance repository.
func (c *Container) FinanceRepo() *repositories.FinanceRepo {
	c.financeRepoOnce.Do(func() {
		c.financeRepo = repositories.NewFinanceRepo(c.db)
	})
	return c.financeRepo
}

// RecipeRepo returns the singleton recipe repository.
func (c *Container) RecipeRepo() *repositories.RecipeRepo {
	c.recipeRepoOnce.Do(func() {
		c.recipeRepo = repositories.NewRecipeRepo(c.db)
	})
	return c.recipeRepo
}

// MealPlanRepo returns the singleton meal plan repository.
func (c *Container) MealPlanRepo() *repositories.MealPlanRepo {
	c.mealPlanRepoOnce.Do(func() {
		c.mealPlanRepo = repositories.NewMealPlanRepo(c.db)
	})
	return c.mealPlanRepo
}

// NotificationRepo returns the singleton notification repository.
func (c *Container) NotificationRepo() *repositories.NotificationRepository {
	c.notificationRepoOnce.Do(func() {
		c.notificationRepo = repositories.NewNotificationRepository(c.db)
	})
	return c.notificationRepo
}

// ActivityRepo returns the singleton activity log repository.
func (c *Container) ActivityRepo() *repositories.ActivityRepository {
	c.activityRepoOnce.Do(func() {
		c.activityRepo = repositories.NewActivityRepository(c.db)
	})
	return c.activityRepo
}

// PinwallRepo returns the singleton pinwall repository.
func (c *Container) PinwallRepo() *repositories.PinwallRepository {
	c.pinwallRepoOnce.Do(func() {
		c.pinwallRepo = repositories.NewPinwallRepository(c.db)
	})
	return c.pinwallRepo
}

// AttachmentRepo returns the singleton attachment repository.
func (c *Container) AttachmentRepo() *repositories.AttachmentRepository {
	c.attachmentRepoOnce.Do(func() {
		c.attachmentRepo = repositories.NewAttachmentRepository(c.db)
	})
	return c.attachmentRepo
}

func (c *Container) ExpenseAttachmentRepo() *repositories.ExpenseAttachmentRepository {
	c.expenseAttachmentRepoOnce.Do(func() {
		c.expenseAttachmentRepo = repositories.NewExpenseAttachmentRepository(c.db)
	})
	return c.expenseAttachmentRepo
}

func (c *Container) PinwallAttachmentRepo() *repositories.PinwallAttachmentRepository {
	c.pinwallAttachmentRepoOnce.Do(func() {
		c.pinwallAttachmentRepo = repositories.NewPinwallAttachmentRepository(c.db)
	})
	return c.pinwallAttachmentRepo
}

func (c *Container) ListItemAttachmentRepo() *repositories.ListItemAttachmentRepository {
	c.listItemAttachmentRepoOnce.Do(func() {
		c.listItemAttachmentRepo = repositories.NewListItemAttachmentRepository(c.db)
	})
	return c.listItemAttachmentRepo
}

// UserService returns the singleton user service.
func (c *Container) UserService() *services.UserService {
	c.userServiceOnce.Do(func() {
		c.userService = services.NewUserService(c.UserRepo(), c.AuthRepo(), c.JWT(), c.Password(), c.Mail(), c.redis.Client())
	})
	return c.userService
}

// GroupService returns the singleton group service.
func (c *Container) GroupService() *services.GroupService {
	c.groupServiceOnce.Do(func() {
		c.groupService = services.NewGroupService(c.GroupRepo(), c.UserRepo())
	})
	return c.groupService
}

// GoogleClient returns the singleton Google OAuth client.
func (c *Container) GoogleClient() *oauthclient.GoogleClient {
	c.googleClientOnce.Do(func() {
		c.googleClient = oauthclient.NewGoogleClient(c.cfg)
	})
	return c.googleClient
}

// AppleClient returns the singleton Apple OAuth client.
func (c *Container) AppleClient() *oauthclient.AppleClient {
	c.appleClientOnce.Do(func() {
		c.appleClient = oauthclient.NewAppleClient(c.cfg)
	})
	return c.appleClient
}

// GuestService returns the singleton guest service.
func (c *Container) GuestService() *services.GuestService {
	c.guestServiceOnce.Do(func() {
		c.guestService = services.NewGuestService(c.UserRepo(), c.JWT(), c.Password(), c.redis.Client())
	})
	return c.guestService
}

// OAuthService returns the singleton OAuth service.
func (c *Container) OAuthService() *services.OAuthService {
	c.oauthServiceOnce.Do(func() {
		c.oauthService = services.NewOAuthService(c.UserRepo(), c.AuthRepo(), c.JWT(), c.GoogleClient(), c.AppleClient())
	})
	return c.oauthService
}

// ListService returns the singleton list service.
func (c *Container) ListService() *services.ListService {
	c.listServiceOnce.Do(func() {
		c.listService = services.NewListService(c.ListRepo(), c.GroupRepo())
		c.listService.SetHub(c.SSEHub())
		c.listService.SetPush(c.Push())
	})
	return c.listService
}

// TemplateService returns the singleton template service.
func (c *Container) TemplateService() *services.TemplateService {
	c.templateServiceOnce.Do(func() {
		c.templateService = services.NewTemplateService(c.TemplateRepo(), c.GroupRepo(), c.ListRepo())
	})
	return c.templateService
}

// ChoreService returns the singleton chore service.
func (c *Container) ChoreService() *services.ChoreService {
	c.choreServiceOnce.Do(func() {
		c.choreService = services.NewChoreService(c.ChoreRepo(), c.GroupRepo(), c.ListRepo())
		c.choreService.SetHub(c.SSEHub())
		c.choreService.SetPush(c.Push())
	})
	return c.choreService
}

// FinanceService returns the singleton finance service.
func (c *Container) FinanceService() *services.FinanceService {
	c.financeServiceOnce.Do(func() {
		c.financeService = services.NewFinanceService(c.FinanceRepo(), c.GroupRepo())
	})
	return c.financeService
}

// RecipeService returns the singleton recipe service.
func (c *Container) RecipeService() *services.RecipeService {
	c.recipeServiceOnce.Do(func() {
		c.recipeService = services.NewRecipeService(c.RecipeRepo())
	})
	return c.recipeService
}

// MealPlanService returns the singleton meal plan service.
func (c *Container) MealPlanService() *services.MealPlanService {
	c.mealPlanServiceOnce.Do(func() {
		c.mealPlanService = services.NewMealPlanService(c.MealPlanRepo(), c.GroupRepo(), c.RecipeRepo(), c.ListRepo())
	})
	return c.mealPlanService
}

// CalendarService returns the singleton calendar service.
func (c *Container) CalendarService() *services.CalendarService {
	c.calendarServiceOnce.Do(func() {
		c.calendarService = services.NewCalendarService(c.MealPlanRepo(), c.RecipeRepo(), c.ChoreRepo(), c.FinanceRepo(), c.GroupRepo(), c.PinwallRepo())
	})
	return c.calendarService
}

// NotificationService returns the singleton notification service.
func (c *Container) NotificationService() *services.NotificationService {
	c.notificationServiceOnce.Do(func() {
		c.notificationService = services.NewNotificationService(c.NotificationRepo(), c.ActivityRepo(), c.Push())
	})
	return c.notificationService
}

// ActivityService returns the singleton activity log service.
func (c *Container) ActivityService() *services.ActivityService {
	c.activityServiceOnce.Do(func() {
		c.activityService = services.NewActivityService(c.ActivityRepo(), c.GroupRepo())
	})
	return c.activityService
}

// PinwallService returns the singleton pinwall service.
func (c *Container) PinwallService() *services.PinwallService {
	c.pinwallServiceOnce.Do(func() {
		c.pinwallService = services.NewPinwallService(c.PinwallRepo(), c.GroupRepo())
	})
	return c.pinwallService
}

// AttachmentService returns the singleton attachment service.
func (c *Container) AttachmentService() *services.AttachmentService {
	c.attachmentServiceOnce.Do(func() {
		c.attachmentService = services.NewAttachmentService(c.cfg, c.AttachmentRepo(), c.GroupRepo(), c.Storage())
	})
	return c.attachmentService
}

func (c *Container) ExpenseReceiptService() *services.ExpenseReceiptService {
	c.expenseReceiptServiceOnce.Do(func() {
		c.expenseReceiptService = services.NewExpenseReceiptService(
			c.FinanceRepo(),
			c.GroupRepo(),
			c.AttachmentRepo(),
			c.ExpenseAttachmentRepo(),
			c.Storage(),
		)
	})
	return c.expenseReceiptService
}

func (c *Container) PinwallMediaService() *services.PinwallMediaService {
	c.pinwallMediaServiceOnce.Do(func() {
		c.pinwallMediaService = services.NewPinwallMediaService(
			c.PinwallRepo(),
			c.GroupRepo(),
			c.AttachmentRepo(),
			c.PinwallAttachmentRepo(),
			c.Storage(),
		)
	})
	return c.pinwallMediaService
}

func (c *Container) ListItemPhotoService() *services.ListItemPhotoService {
	c.listItemPhotoServiceOnce.Do(func() {
		c.listItemPhotoService = services.NewListItemPhotoService(
			c.ListRepo(),
			c.GroupRepo(),
			c.AttachmentRepo(),
			c.ListItemAttachmentRepo(),
			c.Storage(),
		)
	})
	return c.listItemPhotoService
}

// ShareService returns the singleton share target service.
func (c *Container) ShareService() *services.ShareService {
	c.shareServiceOnce.Do(func() {
		c.shareService = services.NewShareService(c.ListRepo(), c.RecipeRepo(), c.GroupRepo())
	})
	return c.shareService
}

// SSEHub returns the singleton SSE hub for real-time broadcasts.
func (c *Container) SSEHub() *sse.Hub {
	if c.sseHub == nil {
		c.sseHub = sse.New()
	}
	return c.sseHub
}

// GroceryRepo returns the singleton grocery repository.
func (c *Container) GroceryRepo() *repositories.GroceryRepository {
	c.groceryRepoOnce.Do(func() {
		c.groceryRepo = repositories.NewGroceryRepository(c.db)
	})
	return c.groceryRepo
}

// GroceryService returns the singleton grocery service.
func (c *Container) GroceryService() *services.GroceryService {
	c.groceryServiceOnce.Do(func() {
		c.groceryService = services.NewGroceryService(c.GroceryRepo(), c.GroupRepo())
		c.groceryService.SetHub(c.SSEHub())
	})
	return c.groceryService
}
