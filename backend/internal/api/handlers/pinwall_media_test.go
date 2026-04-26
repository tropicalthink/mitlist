package handlers

import (
	"context"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/internal/models"
	"github.com/yourorg/mitlist/internal/repositories"
	"github.com/yourorg/mitlist/internal/services"
	storagesvc "github.com/yourorg/mitlist/internal/services/storage"
)

func TestPinwallMedia_AttachAndList(t *testing.T) {
	clearTables(t)

	user := createTestUser(t, "pinwallmedia@example.com", "password123")
	groupRepo := newTestGroupRepo()

	group := &models.Group{Name: "Pinwall", CreatedBy: user.ID}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		GroupID: group.ID,
		UserID:  user.ID,
		Role:    "member",
	}))

	// Create a post.
	pinRepo := repositories.NewPinwallRepository(testDB)
	post := &models.PinwallPost{GroupID: group.ID, UserID: user.ID, Content: "hi"}
	require.NoError(t, pinRepo.CreatePost(context.Background(), post))

	// Create a ready attachment.
	attRepo := repositories.NewAttachmentRepository(testDB)
	att := &models.Attachment{
		GroupID:     group.ID,
		UserID:      user.ID,
		Purpose:     "pinwall_media",
		ObjectKey:   "groups/" + group.ID.String() + "/attachments/" + uuid.New().String() + "/img.jpg",
		ContentType: "image/jpeg",
		ByteSize:    10,
		Status:      models.AttachmentStatusReady,
	}
	require.NoError(t, attRepo.Create(context.Background(), att))

	cfg := &config.Config{
		AWSAccessKeyID:     "test-access",
		AWSSecretAccessKey: "test-secret",
		AWSRegion:          "us-east-1",
		S3BucketName:       "test-bucket",
		S3EndpointURL:      "https://example.com",
	}
	storage := storagesvc.New(cfg)
	postAttachRepo := repositories.NewPinwallAttachmentRepository(testDB)
	svc := services.NewPinwallMediaService(pinRepo, groupRepo, attRepo, postAttachRepo, storage)
	h := NewPinwallMediaHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)

	// Attach
	rec := execRequest(t, r, "POST", "/pinwall/posts/"+post.ID.String()+"/attachments", map[string]any{
		"group_id":      group.ID,
		"attachment_id": att.ID,
	}, generateTestToken(user.ID))
	requireStatus(t, rec, 204)

	// List
	rec2 := execRequest(t, r, "GET", "/pinwall/posts/"+post.ID.String()+"/attachments?group_id="+group.ID.String(), nil, generateTestToken(user.ID))
	requireStatus(t, rec2, 200)
	var out []map[string]any
	parseJSONResponse(t, rec2, &out)
	require.Len(t, out, 1)
	require.Equal(t, att.ID.String(), out[0]["attachment_id"])
	require.NotEmpty(t, out[0]["url"])

	// Ensure created_at parses like RFC3339 in json encoder (sanity).
	_, err := time.Parse(time.RFC3339Nano, out[0]["created_at"].(string))
	require.NoError(t, err)
}

