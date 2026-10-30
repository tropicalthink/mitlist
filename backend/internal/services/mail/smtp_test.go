package mail

import (
	"bufio"
	"errors"
	"net"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

func TestParseSMTPTLSMode(t *testing.T) {
	tests := []struct {
		raw     string
		want    smtpTLSMode
		wantErr bool
	}{
		{raw: "", want: smtpTLSStartTLS},
		{raw: "starttls", want: smtpTLSStartTLS},
		{raw: " STARTTLS ", want: smtpTLSStartTLS},
		{raw: "tls", want: smtpTLSImplicit},
		{raw: "TLS", want: smtpTLSImplicit},
		{raw: "none", want: smtpTLSNone},
		{raw: "ssl", wantErr: true},
		{raw: "true", wantErr: true},
	}
	for _, tt := range tests {
		got, err := parseSMTPTLSMode(tt.raw)
		if tt.wantErr {
			if err == nil {
				t.Errorf("parseSMTPTLSMode(%q) = %q, want an error", tt.raw, got)
			}
			continue
		}
		if err != nil || got != tt.want {
			t.Errorf("parseSMTPTLSMode(%q) = %q, %v; want %q", tt.raw, got, err, tt.want)
		}
	}
}

// hostedDefaults is what config.Load leaves in the SendGrid/Brevo host fields
// when nothing is set: non-empty hosts, no credentials.
func hostedDefaults(cfg *config.Config) *config.Config {
	cfg.SendGridSMTPHost, cfg.SendGridSMTPPort = "smtp.sendgrid.net", 587
	cfg.BrevoSMTPHost, cfg.BrevoSMTPPort = "smtp-relay.sendinblue.com", 587
	return cfg
}

func providerNames(ps []smtpProvider) []string {
	names := make([]string, 0, len(ps))
	for _, p := range ps {
		names = append(names, p.name)
	}
	return names
}

func TestSMTPProviders_Order(t *testing.T) {
	tests := []struct {
		name string
		cfg  *config.Config
		want []string
	}{
		{
			// The hosted service's list must not change: both relays, in
			// order, exactly as before SMTP_HOST existed.
			name: "no SMTP_HOST keeps the hosted order",
			cfg:  hostedDefaults(&config.Config{SendGridSMTPUser: "apikey", BrevoSMTPUser: "brevo"}),
			want: []string{"sendgrid", "brevo"},
		},
		{
			name: "no SMTP_HOST and no credentials still lists both relays",
			cfg:  hostedDefaults(&config.Config{}),
			want: []string{"sendgrid", "brevo"},
		},
		{
			name: "SMTP_HOST alone drops the unconfigured relays",
			cfg:  hostedDefaults(&config.Config{SMTPHost: "smtp.fastmail.com", SMTPPort: 465}),
			want: []string{"smtp"},
		},
		{
			name: "SMTP_HOST comes before credentialed relays",
			cfg:  hostedDefaults(&config.Config{SMTPHost: "mail.example.org", SMTPPort: 587, BrevoSMTPUser: "brevo"}),
			want: []string{"smtp", "brevo"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := New(tt.cfg, logger.New("test"))
			if got := providerNames(s.smtpProviders()); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("providers = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSMTPProviders_GenericCarriesItsSettings(t *testing.T) {
	s := New(&config.Config{
		SMTPHost: " smtp.fastmail.com ", SMTPPort: 465,
		SMTPUsername: "me@example.org", SMTPPassword: "app-password", SMTPTLS: "tls",
	}, logger.New("test"))
	got := s.smtpProviders()[0]
	want := smtpProvider{name: "smtp", host: "smtp.fastmail.com", port: 465, user: "me@example.org", pass: "app-password", tls: "tls"}
	if got != want {
		t.Errorf("generic provider = %+v, want %+v", got, want)
	}
}

// recordingSender stands in for the network and fails the providers named in
// failing.
type recordingSender struct {
	mu      sync.Mutex
	tried   []string
	failing map[string]bool
}

func (r *recordingSender) send(p smtpProvider, _ string, _ []string, _ []byte) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.tried = append(r.tried, p.name)
	if r.failing[p.name] {
		return errors.New(p.name + " is down")
	}
	return nil
}

func TestSendHTML_GenericSMTPIsTriedFirst(t *testing.T) {
	rec := &recordingSender{}
	s := New(hostedDefaults(&config.Config{
		SMTPHost: "mail.example.org", SMTPPort: 587,
		SendGridSMTPUser: "apikey", SendGridSMTPPass: "key",
	}), logger.New("test"))
	s.smtpSend = rec.send

	if err := s.SendHTML("user@example.com", "Verify", "<p>h</p>", "t"); err != nil {
		t.Fatalf("SendHTML: %v", err)
	}
	if !reflect.DeepEqual(rec.tried, []string{"smtp"}) {
		t.Errorf("tried %v, want only the generic server", rec.tried)
	}
}

func TestSendHTML_FallsBackFromGenericSMTP(t *testing.T) {
	rec := &recordingSender{failing: map[string]bool{"smtp": true}}
	s := New(hostedDefaults(&config.Config{
		SMTPHost: "mail.example.org", SMTPPort: 587,
		SendGridSMTPUser: "apikey", SendGridSMTPPass: "key",
	}), logger.New("test"))
	s.smtpSend = rec.send

	if err := s.Send("user@example.com", "Verify", "code", false); err != nil {
		t.Fatalf("Send: %v", err)
	}
	if !reflect.DeepEqual(rec.tried, []string{"smtp", "sendgrid"}) {
		t.Errorf("tried %v, want smtp then sendgrid", rec.tried)
	}
}

func TestSendHTML_ReportsEveryFailedProvider(t *testing.T) {
	rec := &recordingSender{failing: map[string]bool{"smtp": true}}
	s := New(hostedDefaults(&config.Config{SMTPHost: "mail.example.org", SMTPPort: 587}), logger.New("test"))
	s.smtpSend = rec.send

	err := s.SendHTML("user@example.com", "Verify", "<p>h</p>", "t")
	if err == nil || !strings.Contains(err.Error(), "smtp is down") {
		t.Fatalf("error = %v, want the generic server's failure", err)
	}
}

func TestSendHTMLWithHeadersOnce_PrefersGenericSMTPAndNeverFallsBack(t *testing.T) {
	rec := &recordingSender{failing: map[string]bool{"smtp": true}}
	s := New(hostedDefaults(&config.Config{
		SMTPHost: "mail.example.org", SMTPPort: 587,
		BrevoSMTPUser: "brevo", BrevoSMTPPass: "pass",
	}), logger.New("test"))
	s.smtpSend = rec.send

	err := s.SendHTMLWithHeadersOnce("user@example.com", "Tips", "<p>h</p>", "t", nil)
	if err == nil || !strings.Contains(err.Error(), "via smtp") {
		t.Fatalf("error = %v, want the generic server's failure", err)
	}
	if !reflect.DeepEqual(rec.tried, []string{"smtp"}) {
		t.Errorf("tried %v, want exactly one submission to the generic server", rec.tried)
	}
}

func TestSendHTMLWithHeadersOnce_HostedOrderUnchanged(t *testing.T) {
	rec := &recordingSender{}
	s := New(hostedDefaults(&config.Config{SendGridSMTPUser: "apikey", SendGridSMTPPass: "key"}), logger.New("test"))
	s.smtpSend = rec.send

	if err := s.SendHTMLWithHeadersOnce("user@example.com", "Tips", "<p>h</p>", "t", nil); err != nil {
		t.Fatalf("SendHTMLWithHeadersOnce: %v", err)
	}
	if !reflect.DeepEqual(rec.tried, []string{"sendgrid"}) {
		t.Errorf("tried %v, want sendgrid", rec.tried)
	}
}

func TestCheckSMTPPlan(t *testing.T) {
	tests := []struct {
		name     string
		p        smtpProvider
		wantMode smtpTLSMode
		wantErr  string
	}{
		{name: "default is starttls", p: smtpProvider{host: "mail.example.org", port: 587}, wantMode: smtpTLSStartTLS},
		{name: "implicit tls with credentials", p: smtpProvider{host: "smtp.fastmail.com", port: 465, user: "u", pass: "p", tls: "tls"}, wantMode: smtpTLSImplicit},
		{name: "plaintext relay without credentials", p: smtpProvider{host: "relay.lan", port: 25, tls: "none"}, wantMode: smtpTLSNone},
		{name: "plaintext credentials to localhost", p: smtpProvider{host: "localhost", port: 25, user: "u", pass: "p", tls: "none"}, wantMode: smtpTLSNone},
		{name: "plaintext credentials to loopback ip", p: smtpProvider{host: "127.0.0.1", port: 25, user: "u", pass: "p", tls: "none"}, wantMode: smtpTLSNone},
		{name: "plaintext credentials to a remote host", p: smtpProvider{host: "relay.lan", port: 25, user: "u", pass: "p", tls: "none"}, wantErr: "without TLS"},
		{name: "unknown mode", p: smtpProvider{host: "mail.example.org", port: 587, tls: "ssl"}, wantErr: "invalid SMTP_TLS"},
		{name: "missing host", p: smtpProvider{port: 587}, wantErr: "invalid smtp configuration"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mode, err := checkSMTPPlan(tt.p)
			if tt.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tt.wantErr) {
					t.Fatalf("err = %v, want one containing %q", err, tt.wantErr)
				}
				return
			}
			if err != nil || mode != tt.wantMode {
				t.Fatalf("mode = %q, err = %v; want %q", mode, err, tt.wantMode)
			}
		})
	}
}

// fakeSMTPServer is a minimal plaintext SMTP server on loopback. It never
// offers STARTTLS, records the commands it saw and the message body.
type fakeSMTPServer struct {
	ln       net.Listener
	mu       sync.Mutex
	commands []string
	data     string
	done     chan struct{}
}

func startFakeSMTP(t *testing.T) *fakeSMTPServer {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Skipf("cannot listen on loopback: %v", err)
	}
	srv := &fakeSMTPServer{ln: ln, done: make(chan struct{})}
	t.Cleanup(func() { _ = ln.Close() })
	go srv.serve()
	return srv
}

