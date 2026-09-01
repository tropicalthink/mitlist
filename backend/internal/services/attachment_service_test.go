package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

type fakeAttachmentRepo struct {
	attachment        *models.Attachment
	storageUsage      *models.AttachmentStorageUsage
	updatedStatus     models.AttachmentStatus
	updatedByteSize   int64
	updateCalled      bool
	markFailedCalled  bool
	deleteCalled      bool
	reserveErr        error
	finalizeErr       error
	cleanupCandidates []models.Attachment
}

func (r *fakeAttachmentRepo) GetStorageUsage(ctx context.Context, groupID uuid.UUID) (*models.AttachmentStorageUsage, error) {
	return r.storageUsage, nil
}

func (r *fakeAttachmentRepo) Reserve(ctx context.Context, a *models.Attachment, limitBytes int64) error {
	if r.reserveErr != nil {
		return r.reserveErr
	}
	if a.ID == uuid.Nil {
		a.ID = uuid.New()
	}
	r.attachment = a
	return nil
}

func (r *fakeAttachmentRepo) GetByID(ctx context.Context, id uuid.UUID) (*models.Attachment, error) {
	return r.attachment, nil
}

func (r *fakeAttachmentRepo) UpdateObjectKey(ctx context.Context, id uuid.UUID, objectKey string) error {
	r.attachment.ObjectKey = objectKey
	return nil
}

func (r *fakeAttachmentRepo) FinalizeReservation(ctx context.Context, id uuid.UUID, byteSize, limitBytes int64) error {
	if r.finalizeErr != nil {
		return r.finalizeErr
	}
	r.updatedStatus = models.AttachmentStatusReady
	r.updatedByteSize = byteSize
	r.updateCalled = true
	return nil
}

func (r *fakeAttachmentRepo) MarkFailed(ctx context.Context, id uuid.UUID) error {
	r.markFailedCalled = true
	r.updatedStatus = models.AttachmentStatusFailed
	return nil
}

func (r *fakeAttachmentRepo) ListCleanupCandidates(ctx context.Context, expiredBefore time.Time, limit int) ([]models.Attachment, error) {
	return r.cleanupCandidates, nil
}

func (r *fakeAttachmentRepo) Delete(ctx context.Context, id uuid.UUID) error {
	r.deleteCalled = true
	return nil
}

func (r *fakeAttachmentRepo) UpdateContentType(ctx context.Context, id uuid.UUID, contentType string) error {
	return nil
}

type fakeAttachmentStorage struct {
	size      int64
	deleted   *bool
	deleteErr error
}

func (s fakeAttachmentStorage) GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string {
	return "https://upload.example/" + key
}

func (s fakeAttachmentStorage) GetURL(key string) string { return "https://download.example/" + key }

func (s fakeAttachmentStorage) Delete(key string) error {
	if s.deleteErr != nil {
		return s.deleteErr
	}
	if s.deleted != nil {
		*s.deleted = true
	}
	return nil
}

func (s fakeAttachmentStorage) HeadObjectSize(ctx context.Context, key string) (int64, error) {
	return s.size, nil
}

// Download returns bytes that never sniff as an image, so finalize tests keep
// exercising the "store as uploaded" path rather than recompression.
func (s fakeAttachmentStorage) Download(ctx context.Context, key string) ([]byte, error) {
	return []byte("not an image"), nil
}

func (s fakeAttachmentStorage) Upload(key string, data []byte, contentType string) error {
	return nil
}

func TestAttachmentService_FinalizeUploadVerifiesRealSize(t *testing.T) {
	ctx := context.Background()
	user := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	groupID := uuid.New()
	attachmentID := uuid.New()

	t.Run("stores real size and marks ready", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil)
		repo := &fakeAttachmentRepo{
			attachment: &models.Attachment{
				ID:        attachmentID,
				GroupID:   groupID,
				UserID:    user.ID,
				ObjectKey: "groups/g/file.txt",
				ByteSize:  1,
				Status:    models.AttachmentStatusPending,
			},
		}
		svc := NewAttachmentServiceWithStorage(
			&config.Config{MaxFileSizeBytes: 1000, MaxStoragePerGroupGB: 1},
			repo,
			groupRepo,
			fakeAttachmentStorage{size: 512},
		)

		a, err := svc.FinalizeUpload(ctx, user, groupID, attachmentID)

		require.NoError(t, err)
		require.Equal(t, models.AttachmentStatusReady, a.Status)
		require.EqualValues(t, 512, a.ByteSize)
		require.True(t, repo.updateCalled)
		require.EqualValues(t, 512, repo.updatedByteSize)
		groupRepo.AssertExpectations(t)
	})

	t.Run("rejects byte_size bypass over max file size", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil)
		repo := &fakeAttachmentRepo{
			attachment: &models.Attachment{
				ID:        attachmentID,
				GroupID:   groupID,
				UserID:    user.ID,
				ObjectKey: "groups/g/large.bin",
				ByteSize:  1,
				Status:    models.AttachmentStatusPending,
			},
		}
		svc := NewAttachmentServiceWithStorage(
			&config.Config{MaxFileSizeBytes: 100},
			repo,
			groupRepo,
			fakeAttachmentStorage{size: 101},
		)

		_, err := svc.FinalizeUpload(ctx, user, groupID, attachmentID)

		require.Error(t, err)
		require.IsType(t, &api.ValidationError{}, err)
		require.False(t, repo.updateCalled)
		require.True(t, repo.markFailedCalled)
		require.True(t, repo.deleteCalled)
		groupRepo.AssertExpectations(t)
	})

	t.Run("rejects real size that exceeds group quota", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil)
		repo := &fakeAttachmentRepo{
			finalizeErr: repositories.ErrStorageQuotaExceeded,
			attachment: &models.Attachment{
				ID:        attachmentID,
				GroupID:   groupID,
				UserID:    user.ID,
				ObjectKey: "groups/g/file.bin",
				ByteSize:  1,
				Status:    models.AttachmentStatusPending,
			},
		}
		svc := NewAttachmentServiceWithStorage(
			&config.Config{MaxFileSizeBytes: 1000, MaxStoragePerGroupGB: 1},
			repo,
			groupRepo,
			fakeAttachmentStorage{size: 100},
		)

		_, err := svc.FinalizeUpload(ctx, user, groupID, attachmentID)

		require.Error(t, err)
		require.IsType(t, &api.ValidationError{}, err)
		require.False(t, repo.updateCalled)
		require.True(t, repo.markFailedCalled)
		require.True(t, repo.deleteCalled)
		groupRepo.AssertExpectations(t)
	})
}

