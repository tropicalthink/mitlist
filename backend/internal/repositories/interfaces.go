package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/models"
)

// ErrInviteAlreadyUsed is returned when a concurrent or repeated redemption
// attempts to consume a one-use invite.
var ErrInviteAlreadyUsed = errors.New("invite already used")

// UserRepo is the interface for user repository operations.
type UserRepo interface {
	Create(ctx context.Context, user *models.User) error
	GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	GetByEmail(ctx context.Context, email string) (*models.User, error)
	GetByOAuth(ctx context.Context, provider, providerUserID string) (*models.User, error)
	Update(ctx context.Context, user *models.User) error
	SoftDelete(ctx context.Context, id uuid.UUID) error
	TouchGuestActivity(ctx context.Context, id uuid.UUID) error
	ReactivateGuest(ctx context.Context, id uuid.UUID) error
	List(ctx context.Context, limit, offset int) ([]models.User, error)
}

// AuthRepo is the interface for auth repository operations.
type AuthRepo interface {
	CreateOAuthAccount(ctx context.Context, account *models.OAuthAccount) error
	GetOAuthByProviderID(ctx context.Context, provider, providerUserID string) (*models.OAuthAccount, error)
	CreatePasswordResetToken(ctx context.Context, token *models.PasswordResetToken) error
	GetPasswordResetToken(ctx context.Context, token string) (*models.PasswordResetToken, error)
	ConsumeToken(ctx context.Context, id uuid.UUID) error
	ConsumePasswordReset(ctx context.Context, tokenHash, passwordHash string) (uuid.UUID, error)
	UpdatePasswordAndRevokeSessions(ctx context.Context, userID uuid.UUID, passwordHash string) error
	CreateUnverifiedUser(ctx context.Context, user *models.User, tokenHash string, expiresAt time.Time) error
	CreateEmailVerification(ctx context.Context, userID uuid.UUID, tokenHash string, expiresAt time.Time) error
	ConsumeEmailVerification(ctx context.Context, tokenHash string) (uuid.UUID, error)
	ReserveLoginAttempt(ctx context.Context, identifier string, limit int, window time.Duration) (bool, error)
	ClearLoginAttempts(ctx context.Context, identifier string) error
	CreatePushSubscription(ctx context.Context, sub *models.PushSubscription) error
	ListPushSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.PushSubscription, error)
	ListPushSubscriptionsByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.PushSubscription, error)
	DeletePushSubscription(ctx context.Context, id uuid.UUID) error
	SaveDeviceToken(ctx context.Context, userID uuid.UUID, platform, token string) (*models.DeviceToken, error)
	ListDeviceTokensByUser(ctx context.Context, userID uuid.UUID) ([]models.DeviceToken, error)
	ListDeviceTokensByUserIDs(ctx context.Context, userIDs []uuid.UUID) (map[uuid.UUID][]models.DeviceToken, error)
	DeleteDeviceToken(ctx context.Context, userID, id uuid.UUID) error
	CreateOAuthHandoff(ctx context.Context, codeHash string, userID uuid.UUID, expiresAt time.Time) error
	ConsumeOAuthHandoff(ctx context.Context, codeHash string) (uuid.UUID, error)
}

// IntegrationCredentialRepo is the persistence contract for revocable,
// group-scoped bearer credentials.
type IntegrationCredentialRepo interface {
	Create(ctx context.Context, credential *models.IntegrationCredential, tokenHash string) error
	ListByUser(ctx context.Context, userID uuid.UUID) ([]models.IntegrationCredential, error)
	GetActiveByHash(ctx context.Context, tokenHash string) (*models.IntegrationCredential, error)
	TouchLastUsed(ctx context.Context, id uuid.UUID, ip, userAgent string) error
	Revoke(ctx context.Context, userID, id uuid.UUID) error
	GetByID(ctx context.Context, userID, id uuid.UUID) (*models.IntegrationCredential, error)
}

