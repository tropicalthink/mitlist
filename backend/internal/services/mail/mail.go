package mail

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"net/smtp"
	"strings"
	"time"

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

// sanitizeHeader removes CR and LF characters from a header value to prevent
// header injection. Any \r or \n in a field like To/Subject/From would allow an
// attacker to inject arbitrary headers or body content.
func sanitizeHeader(s string) string {
	s = strings.ReplaceAll(s, "\r", "")
	s = strings.ReplaceAll(s, "\n", "")
	return s
}

// buildMessage assembles a well-formed RFC 2822 email message as a byte slice.
// All header values are sanitized to strip CR/LF before being written. This is
// a pure function that can be tested without an SMTP connection.
func buildMessage(from, to, subject, body string, isHTML bool) []byte {
	from = sanitizeHeader(from)
	to = sanitizeHeader(to)
	subject = sanitizeHeader(subject)

	contentType := "text/plain; charset=\"utf-8\""
	if isHTML {
		contentType = "text/html; charset=\"utf-8\""
	}

	date := time.Now().Format(time.RFC1123Z)

	var buf bytes.Buffer
	buf.WriteString("From: ")
	buf.WriteString(from)
	buf.WriteString("\r\n")
	buf.WriteString("To: ")
	buf.WriteString(to)
	buf.WriteString("\r\n")
	buf.WriteString("Subject: ")
	buf.WriteString(subject)
	buf.WriteString("\r\n")
	buf.WriteString("Date: ")
	buf.WriteString(date)
	buf.WriteString("\r\n")
	buf.WriteString("MIME-Version: 1.0\r\n")
	buf.WriteString("Content-Type: ")
	buf.WriteString(contentType)
	buf.WriteString("\r\n\r\n")
	buf.WriteString(body)
	return buf.Bytes()
}

// Send delivers an email before returning. Authentication flows must not report
// that a verification or recovery message was sent when the provider rejected
// it. A Resend API key opts into the HTTPS provider; SMTP remains available as
// a fallback for self-hosted deployments.
func (s *Service) Send(to, subject, body string, isHTML bool) error {
	return s.send(to, subject, body, isHTML)
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

func (s *Service) send(to, subject, body string, isHTML bool) error {
	from := s.cfg.MailFromEmail
	if from == "" {
		from = "noreply@mitlist.me"
	}

	msg := buildMessage(from, to, subject, body, isHTML)
	if s.cfg.ResendAPIKey != "" {
		if err := s.sendViaResend(to, from, subject, body, isHTML); err == nil {
			s.log.Info().Str("provider", "resend").Str("to", to).Msg("email sent")
			return nil
		} else {
			s.log.WithError(err).Warn().Str("provider", "resend").Msg("resend send failed, trying smtp")
		}
	}

	sendGridErr := s.sendViaSMTP(
		s.cfg.SendGridSMTPHost,
		s.cfg.SendGridSMTPPort,
		s.cfg.SendGridSMTPUser,
		s.cfg.SendGridSMTPPass,
		from,
		[]string{to},
		msg,
	)
	if sendGridErr != nil {
		s.log.WithError(sendGridErr).Error().Str("provider", "sendgrid").Msg("smtp send failed, trying brevo")

		brevoErr := s.sendViaSMTP(
			s.cfg.BrevoSMTPHost,
			s.cfg.BrevoSMTPPort,
			s.cfg.BrevoSMTPUser,
			s.cfg.BrevoSMTPPass,
			from,
			[]string{to},
			msg,
		)
		if brevoErr != nil {
			s.log.WithError(brevoErr).Error().Str("provider", "brevo").Msg("smtp fallback send failed")
			return fmt.Errorf("send email via smtp providers: sendgrid: %v; brevo: %w", sendGridErr, brevoErr)
		} else {
			s.log.Info().Str("provider", "brevo").Str("to", to).Msg("email sent")
		}
	} else {
		s.log.Info().Str("provider", "sendgrid").Str("to", to).Msg("email sent")
	}
	return nil
}

func (s *Service) sendViaResend(to, from, subject, body string, isHTML bool) error {
	payload := map[string]any{"from": from, "to": []string{to}, "subject": subject}
	if isHTML {
		payload["html"] = body
	} else {
		payload["text"] = body
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("encode resend request: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.resend.com/emails", bytes.NewReader(encoded))
	if err != nil {
		return fmt.Errorf("create resend request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+s.cfg.ResendAPIKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("resend request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("resend returned status %d", resp.StatusCode)
	}
	return nil
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
