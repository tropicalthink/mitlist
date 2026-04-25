package storage

import (
	"bytes"
	"context"
	"fmt"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/rs/zerolog/log"

	"github.com/yourorg/mitlist/internal/config"
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

	awsCfg, err := awsconfig.LoadDefaultConfig(context.Background(),
		awsconfig.WithRegion(cfg.AWSRegion),
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

// Upload stores data at the given key in the configured bucket.
func (s *Service) Upload(key string, data []byte) error {
	if s.client == nil || s.bucket == "" {
		return fmt.Errorf("storage not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader(data),
		ContentType: aws.String("application/octet-stream"),
	})
	if err != nil {
		return fmt.Errorf("upload to s3: %w", err)
	}
	return nil
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