// BillingRepo is the interface for premium subscription operations.
type BillingRepo interface {
	UpsertSubscription(ctx context.Context, s *models.BillingSubscription) (*models.BillingSubscription, error)
	SupersedeSubscription(ctx context.Context, provider, providerSubscriptionID string, supersededAt time.Time) error
	GetSubscriptionByProviderID(ctx context.Context, provider, providerSubscriptionID string) (*models.BillingSubscription, error)
	ListSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.BillingSubscription, error)
	GetLiveSubscriptionForUser(ctx context.Context, userID uuid.UUID) (*models.BillingSubscription, error)
	SetPrimaryGroupForUser(ctx context.Context, userID, groupID uuid.UUID) (*models.BillingSubscription, error)
	GetGroupCoverage(ctx context.Context, groupID uuid.UUID) (bool, *string, error)
	CountGroupMembers(ctx context.Context, groupID uuid.UUID) (int, error)
	MarkWebhookEventProcessed(ctx context.Context, id, provider, eventType string) (bool, error)
	DeleteWebhookEventsBefore(ctx context.Context, cutoff time.Time) (int64, error)
}

// GroupRepo is the interface for group repository operations.
type GroupRepo interface {
	WithTx(ctx context.Context, fn func(txRepo GroupRepo) error) error
	LockGroup(ctx context.Context, groupID uuid.UUID) error
	CreateGroup(ctx context.Context, group *models.Group) error
	GetGroupByID(ctx context.Context, id uuid.UUID) (*models.Group, error)
	ListGroupsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Group, error)
	UpdateGroup(ctx context.Context, group *models.Group) error
	DeleteGroup(ctx context.Context, id uuid.UUID) error
	CreateMembership(ctx context.Context, m *models.GroupMembership) error
	GetMembership(ctx context.Context, groupID, userID uuid.UUID) (*models.GroupMembership, error)
	UpdateMembership(ctx context.Context, m *models.GroupMembership) error
	DeleteMembership(ctx context.Context, id uuid.UUID) error
	CreateInvite(ctx context.Context, invite *models.GroupInvite) error
	GetInviteByCode(ctx context.Context, code string) (*models.GroupInvite, error)
	ConsumeInvite(ctx context.Context, inviteID, userID uuid.UUID) error
	CreatePendingClaim(ctx context.Context, claim *models.PendingClaim) error
	GetPendingClaimByCode(ctx context.Context, code string) (*models.PendingClaim, error)
	GetPendingClaimByID(ctx context.Context, id uuid.UUID) (*models.PendingClaim, error)
	DeletePendingClaim(ctx context.Context, id uuid.UUID) error
	ListMembershipsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMembership, error)
	ListMemberProfilesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.GroupMemberProfile, error)
	ListPendingClaimsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.PendingClaim, error)
	// ListMemberEmailsByGroup returns a map of userID → email for all members of
	// a group. Used by the email notification channel to look up recipient addresses.
	ListMemberEmailsByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]string, error)
}

// ListRepo is the interface for list repository operations.
type ListRepo interface {
	CreateList(ctx context.Context, list *models.List) error
	GetListByID(ctx context.Context, id uuid.UUID) (*models.List, error)
	GetListsByIDs(ctx context.Context, ids []uuid.UUID) ([]models.List, error)
	ListListsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.List, error)
	ListItemPreviewLinesByListIDs(ctx context.Context, listIDs []uuid.UUID, perList int) (map[uuid.UUID][]string, error)
	UpdateList(ctx context.Context, list *models.List) error
	HardDeleteList(ctx context.Context, id uuid.UUID) error
	SetListArchived(ctx context.Context, id, actorID uuid.UUID, archived bool) error
	CreateItem(ctx context.Context, item *models.ListItem) error
	CreateItems(ctx context.Context, items []models.ListItem) error
	BulkMarkItemsChecked(ctx context.Context, userID uuid.UUID, itemIDs []uuid.UUID) (int64, error)
	GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error)
	GetItemByListNameUnit(ctx context.Context, listID uuid.UUID, name, unit string) (*models.ListItem, error)
	ListItemsByList(ctx context.Context, listID uuid.UUID, limit, offset int) ([]models.ListItem, error)
	ListItemsByListIDs(ctx context.Context, listIDs []uuid.UUID) (map[uuid.UUID][]models.ListItem, error)
	UpdateItem(ctx context.Context, item *models.ListItem) error
	HardDeleteItem(ctx context.Context, id uuid.UUID) error
	SoftDeleteItem(ctx context.Context, id uuid.UUID) error
	SoftDeleteItemsByList(ctx context.Context, listID uuid.UUID, onlyChecked bool) (int64, error)
	BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error
	ClaimItem(ctx context.Context, listID, id, userID uuid.UUID) error
	UnclaimItem(ctx context.Context, listID, id, actorID uuid.UUID) error
	CreateShoppingLocation(ctx context.Context, location *models.ShoppingLocation) error
	ListShoppingLocationsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.ShoppingLocation, error)
	CreateProduct(ctx context.Context, product *models.Product) error
	ListProductsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Product, error)
	SearchProducts(ctx context.Context, groupID uuid.UUID, query string, limit int) ([]models.Product, error)
	CostSummary(ctx context.Context, listID uuid.UUID) (totalCents int, equalShareCents int, userContributions map[uuid.UUID]int, err error)
}

