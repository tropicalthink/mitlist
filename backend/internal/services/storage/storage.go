// Package storage stores attachment bytes (receipts, list item photos, pinwall
// media, recipe images) behind one API with two backends:
//
//   - S3-compatible object storage (S3_BUCKET_NAME), used by the hosted
//     service. Clients upload and download directly against the provider
//     through presigned URLs.
//   - Local disk (STORAGE_LOCAL_PATH), for a self-host without S3. The API
//     serves the files itself, through URLs on its own public origin
//     (PUBLIC_API_URL) signed with a key derived from SECRET_KEY; see local.go.
//
// S3 wins when both are configured. With neither, every method fails (or
// returns an empty URL), and uploads report "storage not configured".
package storage

import (
	"context"
	"fmt"
	"time"

	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/config"
)

// backend is one storage implementation. The method contracts are the
// exported ones on Service.
type backend interface {
	Upload(key string, data []byte, contentType string) error
	Download(ctx context.Context, key string) ([]byte, error)
	GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string
	HeadObjectSize(ctx context.Context, key string) (int64, error)
	GetURL(key string) string
	Delete(key string) error
}

// Service provides file storage backed by S3-compatible object storage or,
// on a self-host, the local filesystem.
type Service struct {
	b     backend
	local *LocalStore
}

// New creates a storage service using the provided application config.
func New(cfg *config.Config) *Service {
	if cfg.S3BucketName != "" {
		return &Service{b: newS3Backend(cfg)}
	}
	if cfg.StorageLocalPath != "" {
		local, err := NewLocalStore(cfg.StorageLocalPath, []byte(cfg.SecretKey), cfg.PublicAPIURL, cfg.APIPrefix)
		if err != nil {
			log.Error().Err(err).Str("path", cfg.StorageLocalPath).
				Msg("STORAGE_LOCAL_PATH is not usable; storage service will fail on upload")
			return &Service{}
		}
		if cfg.PublicAPIURL == "" {
			log.Error().Str("path", cfg.StorageLocalPath).
				Msg("STORAGE_LOCAL_PATH is set but PUBLIC_API_URL is empty: local file storage serves uploads and downloads through the API's own public URL, so uploads will fail until PUBLIC_API_URL is set to the API's public origin")
		}
		return &Service{b: local, local: local}
	}
	log.Warn().Msg("S3_BUCKET_NAME not set; storage service will fail on upload (set STORAGE_LOCAL_PATH to store files on local disk)")
	return &Service{}
}

// Local returns the local-disk store when that backend is active, so the API
// can serve its signed file URLs; nil otherwise (S3 or unconfigured).
func (s *Service) Local() *LocalStore {
	if s == nil {
		return nil
	}
	return s.local
}

// Upload stores data at the given key. The content type is stored with the
// object and echoed on downloads.
func (s *Service) Upload(key string, data []byte, contentType string) error {
	if s.b == nil {
		return fmt.Errorf("storage not configured")
	}
	return s.b.Upload(key, data, contentType)
}

// Download fetches the object at the given key into memory. Callers own
// bounding the size (attachments are already capped at upload time).
func (s *Service) Download(ctx context.Context, key string) ([]byte, error) {
	if s.b == nil {
		return nil, fmt.Errorf("storage not configured")
	}
	return s.b.Download(ctx, key)
}

// GetUploadURL returns a presigned PUT URL for the given key, or "" when
// storage cannot issue one. The caller should upload bytes directly to the
// returned URL with exactly contentLength bytes.
func (s *Service) GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string {
	if s.b == nil {
		return ""
	}
	return s.b.GetUploadURL(key, contentType, contentLength, expires)
}

// HeadObjectSize returns the persisted object size in bytes.
func (s *Service) HeadObjectSize(ctx context.Context, key string) (int64, error) {
	if s.b == nil {
		return 0, fmt.Errorf("storage not configured")
	}
	return s.b.HeadObjectSize(ctx, key)
}

// GetURL returns a short-lived presigned download URL for the given key, or
// "" when storage cannot issue one.
func (s *Service) GetURL(key string) string {
	if s.b == nil {
		return ""
	}
	return s.b.GetURL(key)
}

// Delete removes the object at the given key.
func (s *Service) Delete(key string) error {
	if s.b == nil {
		return fmt.Errorf("storage not configured")
	}
	return s.b.Delete(key)
}
