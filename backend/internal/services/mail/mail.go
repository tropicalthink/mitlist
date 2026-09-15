package mail

import (
	"bytes"
	"fmt"
	"html/template"
	"mime/multipart"
	"net/smtp"
	"net/textproto"
	"strings"
	"time"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// Service sends emails through Amazon SES when it is configured, falling back
// to SMTP providers otherwise.
type Service struct {
	cfg *config.Config
	log *logger.Logger

	sesState sesState
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

// Header is one extra message header, e.g. List-Unsubscribe. Names and values
// are sanitized like every other header before they reach the wire.
type Header struct {
	Name  string
	Value string
}

// buildMultipartMessage assembles a multipart/alternative message carrying a
// plain-text part and an HTML part. Clients that render HTML use the second
// part; everything else (and every spam filter that distrusts HTML-only mail)
// still gets the text. Like buildMessage it is pure and unit-testable. Extra
// headers, when given, go after the standard ones.
func buildMultipartMessage(from, to, subject, text, html string, extra ...Header) []byte {
	from = sanitizeHeader(from)
	to = sanitizeHeader(to)
	subject = sanitizeHeader(subject)

	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	for _, part := range []struct{ contentType, content string }{
		{"text/plain; charset=\"utf-8\"", text},
		{"text/html; charset=\"utf-8\"", html},
	} {
		w, err := mw.CreatePart(textproto.MIMEHeader{
			"Content-Type":              {part.contentType},
			"Content-Transfer-Encoding": {"8bit"},
		})
		if err != nil {
			// The writer is backed by a bytes.Buffer; the only failure mode is
			// a closed writer, which cannot happen here.
			continue
		}
		_, _ = w.Write([]byte(part.content))
	}
	_ = mw.Close()

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
	buf.WriteString(time.Now().Format(time.RFC1123Z))
	buf.WriteString("\r\n")
	for _, h := range extra {
		name := sanitizeHeader(strings.ReplaceAll(h.Name, ":", ""))
		if name == "" {
			continue
		}
		buf.WriteString(name)
		buf.WriteString(": ")
		buf.WriteString(sanitizeHeader(h.Value))
		buf.WriteString("\r\n")
	}
	buf.WriteString("MIME-Version: 1.0\r\n")
	buf.WriteString("Content-Type: multipart/alternative; boundary=\"")
	buf.WriteString(mw.Boundary())
	buf.WriteString("\"\r\n\r\n")
	buf.Write(body.Bytes())
	return buf.Bytes()
}

// Send delivers an email before returning. Authentication flows must not report
// that a verification or recovery message was sent when the provider rejected
// it. AWS_SES_REGION opts into Amazon SES; SMTP remains available as a fallback
// for self-hosted deployments.
func (s *Service) Send(to, subject, body string, isHTML bool) error {
	return s.send(to, subject, body, isHTML)
}

// SendHTML delivers a styled email with a plain-text alternative. Use it for
// anything a person reads (verification, recovery); the text part is what a
// text-only client shows and what keeps HTML mail out of the spam folder.
func (s *Service) SendHTML(to, subject, html, text string) error {
	return s.SendHTMLWithHeaders(to, subject, html, text, nil)
}

// SendHTMLWithHeaders is SendHTML plus extra headers. The onboarding series
// uses it for List-Unsubscribe, which mail clients turn into a native
// unsubscribe button and which Gmail and Yahoo require of anything that is
// not strictly transactional.
func (s *Service) SendHTMLWithHeaders(to, subject, html, text string, headers []Header) error {
	if s.sesEnabled() {
		if err := s.sendViaSES(s.fromHeader(), to, subject, html, text, headers); err == nil {
			s.log.Info().Str("provider", "ses").Str("to", to).Msg("email sent")
			return nil
		} else {
			s.log.WithError(err).Warn().Str("provider", "ses").Msg("ses send failed, trying smtp")
		}
	}
	return s.sendSMTPWithFallback(s.fromAddress(), to, buildMultipartMessage(s.fromHeader(), to, subject, text, html, headers...))
}

// SendHTMLWithHeadersOnce submits a message to exactly one configured
// provider. It is for non-critical campaigns where an ambiguous provider
// timeout must not fan out into a duplicate through the normal fallback path.
// Transactional account mail should keep using SendHTMLWithHeaders.
func (s *Service) SendHTMLWithHeadersOnce(to, subject, html, text string, headers []Header) error {
	if s.sesEnabled() {
		if err := s.sendViaSES(s.fromHeader(), to, subject, html, text, headers); err != nil {
			return err
		}
		s.log.Info().Str("provider", "ses").Str("to", to).Msg("email sent")
		return nil
	}

	msg := buildMultipartMessage(s.fromHeader(), to, subject, text, html, headers...)
	type smtpProvider struct {
		name, host, user, pass string
		port                   int
	}
	providers := []smtpProvider{
		{"sendgrid", s.cfg.SendGridSMTPHost, s.cfg.SendGridSMTPUser, s.cfg.SendGridSMTPPass, s.cfg.SendGridSMTPPort},
		{"brevo", s.cfg.BrevoSMTPHost, s.cfg.BrevoSMTPUser, s.cfg.BrevoSMTPPass, s.cfg.BrevoSMTPPort},
	}
	for _, provider := range providers {
		if provider.host == "" || provider.port == 0 {
			continue
		}
		if err := s.sendViaSMTP(provider.host, provider.port, provider.user, provider.pass, s.fromAddress(), []string{to}, msg); err != nil {
			return fmt.Errorf("send email via %s: %w", provider.name, err)
		}
		s.log.Info().Str("provider", provider.name).Str("to", to).Msg("email sent")
		return nil
	}
	return fmt.Errorf("send email: no mail provider configured")
}

// fromAddress is the bare sender address: the SMTP envelope sender, and what
// must be a verified identity at the provider.
func (s *Service) fromAddress() string {
	if s.cfg.MailFromEmail != "" {
		return s.cfg.MailFromEmail
	}
	return "noreply@mitlist.me"
}

// fromHeader is what the recipient sees in the From line: the display name in
// front of the address, "mitlist <noreply@mitlist.me>", so the inbox shows
// the product and not a bare noreply.
func (s *Service) fromHeader() string {
	addr := s.fromAddress()
	name := sanitizeHeader(strings.ReplaceAll(s.cfg.MailFromName, `"`, ""))
	if name == "" {
		return addr
	}
	return name + " <" + addr + ">"
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
	msg := buildMessage(s.fromHeader(), to, subject, body, isHTML)
	if s.sesEnabled() {
		html, text := body, ""
		if !isHTML {
			html, text = "", body
		}
		if err := s.sendViaSES(s.fromHeader(), to, subject, html, text, nil); err == nil {
			s.log.Info().Str("provider", "ses").Str("to", to).Msg("email sent")
			return nil
		} else {
			s.log.WithError(err).Warn().Str("provider", "ses").Msg("ses send failed, trying smtp")
		}
	}
	return s.sendSMTPWithFallback(s.fromAddress(), to, msg)
}

// sendSMTPWithFallback tries the primary SMTP provider and falls back to the
// secondary one, so a single provider outage does not lose a sign-up code.
func (s *Service) sendSMTPWithFallback(from, to string, msg []byte) error {
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