func (f *fakeSMTPServer) port() int { return f.ln.Addr().(*net.TCPAddr).Port }

func (f *fakeSMTPServer) serve() {
	defer close(f.done)
	conn, err := f.ln.Accept()
	if err != nil {
		return
	}
	defer conn.Close()
	r := bufio.NewReader(conn)
	reply := func(s string) { _, _ = conn.Write([]byte(s + "\r\n")) }
	reply("220 fake ESMTP")
	inData := false
	var body strings.Builder
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		line = strings.TrimRight(line, "\r\n")
		if inData {
			if line == "." {
				inData = false
				f.mu.Lock()
				f.data = body.String()
				f.mu.Unlock()
				reply("250 queued")
				continue
			}
			body.WriteString(line + "\n")
			continue
		}
		f.mu.Lock()
		f.commands = append(f.commands, line)
		f.mu.Unlock()
		verb := strings.ToUpper(strings.SplitN(line, " ", 2)[0])
		switch verb {
		case "EHLO":
			reply("250-fake")
			reply("250 AUTH PLAIN")
		case "AUTH":
			reply("235 ok")
		case "MAIL", "RCPT":
			reply("250 ok")
		case "DATA":
			inData = true
			reply("354 go ahead")
		case "QUIT":
			reply("221 bye")
			return
		default:
			reply("502 unknown")
		}
	}
}