// MealPlanRepo is the interface for meal plan repository operations.
type MealPlanRepoIface interface {
	CreateMealPlan(ctx context.Context, mp *models.MealPlan) error
	GetMealPlanByID(ctx context.Context, id uuid.UUID) (*models.MealPlan, error)
	ListMealPlansByGroup(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.MealPlan, error)
	UpdateMealPlan(ctx context.Context, mp *models.MealPlan) error
	DeleteMealPlan(ctx context.Context, id uuid.UUID) error
}

// TemplateRepo is the interface for template repository operations.
type TemplateRepo interface {
	CreateTemplate(ctx context.Context, template *models.Template) error
	GetTemplateByID(ctx context.Context, id uuid.UUID) (*models.Template, error)
	ListTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Template, error)
	UpdateTemplate(ctx context.Context, template *models.Template) error
	DeleteTemplate(ctx context.Context, id uuid.UUID) error
	CreateTemplateItem(ctx context.Context, item *models.TemplateItem) error
	ListTemplateItems(ctx context.Context, templateID uuid.UUID) ([]models.TemplateItem, error)
	UpdateTemplateItem(ctx context.Context, item *models.TemplateItem) error
	DeleteTemplateItem(ctx context.Context, id uuid.UUID) error
	CreateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error
	GetChoreTemplateByID(ctx context.Context, id uuid.UUID) (*models.ChoreTemplate, error)
	ListChoreTemplates(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ChoreTemplate, error)
	UpdateChoreTemplate(ctx context.Context, ct *models.ChoreTemplate) error
	DeleteChoreTemplate(ctx context.Context, id uuid.UUID) error
}

// ChoreRepo is the interface for chore repository operations.
type ChoreRepo interface {
	CreateChore(ctx context.Context, chore *models.Chore) error
	GetChoreByID(ctx context.Context, id uuid.UUID) (*models.Chore, error)
	ListChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Chore, error)
	ListCurrentChoresByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.CurrentChore, error)
	GetChoreStats(ctx context.Context, choreID uuid.UUID) (*models.ChoreStats, error)
	GetChoreLoadByGroup(ctx context.Context, groupID uuid.UUID, since time.Time) ([]models.ChoreLoadEntry, error)
	UpdateChore(ctx context.Context, chore *models.Chore) error
	DeleteChore(ctx context.Context, id uuid.UUID) error
	CreateRotationState(ctx context.Context, state *models.ChoreRotationState) error
	GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error)
	GetRotationStatesByChoreIDs(ctx context.Context, choreIDs []uuid.UUID) ([]models.ChoreRotationState, error)
	UpdateRotationState(ctx context.Context, state *models.ChoreRotationState) error
	BulkUpdateRotationStates(ctx context.Context, states []models.ChoreRotationState) error
	CreateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error
	ListAssignments(ctx context.Context, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error)
	UpdateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error
	CompleteAssignment(ctx context.Context, id uuid.UUID, status string, completedAt time.Time, skipReason *string) (bool, error)
	CompleteAssignmentAndAdvance(ctx context.Context, assignmentID uuid.UUID, status string, completedAt time.Time, skipReason *string, completion *models.ChoreCompletion, nextState *models.ChoreRotationState, nextAssignment *models.ChoreAssignment) (bool, error)
	DeleteAssignment(ctx context.Context, id uuid.UUID) error
	CreateCompletion(ctx context.Context, completion *models.ChoreCompletion) error
	GetPendingAssignmentByChore(ctx context.Context, choreID uuid.UUID) (*models.ChoreAssignment, error)
	ListDueAssignments(ctx context.Context, from, to time.Time) ([]models.ChoreAssignment, error)
	ListDueAssignmentsByGroup(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.ChoreAssignment, error)
	CreateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error
	GetSubtaskByID(ctx context.Context, id uuid.UUID) (*models.ChoreSubtask, error)
	ListSubtasksByChore(ctx context.Context, choreID uuid.UUID) ([]models.ChoreSubtask, error)
	UpdateSubtask(ctx context.Context, subtask *models.ChoreSubtask) error
	DeleteSubtask(ctx context.Context, id uuid.UUID) error
	DeleteSubtasksByChore(ctx context.Context, choreID uuid.UUID) error
}