func TestAttachmentService_CreateUploadIntentRejectsExhaustedQuota(t *testing.T) {
	ctx := context.Background()
	user := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	groupID := uuid.New()
	groupRepo := new(mocks.MockGroupRepo)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(
		&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil,
	)
	repo := &fakeAttachmentRepo{reserveErr: repositories.ErrStorageQuotaExceeded}
	svc := NewAttachmentServiceWithStorage(
		&config.Config{MaxFileSizeBytes: 10 * 1024 * 1024, MaxStoragePerGroupGB: 1},
		repo,
		groupRepo,
		fakeAttachmentStorage{},
	)

	_, err := svc.CreateUploadIntent(ctx, user, CreateUploadIntentInput{
		GroupID: groupID, Purpose: "photo", Filename: "photo.jpg", ContentType: "image/jpeg", ByteSize: 1024,
	})

	require.Error(t, err)
	require.IsType(t, &api.ValidationError{}, err)
}

func TestAttachmentService_GetStorageUsage(t *testing.T) {
	ctx := context.Background()
	user := &models.User{ID: uuid.New(), IsActive: true, IsVerified: true}
	groupID := uuid.New()
	groupRepo := new(mocks.MockGroupRepo)
	groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(
		&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil,
	)
	repo := &fakeAttachmentRepo{storageUsage: &models.AttachmentStorageUsage{
		UsedBytes: 300_000_000, ReservedBytes: 50_000_000,
	}}
	svc := NewAttachmentServiceWithStorage(
		&config.Config{MaxStoragePerGroupGB: 1}, repo, groupRepo, fakeAttachmentStorage{},
	)

	usage, err := svc.GetStorageUsage(ctx, user, groupID)

	require.NoError(t, err)
	require.EqualValues(t, 300_000_000, usage.UsedBytes)
	require.EqualValues(t, 50_000_000, usage.ReservedBytes)
	require.EqualValues(t, 1_000_000_000, usage.LimitBytes)
	require.EqualValues(t, 650_000_000, usage.AvailableBytes)
	require.False(t, usage.Unlimited)
	groupRepo.AssertExpectations(t)
}

func TestAttachmentService_CleanupExpiredUploads(t *testing.T) {
	deleted := false
	attachmentID := uuid.New()
	repo := &fakeAttachmentRepo{cleanupCandidates: []models.Attachment{{
		ID: attachmentID, ObjectKey: "groups/g/attachments/a/file.jpg", Status: models.AttachmentStatusPending,
	}}}
	svc := NewAttachmentServiceWithStorage(nil, repo, nil, fakeAttachmentStorage{deleted: &deleted})

	cleaned, err := svc.CleanupExpiredUploads(context.Background())

	require.NoError(t, err)
	require.Equal(t, 1, cleaned)
	require.True(t, repo.markFailedCalled)
	require.True(t, repo.deleteCalled)
	require.True(t, deleted)
}

func TestAttachmentService_CleanupRetriesFailedObjectDeletion(t *testing.T) {
	repo := &fakeAttachmentRepo{cleanupCandidates: []models.Attachment{{
		ID: uuid.New(), ObjectKey: "groups/g/attachments/a/file.jpg", Status: models.AttachmentStatusFailed,
	}}}
	svc := NewAttachmentServiceWithStorage(nil, repo, nil, fakeAttachmentStorage{deleteErr: errors.New("temporary storage failure")})

	cleaned, err := svc.CleanupExpiredUploads(context.Background())

	require.NoError(t, err)
	require.Zero(t, cleaned)
	require.False(t, repo.deleteCalled)
}
