package handlers

import (
	"context"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
)

func TestAttachments_UploadIntent_HappyPath_ReturnsPresignedPutURL(t *testing.T) {
	clearTables(t)

	// Arrange: user + group + membership
	user := createTestUser(t, "attach@example.com", "password123!")

	groupRepo := newTestGroupRepo()
	group := &models.Group{Name: "Test Group", CreatedBy: user.ID}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		GroupID: group.ID,
		UserID:  user.ID,
		Role:    "member",
	}))

	// Storage: presigning is offline (no network), but needs bucket+endpoint+creds.
	cfg := &config.Config{
		AWSAccessKeyID:       "test-access",
		AWSSecretAccessKey:   "test-secret",
		AWSRegion:            "us-east-1",
		S3BucketName:         "test-bucket",
		S3EndpointURL:        "https://example.com",
		MaxFileSizeBytes:     50 * 1024 * 1024,
		MaxStoragePerGroupGB: 10,
	}
	storage := storagesvc.New(cfg)

	attRepo := repositories.NewAttachmentRepository(testDB)
	svc := services.NewAttachmentService(cfg, attRepo, groupRepo, storage)
	h := NewAttachmentHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)

	// Act
	rec := execRequest(t, r, "POST", "/attachments/upload-intent", map[string]any{
		"group_id":     group.ID,
		"purpose":      "debug_diagnostic",
		"filename":     "test.txt",
		"content_type": "text/plain",
		"byte_size":    12,
	}, generateTestToken(user.ID))

	// Assert
	requireStatus(t, rec, 201)
	var body map[string]any
	parseJSONResponse(t, rec, &body)
	require.NotEmpty(t, body["upload_url"])
	require.NotEmpty(t, body["object_key"])

	att, ok := body["attachment"].(map[string]any)
	require.True(t, ok)
	require.NotEqual(t, uuid.Nil.String(), att["id"])
	require.Equal(t, group.ID.String(), att["group_id"])

	usageRec := execRequest(t, r, "GET", "/attachments/storage-usage?group_id="+group.ID.String(), nil, generateTestToken(user.ID))
	requireStatus(t, usageRec, 200)
	var usage map[string]any
	parseJSONResponse(t, usageRec, &usage)
	require.EqualValues(t, 0, usage["used_bytes"])
	require.EqualValues(t, 12, usage["reserved_bytes"])
	require.EqualValues(t, 10_000_000_000, usage["limit_bytes"])
	require.Equal(t, false, usage["unlimited"])
}
