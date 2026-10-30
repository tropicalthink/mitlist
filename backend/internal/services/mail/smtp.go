package mail

import (
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/smtp"
	"strconv"
	"strings"
	"time"
)

// smtpTLSMode is how an SMTP connection is protected.
type smtpTLSMode string

const (
	// smtpTLSStartTLS connects in plaintext (submission, port 587) and must
	// upgrade with STARTTLS before anything else is sent. A server that does
	// not offer STARTTLS is refused rather than silently used in the clear.
	smtpTLSStartTLS smtpTLSMode = "starttls"
	// smtpTLSImplicit speaks TLS from the first byte (SMTPS, port 465).
	// net/smtp.SendMail cannot do this, which is why this file exists.
	smtpTLSImplicit smtpTLSMode = "tls"
	// smtpTLSNone never encrypts. Only for a trusted relay, typically on the
	// same host or a private network; credentials are refused unless the
	// relay is on localhost, the same rule net/smtp's PlainAuth applies.
	smtpTLSNone smtpTLSMode = "none"
)

// parseSMTPTLSMode reads SMTP_TLS. Empty means the default, starttls.
func parseSMTPTLSMode(raw string) (smtpTLSMode, error) {
	switch smtpTLSMode(strings.ToLower(strings.TrimSpace(raw))) {
	case "", smtpTLSStartTLS:
		return smtpTLSStartTLS, nil
	case smtpTLSImplicit:
		return smtpTLSImplicit, nil
	case smtpTLSNone:
		return smtpTLSNone, nil
	}
	return "", fmt.Errorf("invalid SMTP_TLS %q: must be starttls, tls, or none", raw)
}

const (
	smtpDialTimeout    = 15 * time.Second
	smtpSessionTimeout = 2 * time.Minute
)

// smtpProvider is one SMTP server mail can go out through.
type smtpProvider struct {
	name, host, user, pass string
	port                   int
	tls                    string
}

func (p smtpProvider) configured() bool { return p.host != "" && p.port != 0 }

// smtpProviders lists the SMTP servers in the order they are tried.
//
// The generic SMTP_HOST server comes first: an operator who set it means it.
// SendGrid and Brevo follow. Their hosts carry non-empty defaults, so when
// SMTP_HOST is set they are only kept as fallbacks if their credentials are
// too; otherwise every failure of the operator's own server would also log
// two pointless unauthenticated attempts at SendGrid and Brevo. Without
// SMTP_HOST the list is exactly what the hosted service always used.
func (s *Service) smtpProviders() []smtpProvider {
	generic := strings.TrimSpace(s.cfg.SMTPHost)
	var providers []smtpProvider
	if generic != "" {
		providers = append(providers, smtpProvider{
			name: "smtp", host: generic, port: s.cfg.SMTPPort,
			user: s.cfg.SMTPUsername, pass: s.cfg.SMTPPassword, tls: s.cfg.SMTPTLS,
		})
	}
	named := []smtpProvider{
		{name: "sendgrid", host: s.cfg.SendGridSMTPHost, port: s.cfg.SendGridSMTPPort, user: s.cfg.SendGridSMTPUser, pass: s.cfg.SendGridSMTPPass},
		{name: "brevo", host: s.cfg.BrevoSMTPHost, port: s.cfg.BrevoSMTPPort, user: s.cfg.BrevoSMTPUser, pass: s.cfg.BrevoSMTPPass},
	}
	for _, p := range named {
		if generic != "" && p.user == "" {
			continue
		}
		providers = append(providers, p)
	}
	return providers
}

// deliverSMTP sends through the injected test hook when there is one.
func (s *Service) deliverSMTP(p smtpProvider, from string, to []string, msg []byte) error {
	if s.smtpSend != nil {
		return s.smtpSend(p, from, to, msg)
	}
	return sendViaSMTP(p, from, to, msg)
}

// isLocalhost mirrors net/smtp's own test for where PlainAuth may send a
// password without TLS.
func isLocalhost(host string) bool {
	return host == "localhost" || host == "127.0.0.1" || host == "::1"
}

// checkSMTPPlan rejects a configuration that cannot be used safely before
// any connection is made: an unknown TLS mode, or credentials that would
// cross the network in plaintext.
func checkSMTPPlan(p smtpProvider) (smtpTLSMode, error) {
	if !p.configured() {
		return "", fmt.Errorf("invalid smtp configuration: host=%q port=%d", p.host, p.port)
	}
	mode, err := parseSMTPTLSMode(p.tls)
	if err != nil {
		return "", err
	}
	if mode == smtpTLSNone && p.user != "" && p.pass != "" && !isLocalhost(p.host) {
		return "", fmt.Errorf("refusing to send SMTP credentials to %s without TLS: use SMTP_TLS=starttls or tls, or a relay on localhost", p.host)
	}
	return mode, nil
}

// sendViaSMTP delivers one message. Unlike net/smtp.SendMail it supports
// implicit TLS (port 465), insists on STARTTLS when that mode is chosen
// instead of quietly falling back to plaintext, and bounds the session with
// timeouts so a stalled server cannot hang a sign-up request.
func sendViaSMTP(p smtpProvider, from string, to []string, msg []byte) error {
	mode, err := checkSMTPPlan(p)
	if err != nil {
		return err
	}
	addr := net.JoinHostPort(p.host, strconv.Itoa(p.port))
	tlsConfig := &tls.Config{ServerName: p.host, MinVersion: tls.VersionTLS12}
	dialer := &net.Dialer{Timeout: smtpDialTimeout}

	var conn net.Conn
	if mode == smtpTLSImplicit {
		conn, err = tls.DialWithDialer(dialer, "tcp", addr, tlsConfig)
	} else {
		conn, err = dialer.Dial("tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("connect to %s: %w", addr, err)
	}
	_ = conn.SetDeadline(time.Now().Add(smtpSessionTimeout))

	// NewClient notices a *tls.Conn and records the session as encrypted,
	// which is what lets PlainAuth proceed on an implicit-TLS connection.
	c, err := smtp.NewClient(conn, p.host)
	if err != nil {
		_ = conn.Close()
		return fmt.Errorf("smtp handshake with %s: %w", addr, err)
	}
	defer c.Close()

	if mode == smtpTLSStartTLS {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return errors.New("smtp server does not offer STARTTLS: use SMTP_TLS=tls for an implicit-TLS port such as 465, or SMTP_TLS=none for a trusted plaintext relay")
		}
		if err := c.StartTLS(tlsConfig); err != nil {
			return fmt.Errorf("smtp starttls: %w", err)
		}
	}
	if p.user != "" && p.pass != "" {
		if ok, _ := c.Extension("AUTH"); !ok {
			return errors.New("smtp server does not support AUTH, but credentials are configured")
		}
		if err := c.Auth(smtp.PlainAuth("", p.user, p.pass, p.host)); err != nil {
			return fmt.Errorf("smtp auth: %w", err)
		}
	}
	if err := c.Mail(from); err != nil {
		return fmt.Errorf("smtp MAIL FROM: %w", err)
	}
	for _, rcpt := range to {
		if err := c.Rcpt(rcpt); err != nil {
			return fmt.Errorf("smtp RCPT TO: %w", err)
		}
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp DATA: %w", err)
	}
	if _, err := w.Write(msg); err != nil {
		return fmt.Errorf("smtp write message: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp end message: %w", err)
	}
	return c.Quit()
}
