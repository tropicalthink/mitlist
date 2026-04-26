package repositories

import (
	"context"

	"github.com/google/uuid"
	"github.com/yourorg/mitlist/internal/models"
)

// UserRepo is the interface for user repository operations.
type UserRepo interface {
	Create(ctx context.Context, user *models.User) error
	GetByID(ctx context.Context, id uuid.UUID) (*models.User, error)
	GetByEmail(ctx context.Context, email string) (*models.User, error)
	GetByOAuth(ctx context.Context, provider, providerUserID string) (*models.User, error)
	Update(ctx context.Context, user *models.User) error
	SoftDelete(ctx context.Context, id uuid.UUID) error
	List(ctx context.Context, limit, offset int) ([]models.User, error)
}

// AuthRepo is the interface for auth repository operations.
type AuthRepo interface {
	CreateOAuthAccount(ctx context.Context, account *models.OAuthAccount) error
	GetOAuthByProviderID(ctx context.Context, provider, providerUserID string) (*models.OAuthAccount, error)
	CreatePasswordResetToken(ctx context.Context, token *models.PasswordResetToken) error
	GetPasswordResetToken(ctx context.Context, token string) (*models.PasswordResetToken, error)
	ConsumeToken(ctx context.Context, id uuid.UUID) error
	CreatePushSubscription(ctx context.Context, sub *models.PushSubscription) error
	ListPushSubscriptionsByUser(ctx context.Context, userID uuid.UUID) ([]models.PushSubscription, error)
	DeletePushSubscription(ctx context.Context, id uuid.UUID) error
}

// GroupRepo is the interface for group repository operations.
type GroupRepo interface {
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
}

// ListRepo is the interface for list repository operations.
type ListRepo interface {
	CreateList(ctx context.Context, list *models.List) error
	GetListByID(ctx context.Context, id uuid.UUID) (*models.List, error)
	ListListsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.List, error)
	// ListItemPreviewLinesByListIDs returns up to perList item names per list (by position), for hub previews.
	ListItemPreviewLinesByListIDs(ctx context.Context, listIDs []uuid.UUID, perList int) (map[uuid.UUID][]string, error)
	UpdateList(ctx context.Context, list *models.List) error
	HardDeleteList(ctx context.Context, id uuid.UUID) error
	CreateItem(ctx context.Context, item *models.ListItem) error
	GetItemByID(ctx context.Context, id uuid.UUID) (*models.ListItem, error)
	ListItemsByList(ctx context.Context, listID uuid.UUID, limit, offset int) ([]models.ListItem, error)
	UpdateItem(ctx context.Context, item *models.ListItem) error
	HardDeleteItem(ctx context.Context, id uuid.UUID) error
	SoftDeleteItem(ctx context.Context, id uuid.UUID) error
	BatchUpdateItemPositions(ctx context.Context, items []models.ListItem) error
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
	UpdateChore(ctx context.Context, chore *models.Chore) error
	DeleteChore(ctx context.Context, id uuid.UUID) error
	CreateRotationState(ctx context.Context, state *models.ChoreRotationState) error
	GetRotationState(ctx context.Context, choreID uuid.UUID) (*models.ChoreRotationState, error)
	UpdateRotationState(ctx context.Context, state *models.ChoreRotationState) error
	BulkUpdateRotationStates(ctx context.Context, states []models.ChoreRotationState) error
	CreateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error
	ListAssignments(ctx context.Context, choreID uuid.UUID, limit, offset int) ([]models.ChoreAssignment, error)
	UpdateAssignment(ctx context.Context, assignment *models.ChoreAssignment) error
	DeleteAssignment(ctx context.Context, id uuid.UUID) error
	CreateCompletion(ctx context.Context, completion *models.ChoreCompletion) error
	GetPendingAssignmentByChore(ctx context.Context, choreID uuid.UUID) (*models.ChoreAssignment, error)
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
	DeleteSettlement(ctx context.Context, id uuid.UUID) error
	ListSplitsByGroup(ctx context.Context, groupID uuid.UUID) ([]models.Split, error)
	CreateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error
	GetRecurringExpenseByID(ctx context.Context, id uuid.UUID) (*models.RecurringExpense, error)
	ListRecurringExpenses(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.RecurringExpense, error)
	UpdateRecurringExpense(ctx context.Context, re *models.RecurringExpense) error
	DeleteRecurringExpense(ctx context.Context, id uuid.UUID) error
	GetSplitByID(ctx context.Context, id uuid.UUID) (*models.Split, error)
	GetSettlementByID(ctx context.Context, id uuid.UUID) (*models.Settlement, error)
	CreateExpenseWithSplits(ctx context.Context, e *models.Expense, splits []models.Split) error
}

