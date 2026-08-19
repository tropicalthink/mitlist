package services

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/pkg/validation"
)

const (
	IntegrationTokenPrefix = "ml_int_"
	IntegrationScopeRead   = "read"
	IntegrationScopeWrite  = "write"
)

var integrationDomainScopes = map[string]struct{}{
	"lists:read": {}, "lists:write": {}, "chores:read": {}, "chores:write": {},
	"calendar:read": {}, "recipes:read": {}, "recipes:write": {},
	"finance:read": {}, "finance:write": {}, "pinwall:read": {}, "pinwall:write": {},
	"notifications:read": {}, "notifications:write": {}, "groceries:read": {}, "groceries:write": {},
	"activity:read": {}, "attachments:read": {}, "attachments:write": {},
	"groups:read": {}, "groups:write": {},
}

var integrationScopeDomains = map[string]struct{}{
	"lists": {}, "chores": {}, "calendar": {}, "recipes": {}, "finance": {},
	"pinwall": {}, "notifications": {}, "groceries": {}, "activity": {},
	"attachments": {}, "groups": {},
}

// CredentialIdentity is the authorization data carried by an integration
// bearer token. It deliberately does not contain the raw token.
type CredentialIdentity struct {
	CredentialID uuid.UUID
	UserID       uuid.UUID
	GroupIDs     []uuid.UUID
	Scopes       []string
}

type IntegrationCredentialService struct {
	repo   repositories.IntegrationCredentialRepo
	groups repositories.GroupRepo
}

func NewIntegrationCredentialService(repo repositories.IntegrationCredentialRepo, groups repositories.GroupRepo) *IntegrationCredentialService {
	return &IntegrationCredentialService{repo: repo, groups: groups}
}

type CreateIntegrationCredentialInput struct {
	Name     string
	GroupIDs []uuid.UUID
	Scopes   []string
}

// Create issues a random 256-bit secret. Only its SHA-256 digest is persisted,
// and the returned raw token must be shown to the caller exactly once.
func (s *IntegrationCredentialService) Create(ctx context.Context, userID uuid.UUID, input CreateIntegrationCredentialInput) (*models.IntegrationCredential, string, error) {
	name := strings.TrimSpace(input.Name)
	if err := validation.RequiredString(name, "name"); err != nil {
		return nil, "", &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if err := validation.MaxLength(name, 100, "name"); err != nil {
		return nil, "", &api.ValidationError{Field: "name", Message: err.Error()}
	}
	if len(input.GroupIDs) == 0 {
		return nil, "", &api.ValidationError{Field: "group_ids", Message: "at least one group is required"}
	}
	groupIDs, err := uniqueUUIDs(input.GroupIDs)
	if err != nil {
		return nil, "", &api.ValidationError{Field: "group_ids", Message: err.Error()}
	}
	for _, groupID := range groupIDs {
		membership, membershipErr := s.groups.GetMembership(ctx, groupID, userID)
		if membershipErr != nil || membership == nil || (membership.Role != "admin" && membership.Role != "member") {
			return nil, "", &api.PermissionDeniedError{Message: "you must belong to every selected group"}
		}
	}

	scopes, err := normalizeIntegrationScopes(input.Scopes)
	if err != nil {
		return nil, "", &api.ValidationError{Field: "scopes", Message: err.Error()}
	}
	rawSecret, err := randomIntegrationSecret()
	if err != nil {
		return nil, "", err
	}
	rawToken := IntegrationTokenPrefix + rawSecret

	credential := &models.IntegrationCredential{
		UserID: userID, Name: name, TokenPrefix: tokenDisplayPrefix(rawToken),
		GroupIDs: groupIDs, Scopes: scopes, CreatedAt: time.Now().UTC(),
	}
	if err := s.repo.Create(ctx, credential, HashIntegrationToken(rawToken)); err != nil {
		return nil, "", err
	}
	return credential, rawToken, nil
}

func (s *IntegrationCredentialService) CreateCredential(ctx context.Context, userID uuid.UUID, input CreateIntegrationCredentialInput) (*models.IntegrationCredential, string, error) {
	return s.Create(ctx, userID, input)
}

func (s *IntegrationCredentialService) List(ctx context.Context, userID uuid.UUID) ([]models.IntegrationCredential, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *IntegrationCredentialService) Revoke(ctx context.Context, userID, id uuid.UUID) error {
	return s.repo.Revoke(ctx, userID, id)
}

// Authenticate hashes a presented token and looks up only active rows. Last
// use metadata is best effort and never turns a valid request into a failure.
func (s *IntegrationCredentialService) Authenticate(ctx context.Context, rawToken, ip, userAgent string) (*CredentialIdentity, error) {
	if !strings.HasPrefix(rawToken, IntegrationTokenPrefix) || len(rawToken) <= len(IntegrationTokenPrefix) {
		return nil, repositories.ErrIntegrationCredentialNotFound
	}
	credential, err := s.repo.GetActiveByHash(ctx, HashIntegrationToken(rawToken))
	if err != nil {
		return nil, err
	}
	if err := s.repo.TouchLastUsed(ctx, credential.ID, ip, userAgent); err != nil {
		// Authentication remains available if telemetry storage is temporarily
		// unavailable. The next request retries the update.
	}
	return &CredentialIdentity{CredentialID: credential.ID, UserID: credential.UserID,
		GroupIDs: append([]uuid.UUID(nil), credential.GroupIDs...), Scopes: append([]string(nil), credential.Scopes...)}, nil
}

func (s *IntegrationCredentialService) Validate(ctx context.Context, rawToken, ip, userAgent string) (*CredentialIdentity, error) {
	return s.Authenticate(ctx, rawToken, ip, userAgent)
}

func HashIntegrationToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

func randomIntegrationSecret() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(b), nil
}

func tokenDisplayPrefix(token string) string {
	const visible = 12
	if len(token) <= visible {
		return token
	}
	return token[:visible]
}

func uniqueUUIDs(ids []uuid.UUID) ([]uuid.UUID, error) {
	seen := make(map[uuid.UUID]struct{}, len(ids))
	out := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if id == uuid.Nil {
			return nil, errors.New("group_ids contains an invalid UUID")
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out, nil
}

func normalizeIntegrationScopes(scopes []string) ([]string, error) {
	if len(scopes) == 0 {
		return []string{IntegrationScopeRead}, nil
	}
	seen := make(map[string]struct{}, len(scopes))
	out := make([]string, 0, len(scopes))
	for _, scope := range scopes {
		scope = strings.ToLower(strings.TrimSpace(scope))
		if scope != IntegrationScopeRead && scope != IntegrationScopeWrite && scope != "*" {
			if _, ok := integrationDomainScopes[scope]; !ok {
				parts := strings.Split(scope, ":")
				if len(parts) == 2 && parts[1] == "*" {
					if _, domainOK := integrationScopeDomains[parts[0]]; domainOK {
						seen[scope] = struct{}{}
						out = append(out, scope)
						continue
					}
				}
				return nil, errors.New("unsupported integration scope")
			}
		}
		if _, ok := seen[scope]; ok {
			continue
		}
		seen[scope] = struct{}{}
		out = append(out, scope)
	}
	return out, nil
}
