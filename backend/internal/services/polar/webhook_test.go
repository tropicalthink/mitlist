package polar

import (
	"encoding/base64"
	"net/http"
	"strconv"
	"testing"
	"time"

	standardwebhooks "github.com/standard-webhooks/standard-webhooks/libraries/go"
)

// legacySecret has the shape Polar issued before 2026-09-08: "whsec_" and 43
// URL-safe characters that are not valid base64. Not a real secret.
const legacySecret = "whsec_Ab3dEfGh1jKlMnOpQrStUvWxYz0123456789abcdefg"

// signAs mimics Polar's tasks.sign_webhook: the Standard Webhooks signature
// over the delivery, keyed either as-is (standard) or by the UTF-8 bytes of
// the whole secret string (legacy).
func signAs(t *testing.T, secret string, legacy bool, id string, ts time.Time, payload []byte) http.Header {
	t.Helper()
	key := secret
	if legacy {
		key = base64.StdEncoding.EncodeToString([]byte(secret))
	}
	signer, err := standardwebhooks.NewWebhook(key)
	if err != nil {
		t.Fatalf("build signer: %v", err)
	}
	sig, err := signer.Sign(id, ts, payload)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	h := http.Header{}
	h.Set(standardwebhooks.HeaderWebhookID, id)
	h.Set(standardwebhooks.HeaderWebhookTimestamp, strconv.FormatInt(ts.Unix(), 10))
	h.Set(standardwebhooks.HeaderWebhookSignature, sig)
	return h
}

func standardSecret(t *testing.T) string {
	t.Helper()
	key := make([]byte, 32)
	for i := range key {
		key[i] = byte(i * 7)
	}
	return "whsec_" + base64.StdEncoding.EncodeToString(key)
}

// The secret as shown in the Polar dashboard must work verbatim, whichever
// signing scheme Polar picked for it.
func TestWebhookVerifierAcceptsBothPolarSchemes(t *testing.T) {
	payload := []byte(`{"type":"subscription.active","data":{"id":"sub_1"}}`)
	now := time.Now()

	cases := []struct {
		name   string
		secret string
		legacy bool
	}{
		{"legacy secret, Polar HMAC over the whole string", legacySecret, true},
		{"standard secret, key used as-is", standardSecret(t), false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			v, err := NewWebhookVerifier(tc.secret)
			if err != nil {
				t.Fatalf("NewWebhookVerifier: %v", err)
			}
			headers := signAs(t, tc.secret, tc.legacy, "msg_1", now, payload)
			if err := v.Verify(payload, headers); err != nil {
				t.Fatalf("expected the delivery to verify, got %v", err)
			}
		})
	}
}

// A legacy secret decodes under neither library encoding, and used to abort
// process start-up. The verifier must construct from it regardless.
func TestWebhookVerifierBuildsFromRawLegacySecret(t *testing.T) {
	if _, err := standardwebhooks.NewWebhook(legacySecret); err == nil {
		t.Fatal("test premise: the legacy secret should not be valid base64")
	}
	if _, err := NewWebhookVerifier(legacySecret); err != nil {
		t.Fatalf("expected the raw Polar secret to be accepted, got %v", err)
	}
	if _, err := NewWebhookVerifier(""); err == nil {
		t.Fatal("expected an empty secret to be rejected")
	}
}

// Trying two keys must never widen what is accepted: a delivery signed with
// another secret, a tampered body, or a stale timestamp all still fail.
func TestWebhookVerifierRejectsBadDeliveries(t *testing.T) {
	payload := []byte(`{"type":"order.paid"}`)
	v, err := NewWebhookVerifier(legacySecret)
	if err != nil {
		t.Fatal(err)
	}

	other := "whsec_ZZZdEfGh1jKlMnOpQrStUvWxYz0123456789abcdefg"
	if err := v.Verify(payload, signAs(t, other, true, "msg_1", time.Now(), payload)); err == nil {
		t.Fatal("a delivery signed with a different legacy secret must be rejected")
	}
	if err := v.Verify(payload, signAs(t, standardSecret(t), false, "msg_1", time.Now(), payload)); err == nil {
		t.Fatal("a delivery signed with a different standard secret must be rejected")
	}

	good := signAs(t, legacySecret, true, "msg_1", time.Now(), payload)
	if err := v.Verify([]byte(`{"type":"order.paid","data":{"tampered":true}}`), good); err == nil {
		t.Fatal("a tampered body must be rejected")
	}
	stale := signAs(t, legacySecret, true, "msg_1", time.Now().Add(-time.Hour), payload)
	if err := v.Verify(payload, stale); err == nil {
		t.Fatal("a stale timestamp must be rejected")
	}
	if err := v.Verify(payload, http.Header{}); err == nil {
		t.Fatal("missing signature headers must be rejected")
	}
}
