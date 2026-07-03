package services

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories/mocks"
)

type fakeAttachmentRepo struct {
	attachment      *models.Attachment
	usedBytes       int64
	updatedStatus   models.AttachmentStatus
	updatedByteSize int64
	updateCalled    bool
}

func (r *fakeAttachmentRepo) Create(ctx context.Context, a *models.Attachment) error {
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

func (r *fakeAttachmentRepo) UpdateStatus(ctx context.Context, id uuid.UUID, status models.AttachmentStatus) error {
	r.updatedStatus = status
	r.updateCalled = true
	return nil
}

func (r *fakeAttachmentRepo) UpdateStatusAndByteSize(ctx context.Context, id uuid.UUID, status models.AttachmentStatus, byteSize int64) error {
	r.updatedStatus = status
	r.updatedByteSize = byteSize
	r.updateCalled = true
	return nil
}

func (r *fakeAttachmentRepo) Delete(ctx context.Context, id uuid.UUID) error { return nil }

func (r *fakeAttachmentRepo) SumReadyBytesByGroup(ctx context.Context, groupID uuid.UUID) (int64, error) {
	return r.usedBytes, nil
}

type fakeAttachmentStorage struct {
	size int64
}

func (s fakeAttachmentStorage) GetUploadURL(key string, contentType string, expires time.Duration) string {
	return "https://upload.example/" + key
}

func (s fakeAttachmentStorage) GetURL(key string) string { return "https://download.example/" + key }

func (s fakeAttachmentStorage) Delete(key string) error { return nil }

func (s fakeAttachmentStorage) HeadObjectSize(ctx context.Context, key string) (int64, error) {
	return s.size, nil
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
		groupRepo.AssertExpectations(t)
	})

	t.Run("rejects real size that exceeds group quota", func(t *testing.T) {
		groupRepo := new(mocks.MockGroupRepo)
		groupRepo.On("GetMembership", ctx, groupID, user.ID).Return(&models.GroupMembership{GroupID: groupID, UserID: user.ID, Role: "member"}, nil)
		repo := &fakeAttachmentRepo{
			usedBytes: 999_999_950,
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
		groupRepo.AssertExpectations(t)
	})
}
