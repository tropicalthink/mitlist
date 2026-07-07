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

func TestListItemPhotos_AttachAndList(t *testing.T) {
	clearTables(t)

	user := createTestUser(t, "listphotos@example.com", "password123")
	groupRepo := newTestGroupRepo()
	listRepo := newTestListRepo()

	group := &models.Group{Name: "Lists", CreatedBy: user.ID}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		GroupID: group.ID,
		UserID:  user.ID,
		Role:    "member",
	}))

	list := &models.List{GroupID: group.ID, Name: "Groceries", Type: "shopping"}
	require.NoError(t, listRepo.CreateList(context.Background(), list))

	item := &models.ListItem{ListID: list.ID, Name: "Milk", Quantity: 1, Unit: "", Checked: false, Position: 0}
	require.NoError(t, listRepo.CreateItem(context.Background(), item))

	attRepo := repositories.NewAttachmentRepository(testDB)
	att := &models.Attachment{
		GroupID:     group.ID,
		UserID:      user.ID,
		Purpose:     "list_item_photo",
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
	itemAttachRepo := repositories.NewListItemAttachmentRepository(testDB)
	svc := services.NewListItemPhotoService(listRepo, groupRepo, attRepo, itemAttachRepo, storage)
	h := NewListItemPhotoHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)

	rec := execRequest(t, r, "POST", "/lists/items/"+item.ID.String()+"/photos", map[string]any{
		"group_id":      group.ID,
		"attachment_id": att.ID,
	}, generateTestToken(user.ID))
	requireStatus(t, rec, 204)

	rec2 := execRequest(t, r, "GET", "/lists/items/"+item.ID.String()+"/photos?group_id="+group.ID.String(), nil, generateTestToken(user.ID))
	requireStatus(t, rec2, 200)
	var out []map[string]any
	parseJSONResponse(t, rec2, &out)
	require.Len(t, out, 1)
	require.Equal(t, att.ID.String(), out[0]["attachment_id"])
	require.NotEmpty(t, out[0]["url"])
}
