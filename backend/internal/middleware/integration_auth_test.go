package middleware

import (
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/mitlist-app/mitlist/internal/services"
)

func TestIntegrationCredentialScopesAndGroups(t *testing.T) {
	group := uuid.New()
	identity := &services.CredentialIdentity{
		GroupIDs: []uuid.UUID{group},
		Scopes:   []string{"lists:read", "chores:*"},
	}
	ctx := WithIntegrationCredential(httptest.NewRequest("GET", "/", nil).Context(), identity)
	if !HasScope(ctx, "lists:read") || !CredentialHasScope(ctx, "chores:write") {
		t.Fatal("expected domain scopes to authorize matching actions")
	}
	if HasScope(ctx, "lists:write") {
		t.Fatal("read scope must not authorize writes")
	}
	if !AllowsGroup(ctx, group) || AllowsGroup(ctx, uuid.New()) {
		t.Fatal("group scope was not enforced")
	}
}

func TestIntegrationGroupIDExtraction(t *testing.T) {
	group := uuid.New()
	req := httptest.NewRequest("GET", "/api/v1/lists?group_id="+group.String(), nil)
	got, ok := integrationGroupID(req)
	if !ok || got != group {
		t.Fatalf("integrationGroupID() = %v, %v; want %v, true", got, ok, group)
	}
	req = httptest.NewRequest("GET", "/api/v1/lists", nil)
	if _, ok := integrationGroupID(req); ok {
		t.Fatal("missing group_id must not be treated as scoped")
	}
}
