package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/rs/zerolog/log"

	"github.com/mitlist-app/mitlist/internal/config"
)

// Service provides file storage backed by S3-compatible object storage.
type Service struct {
	client *s3.Client
	bucket string
}

// New creates a storage service using the provided application config.
func New(cfg *config.Config) *Service {
	if cfg.S3BucketName == "" {
		log.Warn().Msg("S3_BUCKET_NAME not set; storage service will fail on upload")
		return &Service{bucket: ""}
	}

	region := cfg.AWSRegion
	// Cloudflare R2 uses the S3-compatible API with region "auto".
	// For compatibility, "us-east-1" aliases to "auto", but we prefer "auto"
	// when we detect an R2 endpoint.
	if cfg.S3EndpointURL != "" && strings.Contains(cfg.S3EndpointURL, ".r2.cloudflarestorage.com") {
		region = "auto"
	}

	awsCfg, err := awsconfig.LoadDefaultConfig(context.Background(),
		awsconfig.WithRegion(region),
	)
	if err != nil {
		log.Error().Err(err).Msg("failed to load AWS config; storage service may not work")
		return &Service{bucket: cfg.S3BucketName}
	}

	var opts []func(*s3.Options)
	opts = append(opts, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	if cfg.S3EndpointURL != "" {
		opts = append(opts, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(cfg.S3EndpointURL)
		})
	}

	if cfg.AWSAccessKeyID != "" && cfg.AWSSecretAccessKey != "" {
		opts = append(opts, func(o *s3.Options) {
			o.Credentials = credentials.NewStaticCredentialsProvider(
				cfg.AWSAccessKeyID,
				cfg.AWSSecretAccessKey,
				"",
			)
		})
	}

	client := s3.NewFromConfig(awsCfg, opts...)

	return &Service{
		client: client,
		bucket: cfg.S3BucketName,
	}
}

// Upload stores data at the given key in the configured bucket. The content
// type is stored as object metadata and echoed on downloads.
func (s *Service) Upload(key string, data []byte, contentType string) error {
	if s.client == nil || s.bucket == "" {
		return fmt.Errorf("storage not configured")
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return fmt.Errorf("upload to s3: %w", err)
	}
	return nil
}

// Download fetches the object at the given key into memory. Callers own
// bounding the size (attachments are already capped at upload time).
func (s *Service) Download(ctx context.Context, key string) ([]byte, error) {
	if s.client == nil || s.bucket == "" {
		return nil, fmt.Errorf("storage not configured")
	}

	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	out, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("download from s3: %w", err)
	}
	defer out.Body.Close()

	data, err := io.ReadAll(out.Body)
	if err != nil {
		return nil, fmt.Errorf("read s3 object body: %w", err)
	}
	return data, nil
}

// GetUploadURL returns a presigned PUT URL for the given key.
// The caller should upload bytes directly to the returned URL.
func (s *Service) GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string {
	if s.client == nil || s.bucket == "" {
		return ""
	}
	if expires <= 0 {
		expires = 15 * time.Minute
	}
	_ = contentType // recorded on the attachment at intent time; not signed (see below)

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	presignClient := s3.NewPresignClient(s.client)
	// Content-Type is deliberately NOT part of the signature. Binding it means
	// the client's PUT must echo the exact type the intent was signed with;
	// shipped app versions send types the intent normalizes away (`image/*`),
	// so their uploads fail with a signature mismatch. The type is validated
	// and recorded at intent time; the signed Content-Length still pins the
	// upload to the reserved size.
	req, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(s.bucket),
		Key:           aws.String(key),
		ContentLength: aws.Int64(contentLength),
	}, s3.WithPresignExpires(expires))
	if err != nil {
		log.Error().Err(err).Str("key", key).Msg("failed to generate presigned upload URL")
		return ""
	}
	return req.URL
}

// HeadObjectSize returns the persisted object size in bytes.
func (s *Service) HeadObjectSize(ctx context.Context, key string) (int64, error) {
	if s.client == nil || s.bucket == "" {
		return 0, fmt.Errorf("storage not configured")
	}

	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()

	out, err := s.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return 0, fmt.Errorf("head object in s3: %w", err)
	}
	return aws.ToInt64(out.ContentLength), nil
}

// GetURL returns a presigned URL for the given key.
func (s *Service) GetURL(key string) string {
	if s.client == nil || s.bucket == "" {
		return ""
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	presignClient := s3.NewPresignClient(s.client)
	req, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(15*time.Minute))
	if err != nil {
		log.Error().Err(err).Str("key", key).Msg("failed to generate presigned URL")
		return ""
	}
	return req.URL
}

// Delete removes the object at the given key from the configured bucket.
func (s *Service) Delete(key string) error {
	if s.client == nil || s.bucket == "" {
		return fmt.Errorf("storage not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("delete from s3: %w", err)
	}
	return nil
}