func (f *fakeSMTPServer) sawCommand(prefix string) bool {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, c := range f.commands {
		if strings.HasPrefix(strings.ToUpper(c), prefix) {
			return true
		}
	}
	return false
}

func TestSendViaSMTP_PlaintextRelayOnLocalhost(t *testing.T) {
	srv := startFakeSMTP(t)
	p := smtpProvider{name: "smtp", host: "127.0.0.1", port: srv.port(), user: "relay", pass: "secret", tls: "none"}
	msg := buildMessage("noreply@example.org", "user@example.com", "Hi", "the body", false)

	if err := sendViaSMTP(p, "noreply@example.org", []string{"user@example.com"}, msg); err != nil {
		t.Fatalf("sendViaSMTP: %v", err)
	}
	<-srv.done
	if !srv.sawCommand("AUTH PLAIN") {
		t.Error("credentials to a localhost relay were not sent")
	}
	if !srv.sawCommand("RCPT TO:<USER@EXAMPLE.COM>") {
		t.Errorf("recipient missing; commands: %v", srv.commands)
	}
	if !strings.Contains(srv.data, "the body") {
		t.Errorf("message body not delivered: %q", srv.data)
	}
}

func TestSendViaSMTP_StartTLSIsRequired(t *testing.T) {
	srv := startFakeSMTP(t)
	p := smtpProvider{name: "smtp", host: "127.0.0.1", port: srv.port(), user: "u", pass: "p", tls: "starttls"}

	err := sendViaSMTP(p, "noreply@example.org", []string{"user@example.com"}, []byte("x"))
	if err == nil || !strings.Contains(err.Error(), "STARTTLS") {
		t.Fatalf("err = %v, want a refusal because the server offers no STARTTLS", err)
	}
	if srv.sawCommand("AUTH") || srv.sawCommand("MAIL") {
		t.Error("credentials or mail were sent over a connection that never upgraded")
	}
}

func TestSendViaSMTP_ImplicitTLSHandshakesFirst(t *testing.T) {
	srv := startFakeSMTP(t)
	p := smtpProvider{name: "smtp", host: "127.0.0.1", port: srv.port(), tls: "tls"}

	// The fake server greets in plaintext; an implicit-TLS client must fail
	// the handshake rather than read that greeting as SMTP.
	err := sendViaSMTP(p, "noreply@example.org", []string{"user@example.com"}, []byte("x"))
	if err == nil || !strings.Contains(err.Error(), "connect to 127.0.0.1:"+strconv.Itoa(srv.port())) {
		t.Fatalf("err = %v, want a TLS handshake failure", err)
	}
}
