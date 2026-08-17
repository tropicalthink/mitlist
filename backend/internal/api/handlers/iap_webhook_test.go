package handlers

import (
	"context"
	"errors"
	"net/http/httptest"
	"testing"

	"google.golang.org/api/idtoken"
)

func TestAuthenticateGooglePush(t *testing.T) {
	h := &IAPWebhookHandler{
		googleAudience:       "https://api.mitlist.me/webhooks/google",
		googleServiceAccount: "pubsub@project.iam.gserviceaccount.com",
		validateGoogleToken: func(_ context.Context, token, audience string) (*idtoken.Payload, error) {
			if token != "signed-token" || audience != "https://api.mitlist.me/webhooks/google" {
				return nil, errors.New("invalid token")
			}
			return &idtoken.Payload{Claims: map[string]any{
				"email": "pubsub@project.iam.gserviceaccount.com", "email_verified": true,
			}}, nil
		},
	}

	req := httptest.NewRequest("POST", "/webhooks/google", nil)
	if err := h.authenticateGooglePush(req); err == nil {
		t.Fatal("missing bearer token must be rejected")
	}
	req.Header.Set("Authorization", "Bearer signed-token")
	if err := h.authenticateGooglePush(req); err != nil {
		t.Fatalf("valid authenticated push rejected: %v", err)
	}
	h.googleServiceAccount = "other@project.iam.gserviceaccount.com"
	if err := h.authenticateGooglePush(req); err == nil {
		t.Fatal("unexpected service-account identity must be rejected")
	}
}
