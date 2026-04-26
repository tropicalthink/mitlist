package container

import (
	"sync"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/redis"
	"github.com/yourorg/mitlist/internal/repositories"
	"github.com/yourorg/mitlist/internal/services"
	aiservice "github.com/yourorg/mitlist/internal/services/ai"
	jwtservice "github.com/yourorg/mitlist/internal/services/jwt"
	mailservice "github.com/yourorg/mitlist/internal/services/mail"
	oauthclient "github.com/yourorg/mitlist/internal/services/oauth"
	passwordservice "github.com/yourorg/mitlist/internal/services/password"
	pushservice "github.com/yourorg/mitlist/internal/services/push"
	storagesvc "github.com/yourorg/mitlist/internal/services/storage"
	"github.com/yourorg/mitlist/pkg/logger"
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

	assistantRepoOnce sync.Once
	assistantRepo     *repositories.AssistantRepository

	notificationRepoOnce sync.Once
	notificationRepo     *repositories.NotificationRepository

	activityRepoOnce sync.Once
	activityRepo     *repositories.ActivityRepository

	pinwallRepoOnce sync.Once
	pinwallRepo     *repositories.PinwallRepository

	attachmentRepoOnce sync.Once
	attachmentRepo     *repositories.AttachmentRepository

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

	assistantServiceOnce sync.Once
	assistantService     *services.AssistantService

	shareServiceOnce sync.Once
	shareService     *services.ShareService

	notificationServiceOnce sync.Once
	notificationService     *services.NotificationService

	activityServiceOnce sync.Once
	activityService     *services.ActivityService

	pinwallServiceOnce sync.Once
	pinwallService     *services.PinwallService

	attachmentServiceOnce sync.Once
	attachmentService     *services.AttachmentService

	aiClientOnce sync.Once
	aiClient     *aiservice.Client
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
		c.pushService = pushservice.New(c.cfg, c.logger)
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

// AssistantRepo returns the singleton assistant repository.
func (c *Container) AssistantRepo() *repositories.AssistantRepository {
	c.assistantRepoOnce.Do(func() {
		c.assistantRepo = repositories.NewAssistantRepository(c.db)
	})
	return c.assistantRepo
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

// UserService returns the singleton user service.
func (c *Container) UserService() *services.UserService {
	c.userServiceOnce.Do(func() {
		c.userService = services.NewUserService(c.UserRepo(), c.AuthRepo(), c.JWT(), c.Password(), c.Mail())
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
		c.guestService = services.NewGuestService(c.UserRepo(), c.JWT(), c.Password())
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
		c.choreService = services.NewChoreService(c.ChoreRepo(), c.GroupRepo())
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

// AssistantService returns the singleton assistant service.
func (c *Container) AssistantService() *services.AssistantService {
	c.assistantServiceOnce.Do(func() {
		c.assistantService = services.NewAssistantService(c.AssistantRepo(), c.AIClient())
	})
	return c.assistantService
}

// NotificationService returns the singleton notification service.
func (c *Container) NotificationService() *services.NotificationService {
	c.notificationServiceOnce.Do(func() {
		c.notificationService = services.NewNotificationService(c.NotificationRepo(), c.Push())
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

// ShareService returns the singleton share target service.
func (c *Container) ShareService() *services.ShareService {
	c.shareServiceOnce.Do(func() {
		c.shareService = services.NewShareService(c.ListRepo(), c.RecipeRepo(), c.GroupRepo())
	})
	return c.shareService
}

// AIClient returns the singleton AI client.
func (c *Container) AIClient() *aiservice.Client {
	c.aiClientOnce.Do(func() {
		c.aiClient = aiservice.New(c.cfg)
	})
	return c.aiClient
}
