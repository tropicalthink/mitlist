package services

import (
	"context"
	"errors"
	"fmt"
	"mime"
	"path"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/internal/models"
	"github.com/mitlist-app/mitlist/internal/repositories"
	storagesvc "github.com/mitlist-app/mitlist/internal/services/storage"
	"github.com/mitlist-app/mitlist/internal/sse"
)

var allowedContentTypes = map[string]bool{
	"application/octet-stream": true,
	"image/jpeg":               true,
	"image/png":                true,
	"image/gif":                true,
	"image/webp":               true,
	"image/heic":               true,
	"image/heif":               true,
	"application/pdf":          true,
	"text/plain":               true,
	"text/csv":                 true,
}

type AttachmentService struct {
	cfg       *config.Config
	repo      repositories.AttachmentRepo
	groupRepo repositories.GroupRepo
	storage   attachmentStorage
	hub       *sse.Hub
}

// SetHub injects the household event hub for attachment lifecycle changes.
func (s *AttachmentService) SetHub(h *sse.Hub) { s.hub = h }

type attachmentStorage interface {
	GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string
	GetURL(key string) string
	Delete(key string) error
	HeadObjectSize(ctx context.Context, key string) (int64, error)
}

func NewAttachmentService(cfg *config.Config, repo repositories.AttachmentRepo, groupRepo repositories.GroupRepo, storage *storagesvc.Service) *AttachmentService {
	return NewAttachmentServiceWithStorage(cfg, repo, groupRepo, storage)
}

func NewAttachmentServiceWithStorage(cfg *config.Config, repo repositories.AttachmentRepo, groupRepo repositories.GroupRepo, storage attachmentStorage) *AttachmentService {
	return &AttachmentService{
		cfg:       cfg,
		repo:      repo,
		groupRepo: groupRepo,
		storage:   storage,
	}
}

type CreateUploadIntentInput struct {
	GroupID     uuid.UUID `json:"group_id"`
	Purpose     string    `json:"purpose"`
	Filename    string    `json:"filename"`
	ContentType string    `json:"content_type"`
	ByteSize    int64     `json:"byte_size"`
}

type UploadIntent struct {
	Attachment *models.Attachment `json:"attachment"`
	ObjectKey  string             `json:"object_key"`
	UploadURL  string             `json:"upload_url"`
	ExpiresIn  int                `json:"expires_in"`
}

type StorageUsage struct {
	UsedBytes      int64 `json:"used_bytes"`
	ReservedBytes  int64 `json:"reserved_bytes"`
	LimitBytes     int64 `json:"limit_bytes"`
	AvailableBytes int64 `json:"available_bytes"`
	Unlimited      bool  `json:"unlimited"`
}

func (s *AttachmentService) requireMembership(ctx context.Context, userID, groupID uuid.UUID) error {
	return requireGroupMember(ctx, s.groupRepo, groupID, userID)
}

func (s *AttachmentService) GetStorageUsage(ctx context.Context, user *models.User, groupID uuid.UUID) (*StorageUsage, error) {
	if user == nil {
		return nil, api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	usage, err := s.repo.GetStorageUsage(ctx, groupID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "group", ID: groupID.String()}
		}
		return nil, err
	}
	limit := s.storageLimitBytes()
	available := int64(0)
	if limit > 0 {
		available = limit - usage.UsedBytes - usage.ReservedBytes
		if available < 0 {
			available = 0
		}
	}
	return &StorageUsage{
		UsedBytes:      usage.UsedBytes,
		ReservedBytes:  usage.ReservedBytes,
		LimitBytes:     limit,
		AvailableBytes: available,
		Unlimited:      limit <= 0,
	}, nil
}

