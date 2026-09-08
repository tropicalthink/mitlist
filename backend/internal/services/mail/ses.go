package mail

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/sesv2"
	"github.com/aws/aws-sdk-go-v2/service/sesv2/types"
)

// sesAPI is the slice of the SES v2 client this package uses. Naming it as an
// interface keeps the send path testable without reaching AWS.
type sesAPI interface {
	SendEmail(ctx context.Context, in *sesv2.SendEmailInput, opts ...func(*sesv2.Options)) (*sesv2.SendEmailOutput, error)
}

// sesClients are built lazily: config loading walks the AWS credential chain,
// which can probe the instance metadata service, and a deployment with no SES
// configured must not pay for that at startup.
type sesState struct {
	once   sync.Once
	client sesAPI
	err    error
}

// sesEnabled reports whether SES is the configured primary provider. The
// region is the opt-in switch — AWS credentials alone are not, since a
// self-host may have set them only for S3-compatible file storage.
func (s *Service) sesEnabled() bool {
	return s.cfg.SESRegion != ""
}

// ses returns the shared SES client, building it on first use.
func (s *Service) ses() (sesAPI, error) {
	s.sesState.once.Do(func() {
		if s.sesState.client != nil {
			// A test injected a client; nothing to build.
			return
		}
		awsCfg, err := awsconfig.LoadDefaultConfig(context.Background(),
			awsconfig.WithRegion(s.cfg.SESRegion),
		)
		if err != nil {
			s.sesState.err = fmt.Errorf("load aws config for ses: %w", err)
			return
		}
		// Deliberately not the AWS_* pair used for file storage: that one
		// addresses an S3-compatible provider (Cloudflare R2 on the hosted
		// service) and its keys are not valid AWS credentials. With no SES
		// pair set, LoadDefaultConfig's ambient chain applies.
		var opts []func(*sesv2.Options)
		if s.cfg.SESAccessKeyID != "" && s.cfg.SESSecretAccessKey != "" {
			opts = append(opts, func(o *sesv2.Options) {
				o.Credentials = credentials.NewStaticCredentialsProvider(
					s.cfg.SESAccessKeyID,
					s.cfg.SESSecretAccessKey,
					"",
				)
			})
		}
		s.sesState.client = sesv2.NewFromConfig(awsCfg, opts...)
	})
	return s.sesState.client, s.sesState.err
}

// sendViaSES delivers one message through the SES v2 API. Passing subject and
// bodies separately (rather than a raw MIME blob) lets SES do the encoding and
// keeps the multipart/alternative assembly a concern of the SMTP path only.
// Either html or text may be empty, but not both. Extra headers ride along as
// SES message headers.
func (s *Service) sendViaSES(from, to, subject, html, text string, headers []Header) error {
	client, err := s.ses()
	if err != nil {
		return err
	}

	body := &types.Body{}
	if text != "" {
		body.Text = &types.Content{Data: aws.String(text), Charset: aws.String("UTF-8")}
	}
	if html != "" {
		body.Html = &types.Content{Data: aws.String(html), Charset: aws.String("UTF-8")}
	}
	if body.Text == nil && body.Html == nil {
		return fmt.Errorf("ses send: message has neither a text nor an html body")
	}

	in := &sesv2.SendEmailInput{
		FromEmailAddress: aws.String(sanitizeHeader(from)),
		Destination:      &types.Destination{ToAddresses: []string{sanitizeHeader(to)}},
		Content: &types.EmailContent{
			Simple: &types.Message{
				Subject: &types.Content{Data: aws.String(sanitizeHeader(subject)), Charset: aws.String("UTF-8")},
				Body:    body,
			},
		},
	}
	for _, h := range headers {
		name := sanitizeHeader(strings.ReplaceAll(h.Name, ":", ""))
		if name == "" {
			continue
		}
		in.Content.Simple.Headers = append(in.Content.Simple.Headers, types.MessageHeader{
			Name:  aws.String(name),
			Value: aws.String(sanitizeHeader(h.Value)),
		})
	}
	if s.cfg.SESConfigurationSet != "" {
		in.ConfigurationSetName = aws.String(s.cfg.SESConfigurationSet)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if _, err := client.SendEmail(ctx, in); err != nil {
		return fmt.Errorf("ses send email: %w", err)
	}
	return nil
}