// FinanceRepoIface is the interface for finance repository operations.
type FinanceRepoIface interface {
	CreateExpense(ctx context.Context, e *models.Expense) error
	GetExpenseByID(ctx context.Context, id uuid.UUID) (*models.Expense, error)
	ListExpensesByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Expense, error)
	ListAllExpensesByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Expense, error)
	UpdateExpense(ctx context.Context, e *models.Expense) error
	DeleteExpense(ctx context.Context, id uuid.UUID) error
	CreateSplit(ctx context.Context, s *models.Split) error
	ListSplitsByExpense(ctx context.Context, expenseID uuid.UUID) ([]models.Split, error)
	UpdateSplit(ctx context.Context, s *models.Split) error
	DeleteSplit(ctx context.Context, id uuid.UUID) error
	CreateSettlement(ctx context.Context, s *models.Settlement) error
	ListSettlementsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.Settlement, error)
	ListAllSettlementsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Settlement, error)
	UpdateSettlementStatus(ctx context.Context, id uuid.UUID, status models.SettlementStatus, respondedAt time.Time) error
	DeleteSettlement(ctx context.Context, id uuid.UUID) error
	ListSplitsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Split, error)
	CreateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error
	GetRecurringExpenseByID(ctx context.Context, id uuid.UUID) (*models.RecurringExpense, error)
	ListRecurringExpenses(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.RecurringExpense, error)
	ListRecurringExpensesByDateRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.RecurringExpense, error)
	ListExpensesByDateRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.Expense, error)
	UpdateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error
	DeleteRecurringExpense(ctx context.Context, id uuid.UUID) error
	GetSplitByID(ctx context.Context, id uuid.UUID) (*models.Split, error)
	GetSettlementByID(ctx context.Context, id uuid.UUID) (*models.Settlement, error)
	CreateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error
	UpdateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error
	GetGroupBalanceAggregates(ctx context.Context, groupID uuid.UUID) ([]models.BalanceAggregate, error)
}

// RecipeRepoIface is the interface for recipe repository operations.
type RecipeRepoIface interface {
	CreateRecipe(ctx context.Context, rec *models.Recipe) error
	GetRecipeByID(ctx context.Context, id uuid.UUID) (*models.Recipe, error)
	GetRecipesByIDs(ctx context.Context, ids []uuid.UUID) (map[uuid.UUID]*models.Recipe, error)
	ListRecipes(ctx context.Context, userID uuid.UUID, filter RecipeFilter) ([]models.Recipe, error)
	ListDistinctTags(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit int) ([]models.RecipeTagCount, error)
	ListRecipesByCollection(ctx context.Context, collectionID uuid.UUID, limit, offset int) ([]models.Recipe, error)
	UpdateRecipe(ctx context.Context, rec *models.Recipe) error
	DeleteRecipe(ctx context.Context, id uuid.UUID) error
	CreateIngredient(ctx context.Context, ing *models.RecipeIngredient) error
	ListIngredients(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeIngredient, error)
	ListIngredientsByRecipeIDs(ctx context.Context, recipeIDs []uuid.UUID) (map[uuid.UUID][]models.RecipeIngredient, error)
	UpdateIngredient(ctx context.Context, ing *models.RecipeIngredient) error
	DeleteIngredient(ctx context.Context, id uuid.UUID) error
	CreateStep(ctx context.Context, step *models.RecipeStep) error
	ListSteps(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeStep, error)
	UpdateStep(ctx context.Context, step *models.RecipeStep) error
	DeleteStep(ctx context.Context, id uuid.UUID) error
	CreateCollection(ctx context.Context, c *models.Collection) error
	GetCollectionByID(ctx context.Context, id uuid.UUID) (*models.Collection, error)
	ListCollections(ctx context.Context, userID uuid.UUID, groupID *uuid.UUID, limit, offset int) ([]models.Collection, error)
	UpdateCollection(ctx context.Context, c *models.Collection) error
	DeleteCollection(ctx context.Context, id uuid.UUID) error
	CreateRecipeShare(ctx context.Context, share *models.RecipeShare) error
	GetRecipeShareByUser(ctx context.Context, recipeID, userID uuid.UUID) (*models.RecipeShare, error)
	CreateCollectionRecipe(ctx context.Context, cr *models.CollectionRecipe) error
	DeleteCollectionRecipe(ctx context.Context, collectionID, recipeID uuid.UUID) error
}