// RecipeRepoIface is the interface for recipe repository operations.
type RecipeRepoIface interface {
	CreateRecipe(ctx context.Context, rec *models.Recipe) error
	GetRecipeByID(ctx context.Context, id uuid.UUID) (*models.Recipe, error)
	ListRecipesByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Recipe, error)
	UpdateRecipe(ctx context.Context, rec *models.Recipe) error
	DeleteRecipe(ctx context.Context, id uuid.UUID) error
	CreateIngredient(ctx context.Context, ing *models.RecipeIngredient) error
	ListIngredients(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeIngredient, error)
	UpdateIngredient(ctx context.Context, ing *models.RecipeIngredient) error
	DeleteIngredient(ctx context.Context, id uuid.UUID) error
	CreateStep(ctx context.Context, step *models.RecipeStep) error
	ListSteps(ctx context.Context, recipeID uuid.UUID) ([]models.RecipeStep, error)
	UpdateStep(ctx context.Context, step *models.RecipeStep) error
	DeleteStep(ctx context.Context, id uuid.UUID) error
	CreateCollection(ctx context.Context, c *models.Collection) error
	GetCollectionByID(ctx context.Context, id uuid.UUID) (*models.Collection, error)
	ListCollections(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.Collection, error)
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
	MarkAsRead(ctx context.Context, id uuid.UUID) error
	MarkAllAsRead(ctx context.Context, userID uuid.UUID) error
	DeleteNotification(ctx context.Context, id uuid.UUID) error
	GetPreferences(ctx context.Context, userID uuid.UUID) ([]models.NotificationPreference, error)
	UpdatePreferences(ctx context.Context, pref *models.NotificationPreference) error
}

// ActivityRepo is the interface for activity repository operations.
type ActivityRepo interface {
	LogActivity(ctx context.Context, a *models.ActivityLog) error
	GetActivityLogByID(ctx context.Context, id uuid.UUID) (*models.ActivityLog, error)
	ListActivityLogsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.ActivityLog, error)
	DeleteActivityLog(ctx context.Context, id uuid.UUID) error
}

// AssistantRepo is the interface for assistant repository operations.
type AssistantRepo interface {
	CreateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error)
	GetSessionByID(ctx context.Context, id uuid.UUID) (*models.ChatSession, error)
	ListSessionsByUser(ctx context.Context, userID uuid.UUID, limit, offset int) ([]models.ChatSession, error)
	UpdateSession(ctx context.Context, s *models.ChatSession) (*models.ChatSession, error)
	DeleteSession(ctx context.Context, id uuid.UUID) error
	CreateMessage(ctx context.Context, m *models.ChatMessage) (*models.ChatMessage, error)
	ListMessagesBySession(ctx context.Context, sessionID uuid.UUID, limit, offset int) ([]models.ChatMessage, error)
}

// PinwallRepo is the interface for pinwall repository operations.
type PinwallRepo interface {
	CreatePost(ctx context.Context, p *models.PinwallPost) error
	ListPostsByGroup(ctx context.Context, groupID uuid.UUID, limit, offset int) ([]models.PinwallPost, error)
	GetPostByID(ctx context.Context, id uuid.UUID) (*models.PinwallPost, error)
	DeletePost(ctx context.Context, id uuid.UUID) error
}