func (s *AttachmentService) CreateUploadIntent(ctx context.Context, user *models.User, in CreateUploadIntentInput) (*UploadIntent, error) {
	if user == nil {
		return nil, api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if in.GroupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, in.GroupID); err != nil {
		return nil, err
	}

	in.Purpose = strings.TrimSpace(in.Purpose)
	if in.Purpose == "" {
		return nil, &api.ValidationError{Field: "purpose", Message: "purpose is required"}
	}
	in.Filename = sanitizeFilename(in.Filename)
	if in.Filename == "" {
		in.Filename = "upload"
	}
	if in.ByteSize <= 0 {
		return nil, &api.ValidationError{Field: "byte_size", Message: "byte_size must be positive"}
	}
	if s.cfg != nil && s.cfg.MaxFileSizeBytes > 0 && in.ByteSize > int64(s.cfg.MaxFileSizeBytes) {
		return nil, &api.ValidationError{Field: "byte_size", Message: "file too large"}
	}
	if in.ContentType == "" {
		in.ContentType = "application/octet-stream"
	}
	in.ContentType = strings.TrimSpace(in.ContentType)
	if !allowedContentTypes[in.ContentType] {
		mt, _, _ := mime.ParseMediaType(in.ContentType)
		if mt == "" || !allowedContentTypes[mt] {
			in.ContentType = "application/octet-stream"
		}
	}

	reservationExpiresAt := time.Now().Add(20 * time.Minute)
	a := &models.Attachment{
		GroupID:              in.GroupID,
		UserID:               user.ID,
		Purpose:              in.Purpose,
		ContentType:          in.ContentType,
		ByteSize:             in.ByteSize,
		Status:               models.AttachmentStatusPending,
		ReservationExpiresAt: &reservationExpiresAt,
	}

	// Create a placeholder object key using a generated attachment id in DB.
	// We will fill ObjectKey once we have the ID.
	a.ObjectKey = "pending"
	if err := s.repo.Reserve(ctx, a, s.storageLimitBytes()); err != nil {
		if errors.Is(err, repositories.ErrStorageQuotaExceeded) {
			return nil, &api.ValidationError{Message: "household storage limit exceeded"}
		}
		return nil, err
	}

	objectKey := buildObjectKey(in.GroupID, a.ID, in.Filename)
	a.ObjectKey = objectKey

	if err := s.repo.UpdateObjectKey(ctx, a.ID, objectKey); err != nil {
		_ = s.repo.MarkFailed(ctx, a.ID)
		_ = s.repo.Delete(ctx, a.ID)
		return nil, err
	}

	expires := 5 * time.Minute
	uploadURL := s.storage.GetUploadURL(objectKey, in.ContentType, in.ByteSize, expires)
	if uploadURL == "" {
		_ = s.repo.MarkFailed(ctx, a.ID)
		_ = s.repo.Delete(ctx, a.ID)
		return nil, fmt.Errorf("failed to generate upload URL")
	}

	return &UploadIntent{
		Attachment: a,
		ObjectKey:  objectKey,
		UploadURL:  uploadURL,
		ExpiresIn:  int(expires.Seconds()),
	}, nil
}

