package turnstile

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestVerifierDisabledWithoutSecret(t *testing.T) {
	v := NewForTesting("", "http://example.invalid", nil)
	if v.Enabled() {
		t.Fatal("verifier with no secret reported enabled")
	}
	if _, err := v.Verify(context.Background(), "token", ""); err != ErrDisabled {
		t.Fatalf("want ErrDisabled, got %v", err)
	}
}

func TestVerifyRejectsEmptyToken(t *testing.T) {
	v := NewForTesting("secret", "http://example.invalid", nil)
	if _, err := v.Verify(context.Background(), "   ", ""); err != ErrMissing {
		t.Fatalf("want ErrMissing, got %v", err)
	}
}

func TestVerifySendsSecretAndToken(t *testing.T) {
	var gotSecret, gotResponse, gotIP string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Errorf("parse form: %v", err)
		}
		gotSecret = r.PostForm.Get("secret")
		gotResponse = r.PostForm.Get("response")
		gotIP = r.PostForm.Get("remoteip")
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"success":true,"hostname":"app.mitlist.me","action":"guest","challenge_ts":"2026-08-19T18:00:00Z"}`))
	}))
	defer srv.Close()

	v := NewForTesting("shh", srv.URL, srv.Client())
	result, err := v.Verify(context.Background(), "client-token", "203.0.113.7")
	if err != nil {
		t.Fatalf("verify: %v", err)
	}
	if gotSecret != "shh" || gotResponse != "client-token" || gotIP != "203.0.113.7" {
		t.Fatalf("unexpected form: secret=%q response=%q ip=%q", gotSecret, gotResponse, gotIP)
	}
	if result.Hostname != "app.mitlist.me" || result.Action != "guest" {
		t.Fatalf("unexpected result: %+v", result)
	}
	if result.ChallengeTS.IsZero() {
		t.Fatal("challenge_ts was not parsed")
	}
}

// A failed challenge and a malformed body must be indistinguishable to the
// caller: both mean "no proof", and neither should leak Cloudflare's error
// codes to an unauthenticated client.
func TestVerifyRejectsUnsuccessfulAndMalformed(t *testing.T) {
	for name, body := range map[string]string{
		"unsuccessful": `{"success":false,"error-codes":["invalid-input-response"]}`,
		"malformed":    `not json`,
		"empty":        ``,
	} {
		t.Run(name, func(t *testing.T) {
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte(body))
			}))
			defer srv.Close()

			v := NewForTesting("shh", srv.URL, srv.Client())
			if _, err := v.Verify(context.Background(), "client-token", ""); err != ErrInvalid {
				t.Fatalf("want ErrInvalid, got %v", err)
			}
		})
	}
}

func TestVerifyRejectsNon200(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer srv.Close()

	v := NewForTesting("shh", srv.URL, srv.Client())
	if _, err := v.Verify(context.Background(), "client-token", ""); err != ErrInvalid {
		t.Fatalf("want ErrInvalid, got %v", err)
	}
}

func TestQuotaIdentity(t *testing.T) {
	install := uuid.New().String()
	result := &Result{Hostname: "app.mitlist.me"}

	if got := result.QuotaIdentity(install); got != "turnstile:installation:"+install {
		t.Fatalf("unexpected identity %q", got)
	}
	for _, bad := range []string{"", "   ", "not-a-uuid", uuid.Nil.String()} {
		if got := result.QuotaIdentity(bad); got != "" {
			t.Fatalf("identity %q accepted a bad installation ID %q", got, bad)
		}
	}
	var nilResult *Result
	if got := nilResult.QuotaIdentity(install); got != "" {
		t.Fatalf("nil result produced identity %q", got)
	}
}