// NotificationRepo is the interface for notification repository operations.
type NotificationRepo interface {
	CreateNotification(ctx context.Context, n *models.Notification) error
	GetNotificationByID(ctx context.Context, id uuid.UUID) (*models.Notification, error)
	ListNotificationsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Notification, error)
	ListNotificationsByUserAndGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, limit, offset int) ([]models.Notification, error)
	ListNotificationsByUserBefore(ctx context.Context, userID uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error)
	ListNotificationsByUserAndGroupsBefore(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID, before time.Time, beforeID uuid.UUID, limit int) ([]models.Notification, error)
	CountUnreadNotifications(ctx context.Context, userID uuid.UUID) (int, error)
	CountUnreadNotificationsByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) (int, error)
	MarkAsRead(ctx context.Context, id uuid.UUID) error
	MarkAllAsRead(ctx context.Context, userID uuid.UUID) error
	MarkAllAsReadByGroups(ctx context.Context, userID uuid.UUID, groupIDs []uuid.UUID) error
	DeleteNotification(ctx context.Context, id uuid.UUID) error
	GetPreference(ctx context.Context, userID, groupID uuid.UUID) (*models.NotificationPreference, error)
	GetPreferencesByUser(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error)
	GetPreferencesByGroup(ctx context.Context, groupID uuid.UUID) (map[uuid.UUID]*models.NotificationPreference, error)
	CreateNotificationsBatch(ctx context.Context, notifications []models.Notification) error
	QueueListItemNotification(ctx context.Context, groupID, actorID, listID uuid.UUID, actorName, listName, itemName string) error
	FlushListNotificationBatches(ctx context.Context, actorID, listID uuid.UUID) error
	UpsertPreference(ctx context.Context, pref *models.NotificationPreference) error
}

// ActivityRepo is the interface for activity repository operations.
type ActivityRepo interface {
	ListRecentActivity(ctx context.Context, groupID uuid.UUID, limit int) ([]models.ActivityEvent, error)
	CountWeeklyActivity(ctx context.Context, groupID uuid.UUID) (map[string]int, error)
}

// PinwallRepo is the interface for pinwall repository operations.
type PinwallRepo interface {
	CreatePost(ctx context.Context, p *models.PinwallPost) error
	ListPostsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error)
	GetPostByID(ctx context.Context, id uuid.UUID) (*models.PinwallPost, error)
	DeletePost(ctx context.Context, id uuid.UUID) error
	UpdatePostPosition(ctx context.Context, id uuid.UUID, x, y float64) error
}

// CalendarPinwallRepo lists pinwall reminders for calendar aggregation.
type CalendarPinwallRepo interface {
	ListPostsByGroupAndRemindAtRange(ctx context.Context, groupID uuid.UUID, from, to time.Time) ([]models.PinwallPost, error)
}

// AttachmentRepo is the interface for attachment repository operations.
type AttachmentRepo interface {
	Reserve(ctx context.Context, a *models.Attachment, limitBytes int64) error
	GetStorageUsage(ctx context.Context, groupID uuid.UUID) (*models.AttachmentStorageUsage, error)
	GetByID(ctx context.Context, id uuid.UUID) (*models.Attachment, error)
	UpdateObjectKey(ctx context.Context, id uuid.UUID, objectKey string) error
	FinalizeReservation(ctx context.Context, id uuid.UUID, byteSize, limitBytes int64) error
	MarkFailed(ctx context.Context, id uuid.UUID) error
	ListCleanupCandidates(ctx context.Context, expiredBefore time.Time, limit int) ([]models.Attachment, error)
	Delete(ctx context.Context, id uuid.UUID) error
}