func (s *AttachmentService) FinalizeUpload(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) (*models.Attachment, error) {
	if user == nil {
		return nil, api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return nil, &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return nil, &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return nil, err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return nil, err
	}
	if a.GroupID != groupID {
		return nil, &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}
	if a.Status != models.AttachmentStatusPending {
		return nil, &api.ValidationError{Message: "upload is no longer pending"}
	}

	realSize, err := s.storage.HeadObjectSize(ctx, a.ObjectKey)
	if err != nil {
		return nil, err
	}
	if s.cfg != nil && s.cfg.MaxFileSizeBytes > 0 && realSize > int64(s.cfg.MaxFileSizeBytes) {
		if failErr := s.failPendingUpload(ctx, a); failErr != nil {
			return nil, failErr
		}
		return nil, &api.ValidationError{Message: "uploaded file exceeds size limit"}
	}

	if err := s.repo.FinalizeReservation(ctx, attachmentID, realSize, s.storageLimitBytes()); err != nil {
		if err == pgx.ErrNoRows {
			return nil, &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		if errors.Is(err, repositories.ErrStorageQuotaExceeded) {
			if failErr := s.failPendingUpload(ctx, a); failErr != nil {
				return nil, failErr
			}
			return nil, &api.ValidationError{Message: "household storage limit exceeded"}
		}
		if errors.Is(err, repositories.ErrAttachmentNotPending) {
			return nil, &api.ValidationError{Message: "upload is no longer pending"}
		}
		return nil, err
	}
	a.Status = models.AttachmentStatusReady
	a.ByteSize = realSize
	publishDomainEvent(s.hub, "attachment:ready", groupID, map[string]string{"attachment_id": attachmentID.String()})
	return a, nil
}

func (s *AttachmentService) storageLimitBytes() int64 {
	if s.cfg == nil || s.cfg.MaxStoragePerGroupGB <= 0 {
		return 0
	}
	return int64(s.cfg.MaxStoragePerGroupGB) * 1_000_000_000
}

func (s *AttachmentService) failPendingUpload(ctx context.Context, a *models.Attachment) error {
	if err := s.repo.MarkFailed(ctx, a.ID); err != nil {
		return err
	}
	if a.ObjectKey == "" || a.ObjectKey == "pending" {
		return s.repo.Delete(ctx, a.ID)
	}
	if err := s.storage.Delete(a.ObjectKey); err != nil {
		// Keep the failed row so the cleanup job can retry the object deletion.
		return nil
	}
	return s.repo.Delete(ctx, a.ID)
}

// CleanupExpiredUploads releases abandoned reservations and deletes failed
// objects. Failed rows are retained when object deletion fails so a later run
// can retry safely.
func (s *AttachmentService) CleanupExpiredUploads(ctx context.Context) (int, error) {
	candidates, err := s.repo.ListCleanupCandidates(ctx, time.Now(), 200)
	if err != nil {
		return 0, err
	}
	cleaned := 0
	for i := range candidates {
		a := &candidates[i]
		if a.Status == models.AttachmentStatusPending {
			if err := s.repo.MarkFailed(ctx, a.ID); err != nil {
				if errors.Is(err, repositories.ErrAttachmentNotPending) || err == pgx.ErrNoRows {
					continue
				}
				return cleaned, err
			}
		}
		if a.ObjectKey != "" && a.ObjectKey != "pending" {
			if err := s.storage.Delete(a.ObjectKey); err != nil {
				continue
			}
		}
		if err := s.repo.Delete(ctx, a.ID); err != nil {
			if err == pgx.ErrNoRows {
				continue
			}
			return cleaned, err
		}
		cleaned++
	}
	return cleaned, nil
}

func (s *AttachmentService) GetDownloadURL(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) (string, error) {
	if user == nil {
		return "", api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return "", &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return "", &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return "", err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return "", &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return "", err
	}
	if a.GroupID != groupID {
		return "", &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}
	if a.Status != models.AttachmentStatusReady {
		return "", &api.ValidationError{Message: "attachment not ready"}
	}

	url := s.storage.GetURL(a.ObjectKey)
	if url == "" {
		return "", fmt.Errorf("failed to generate download URL")
	}
	return url, nil
}

func (s *AttachmentService) DeleteAttachment(ctx context.Context, user *models.User, groupID, attachmentID uuid.UUID) error {
	if user == nil {
		return api.ErrUnauthorized
	}
	if !user.IsActive || !user.IsVerified {
		return &api.PermissionDeniedError{Message: "user is not active or verified"}
	}
	if groupID == uuid.Nil {
		return &api.ValidationError{Field: "group_id", Message: "group_id is required"}
	}
	if err := s.requireMembership(ctx, user.ID, groupID); err != nil {
		return err
	}

	a, err := s.repo.GetByID(ctx, attachmentID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	if a.GroupID != groupID {
		return &api.PermissionDeniedError{Message: "attachment does not belong to this group"}
	}

	// Best-effort delete of backing object.
	if a.ObjectKey != "" && a.ObjectKey != "pending" {
		if err := s.storage.Delete(a.ObjectKey); err != nil {
			return err
		}
	}

	if err := s.repo.Delete(ctx, attachmentID); err != nil {
		if err == pgx.ErrNoRows {
			return &api.NotFoundError{Resource: "attachment", ID: attachmentID.String()}
		}
		return err
	}
	publishDomainEvent(s.hub, "attachment:deleted", groupID, map[string]string{"attachment_id": attachmentID.String()})
	return nil
}

func sanitizeFilename(name string) string {
	name = strings.TrimSpace(name)
	name = strings.ReplaceAll(name, "\\", "/")
	name = path.Base(name)
	name = strings.TrimSpace(name)
	name = strings.Trim(name, ".")
	name = strings.ReplaceAll(name, "..", ".")
	name = strings.ReplaceAll(name, "/", "_")
	name = strings.ReplaceAll(name, "\x00", "")
	if len(name) > 120 {
		name = name[:120]
	}
	return name
}

func buildObjectKey(groupID, attachmentID uuid.UUID, filename string) string {
	filename = sanitizeFilename(filename)
	if filename == "" {
		filename = "upload"
	}
	return fmt.Sprintf("groups/%s/attachments/%s/%s", groupID.String(), attachmentID.String(), filename)
}
