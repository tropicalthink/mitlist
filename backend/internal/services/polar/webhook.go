package polar

import (
	"encoding/base64"
	"errors"
	"net/http"

	standardwebhooks "github.com/standard-webhooks/standard-webhooks/libraries/go"
)

// HeaderWebhookID is the delivery id Polar stamps on every webhook request.
const HeaderWebhookID = standardwebhooks.HeaderWebhookID

// WebhookVerifier checks the signature on a Polar webhook delivery.
//
// Polar signs with the Standard Webhooks scheme (webhook-id, webhook-timestamp
// and webhook-signature headers over "id.timestamp.body"), but the HMAC key
// depends on when the endpoint's secret was generated:
//
//   - secrets generated before 2026-09-08 00:00 UTC — every endpoint created
//     from the dashboard until then — use the UTF-8 bytes of the *whole*
//     "whsec_…" string as the key. The 43 characters after the prefix are not
//     base64, so handing the value to a Standard Webhooks library fails with
//     "illegal base64 data", which is what crash-looped production on
//     2026-08-21;
//   - secrets generated on or after that instant are real Standard Webhooks
//     secrets: "whsec_" followed by a base64 key, used as-is.
//
// Nothing in the value says which one it is, so the verifier derives both
// keys and accepts a delivery that checks out under either. A wrong key can
// only ever fail to verify, never pass, so trying both costs nothing in
// safety and spares the operator from guessing at an encoding. Whatever the
// Polar dashboard shows for the endpoint is what goes into
// POLAR_WEBHOOK_SECRET, verbatim.
type WebhookVerifier struct {
	candidates []*standardwebhooks.Webhook
}

// NewWebhookVerifier builds a verifier for the secret exactly as Polar issued
// it. It fails only on an empty secret.
func NewWebhookVerifier(secret string) (*WebhookVerifier, error) {
	if secret == "" {
		return nil, errors.New("polar: webhook secret is empty")
	}
	v := &WebhookVerifier{}

	// Standard Webhooks: the secret is a base64 key behind the prefix. A
	// legacy secret usually fails to decode here and is simply skipped; one
	// that happens to decode yields a key Polar never signs with, which is
	// harmless.
	if std, err := standardwebhooks.NewWebhook(secret); err == nil {
		v.candidates = append(v.candidates, std)
	}

	// Polar's original scheme: key = UTF-8 bytes of the full secret string.
	// Encoding those bytes as base64 is how the same library is told to use
	// them as-is, which is exactly what Polar's own signer does.
	legacy, err := standardwebhooks.NewWebhook(base64.StdEncoding.EncodeToString([]byte(secret)))
	if err != nil {
		return nil, err
	}
	v.candidates = append(v.candidates, legacy)
	return v, nil
}

// Verify checks payload against the Standard Webhooks headers on the request
// and returns nil when the signature matches under any supported key. The
// library also rejects deliveries whose timestamp is more than a few minutes
// off, so a captured request cannot be replayed later.
func (v *WebhookVerifier) Verify(payload []byte, headers http.Header) error {
	if v == nil || len(v.candidates) == 0 {
		return errors.New("polar: webhook verifier is not configured")
	}
	var last error
	for _, c := range v.candidates {
		if err := c.Verify(payload, headers); err == nil {
			return nil
		} else {
			last = err
		}
	}
	return last
}
