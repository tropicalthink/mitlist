package handlers

import (
	"context"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/services"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
)

func TestExpenses_Receipts_AttachAndList(t *testing.T) {
	clearTables(t)

	user := createTestUser(t, "receipts@example.com", "password123")
	groupRepo := newTestGroupRepo()
	finRepo := newTestFinanceRepo()

	group := &models.Group{Name: "Receipts", CreatedBy: user.ID}
	require.NoError(t, groupRepo.CreateGroup(context.Background(), group))
	require.NoError(t, groupRepo.CreateMembership(context.Background(), &models.GroupMembership{
		GroupID: group.ID,
		UserID:  user.ID,
		Role:    "member",
	}))

	// Create an expense.
	exp := &models.Expense{
		GroupID:     group.ID,
		PayerID:     user.ID,
		Amount:      1234,
		Description: "Test",
		Category:    "other",
		Currency:    "USD",
		Notes:       "",
		Date:        time.Now().UTC(),
	}
	require.NoError(t, finRepo.CreateExpense(context.Background(), exp))

	// Create a ready attachment.
	attRepo := repositories.NewAttachmentRepository(testDB)
	att := &models.Attachment{
		GroupID:     group.ID,
		UserID:      user.ID,
		Purpose:     "expense_receipt",
		ObjectKey:   "groups/" + group.ID.String() + "/attachments/" + uuid.New().String() + "/receipt.jpg",
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
	expAttachRepo := repositories.NewExpenseAttachmentRepository(testDB)
	svc := services.NewExpenseReceiptService(finRepo, groupRepo, attRepo, expAttachRepo, storage)
	h := NewExpenseReceiptHandler(svc)

	r := chi.NewRouter()
	r.Use(testAuthMiddleware)
	h.RegisterRoutes(r)

	// Attach
	rec := execRequest(t, r, "POST", "/expenses/"+exp.ID.String()+"/receipts", map[string]any{
		"group_id":       group.ID,
		"attachment_id":  att.ID,
	}, generateTestToken(user.ID))
	requireStatus(t, rec, 204)

	// List
	rec2 := execRequest(t, r, "GET", "/expenses/"+exp.ID.String()+"/receipts?group_id="+group.ID.String(), nil, generateTestToken(user.ID))
	requireStatus(t, rec2, 200)
	var out []map[string]any
	parseJSONResponse(t, rec2, &out)
	require.Len(t, out, 1)
	require.NotEmpty(t, out[0]["url"])
	require.Equal(t, att.ID.String(), out[0]["attachment_id"])
}
