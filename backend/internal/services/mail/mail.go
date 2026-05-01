package mail

import (
	"bytes"
	"fmt"
	"html/template"
	"net/smtp"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Service sends emails via SMTP with a primary/fallback provider strategy.
type Service struct {
	cfg *config.Config
	log *logger.Logger
}

// New creates a new mail service.
func New(cfg *config.Config, log *logger.Logger) *Service {
	return &Service{cfg: cfg, log: log}
}

// Send dispatches an email asynchronously. Errors are logged but never returned
// to the caller because sending happens in the background.
func (s *Service) Send(to, subject, body string, isHTML bool) error {
	go s.sendAsync(to, subject, body, isHTML)
	return nil
}

// SendTemplate renders an html/template and sends the result as an HTML email.
func (s *Service) SendTemplate(to, subject, tmplStr string, data any) error {
	t, err := template.New("email").Parse(tmplStr)
	if err != nil {
		return fmt.Errorf("parse email template: %w", err)
	}
	var buf bytes.Buffer
	if err := t.Execute(&buf, data); err != nil {
		return fmt.Errorf("execute email template: %w", err)
	}
	return s.Send(to, subject, buf.String(), true)
}

func (s *Service) sendAsync(to, subject, body string, isHTML bool) {
	from := s.cfg.MailFromEmail
	if from == "" {
		from = "noreply@mitlist.app"
	}

	contentType := "text/plain; charset=\"utf-8\""
	if isHTML {
		contentType = "text/html; charset=\"utf-8\""
	}

	msg := []byte(fmt.Sprintf("To: %s\r\nSubject: %s\r\nContent-Type: %s\r\n\r\n%s",
		to, subject, contentType, body))

	if err := s.sendViaSMTP(
		s.cfg.SendGridSMTPHost,
		s.cfg.SendGridSMTPPort,
		s.cfg.SendGridSMTPUser,
		s.cfg.SendGridSMTPPass,
		from,
		[]string{to},
		msg,
	); err != nil {
		s.log.WithError(err).Error().Str("provider", "sendgrid").Msg("smtp send failed, trying brevo")

		if err := s.sendViaSMTP(
			s.cfg.BrevoSMTPHost,
			s.cfg.BrevoSMTPPort,
			s.cfg.BrevoSMTPUser,
			s.cfg.BrevoSMTPPass,
			from,
			[]string{to},
			msg,
		); err != nil {
			s.log.WithError(err).Error().Str("provider", "brevo").Msg("smtp fallback send failed")
		} else {
			s.log.Info().Str("provider", "brevo").Str("to", to).Msg("email sent")
		}
	} else {
		s.log.Info().Str("provider", "sendgrid").Str("to", to).Msg("email sent")
	}
}

func (s *Service) sendViaSMTP(host string, port int, user, pass, from string, to []string, msg []byte) error {
	if host == "" || port == 0 {
		return fmt.Errorf("invalid smtp configuration: host=%q port=%d", host, port)
	}
	addr := fmt.Sprintf("%s:%d", host, port)
	var auth smtp.Auth
	if user != "" && pass != "" {
		auth = smtp.PlainAuth("", user, pass, host)
	}
	return smtp.SendMail(addr, auth, from, to, msg)
}
