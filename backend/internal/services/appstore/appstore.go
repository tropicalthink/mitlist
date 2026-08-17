// Package appstore verifies Apple App Store Server data: the StoreKit 2 signed
// transactions the app sends after a purchase, and the App Store Server
// Notifications V2 Apple posts for renewals, cancellations, and refunds.
//
// Both arrive as JWS (RFC 7515) signed by Apple with an x5c certificate chain.
// Trust comes from verifying that chain up to an embedded Apple root CA;
// the JWS signature is then checked against the chain's leaf key. Nothing here
// trusts a payload before its signature and chain verify.
//
// Mobile IAP is opt-in and independent of the Polar web checkout. A client
// built with no bundle id reports itself disabled and verifies nothing.
package appstore

import (
	"crypto/ecdsa"
	"crypto/x509"
	_ "embed"
	"encoding/asn1"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Apple publishes both G2 and G3 root trust anchors for App Store Server data.
//
//go:embed AppleRootCA-G3.pem
var appleRootCAG3PEM []byte

//go:embed AppleRootCA-G2.pem
var appleRootCAG2PEM []byte

// appleRoots is the parsed trust anchor pool, built once at init.
var appleRoots *x509.CertPool

// Apple documents these certificate-purpose extensions for App Store signed
// data. Trusting an Apple root alone is insufficient because Apple roots issue
// certificates for unrelated services too.
var (
	appStoreReceiptSigningOID = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 6, 11, 1}
	appleWWDRIntermediateOID  = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 6, 2, 1}
)

func init() {
	appleRoots = x509.NewCertPool()
	if !appleRoots.AppendCertsFromPEM(appleRootCAG2PEM) ||
		!appleRoots.AppendCertsFromPEM(appleRootCAG3PEM) {
		// A build that embeds a malformed root cannot verify anything; fail loud
		// rather than silently trusting nothing (or, worse, everything).
		panic("appstore: an embedded Apple root CA is not valid PEM")
	}
}

// ErrDisabled is returned by verification when no bundle id is configured.
var ErrDisabled = errors.New("appstore: Apple IAP is not configured")

// Config is the credentials and identifiers Apple IAP needs.
type Config struct {
	// BundleID is the app's bundle identifier. A verified transaction whose
	// bundle id does not match is rejected — it belongs to another app.
	BundleID string
	// Environment is "Production", "Sandbox", or "Both". Both is intended for
	// a production endpoint that must also accept TestFlight/sandbox deliveries;
	// the signed environment is retained on every decoded payload.
	Environment string
	// AppAppleID is the numeric app identifier from App Store Connect. It is
	// present and required on production notification envelopes.
	AppAppleID       int64
	ProductIDMonthly string
	ProductIDYearly  string
}

// Client verifies Apple IAP payloads. It holds no network state — everything it
// checks is self-contained in the signed JWS, cryptographically anchored to the
// trust root in roots.
type Client struct {
	cfg Config
	// roots is the trust anchor pool JWS chains must verify against. In
	// production it contains Apple's embedded G2 and G3 roots; tests substitute a
	// throwaway CA to exercise the chain path without Apple's private key.
	roots *x509.CertPool
}

// New builds a client. An empty BundleID yields a disabled client whose
// verification calls all return ErrDisabled.
func New(cfg Config) *Client {
	if cfg.Environment == "" {
		cfg.Environment = "Production"
	}
	return &Client{cfg: cfg, roots: appleRoots}
}

// Enabled reports whether the client can verify anything.
func (c *Client) Enabled() bool {
	return c != nil && c.cfg.BundleID != "" && c.cfg.ProductIDMonthly != "" && c.cfg.ProductIDYearly != ""
}

// TransactionInfo is the subset of a StoreKit 2 JWSTransactionDecodedPayload
// mitlist reads. Apple signs this, so every field here is trustworthy once the
// JWS verifies.
//
// https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload
type TransactionInfo struct {
	// TransactionID is this specific transaction. OriginalTransactionID is
	// stable across every renewal of the same subscription and is what we key a
	// subscription on.
	TransactionID         string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	// AppAccountToken carries the mitlist user id the app stamped at purchase,
	// so a subscription resolves to an account without trusting a client call.
	AppAccountToken string `json:"appAccountToken"`
	BundleID        string `json:"bundleId"`
	ProductID       string `json:"productId"`
	// Type is "Auto-Renewable Subscription" for the products mitlist sells.
	Type string `json:"type"`
	// PurchaseDate, ExpiresDate, and RevocationDate are Unix milliseconds.
	PurchaseDate   int64 `json:"purchaseDate"`
	ExpiresDate    int64 `json:"expiresDate"`
	RevocationDate int64 `json:"revocationDate"`
	SignedDate     int64 `json:"signedDate"`
	// RevocationReason is present only on a refunded/revoked transaction.
	RevocationReason *int   `json:"revocationReason"`
	Environment      string `json:"environment"`
	Currency         string `json:"currency"`
	// Price is in the currency's minor units (see Apple's field docs).
	Price int `json:"price"`
	jwt.RegisteredClaims
}

// Expiry returns the subscription's expiry as a time, or the zero time when the
// transaction carries none (a non-renewing product).
func (t *TransactionInfo) Expiry() time.Time {
	if t.ExpiresDate == 0 {
		return time.Time{}
	}
	return time.UnixMilli(t.ExpiresDate).UTC()
}

// Revoked reports whether Apple has refunded or revoked this transaction, which
// must drop entitlement.
func (t *TransactionInfo) Revoked() bool {
	return t.RevocationDate != 0
}

// ModifiedAt is the best monotonic provider timestamp available in a signed
// transaction. signedDate is crucial for lifecycle events such as refunds,
// whose transaction may retain an old purchaseDate.
func (t *TransactionInfo) ModifiedAt() time.Time {
	if t == nil {
		return time.Time{}
	}
	latest := max(t.PurchaseDate, t.RevocationDate, t.SignedDate)
	if latest == 0 {
		return time.Time{}
	}
	return time.UnixMilli(latest).UTC()
}

// VerifyTransaction verifies a StoreKit 2 signed transaction JWS and returns its
// decoded payload. It confirms the Apple certificate chain, the signature, that
// the transaction is for this app's bundle id, and that it was signed for the
// configured store environment.
func (c *Client) VerifyTransaction(signedTransaction string) (*TransactionInfo, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}

	var info TransactionInfo
	if err := c.verifyJWS(signedTransaction, &info); err != nil {
		return nil, err
	}
	if info.BundleID != c.cfg.BundleID {
		return nil, fmt.Errorf("appstore: transaction bundle id %q is not this app", info.BundleID)
	}
	if !environmentMatches(c.cfg.Environment, info.Environment) {
		return nil, fmt.Errorf("appstore: transaction signed for %q, server expects %q", info.Environment, c.cfg.Environment)
	}
	if !c.productAllowed(info.ProductID) {
		return nil, fmt.Errorf("appstore: product id %q is not a configured premium subscription", info.ProductID)
	}
	if info.Type != "" && info.Type != "Auto-Renewable Subscription" {
		return nil, fmt.Errorf("appstore: transaction type %q is not a subscription", info.Type)
	}
	return &info, nil
}

// NotificationEnvelope is the App Store Server Notifications V2 signedPayload,
// decoded. The interesting data (transaction, renewal info) is itself signed
// JWS nested inside, so it is verified separately.
//
// https://developer.apple.com/documentation/appstoreservernotifications/responsebodyv2decodedpayload
type NotificationEnvelope struct {
	NotificationType string `json:"notificationType"`
	Subtype          string `json:"subtype"`
	// NotificationUUID is stable per notification and is used for idempotency.
	NotificationUUID string `json:"notificationUUID"`
	Data             struct {
		BundleID              string `json:"bundleId"`
		AppAppleID            int64  `json:"appAppleId"`
		Environment           string `json:"environment"`
		SignedTransactionInfo string `json:"signedTransactionInfo"`
		SignedRenewalInfo     string `json:"signedRenewalInfo"`
	} `json:"data"`
	jwt.RegisteredClaims
}

// VerifiedNotification is a fully-verified App Store notification: the outer
// envelope and the nested transaction have both had their signatures checked.
type VerifiedNotification struct {
	Type        string
	Subtype     string
	UUID        string
	Transaction *TransactionInfo
	Renewal     *RenewalInfo
}

// RenewalInfo is the signed renewal-state subset needed for cancellation and
// billing-retry lifecycle rendering.
type RenewalInfo struct {
	OriginalTransactionID  string `json:"originalTransactionId"`
	AutoRenewProductID     string `json:"autoRenewProductId"`
	AutoRenewStatus        int    `json:"autoRenewStatus"`
	ExpirationIntent       int    `json:"expirationIntent"`
	IsInBillingRetryPeriod bool   `json:"isInBillingRetryPeriod"`
	GracePeriodExpiresDate int64  `json:"gracePeriodExpiresDate"`
	SignedDate             int64  `json:"signedDate"`
	Environment            string `json:"environment"`
	jwt.RegisteredClaims
}

func (r *RenewalInfo) GracePeriodExpiry() time.Time {
	if r == nil || r.GracePeriodExpiresDate == 0 {
		return time.Time{}
	}
	return time.UnixMilli(r.GracePeriodExpiresDate).UTC()
}

func (r *RenewalInfo) ModifiedAt() time.Time {
	if r == nil {
		return time.Time{}
	}
	if r.SignedDate != 0 {
		return time.UnixMilli(r.SignedDate).UTC()
	}
	if r.IssuedAt == nil {
		return time.Time{}
	}
	return r.IssuedAt.Time.UTC()
}

// VerifyNotification verifies an App Store Server Notification V2 signedPayload
// and the transaction nested inside it.
func (c *Client) VerifyNotification(signedPayload string) (*VerifiedNotification, error) {
	if !c.Enabled() {
		return nil, ErrDisabled
	}

	var env NotificationEnvelope
	if err := c.verifyJWS(signedPayload, &env); err != nil {
		return nil, err
	}
	if env.Data.BundleID != "" && env.Data.BundleID != c.cfg.BundleID {
		return nil, fmt.Errorf("appstore: notification bundle id %q is not this app", env.Data.BundleID)
	}
	if env.Data.Environment == "Production" && (c.cfg.AppAppleID == 0 || env.Data.AppAppleID != c.cfg.AppAppleID) {
		return nil, fmt.Errorf("appstore: notification app Apple ID %d is not this app", env.Data.AppAppleID)
	}
	if !environmentMatches(c.cfg.Environment, env.Data.Environment) {
		return nil, fmt.Errorf("appstore: notification signed for %q, server expects %q", env.Data.Environment, c.cfg.Environment)
	}

	out := &VerifiedNotification{
		Type:    env.NotificationType,
		Subtype: env.Subtype,
		UUID:    env.NotificationUUID,
	}
	if env.Data.SignedTransactionInfo != "" {
		var tx TransactionInfo
		if err := c.verifyJWS(env.Data.SignedTransactionInfo, &tx); err != nil {
			return nil, fmt.Errorf("appstore: nested transaction: %w", err)
		}
		if tx.BundleID != "" && tx.BundleID != c.cfg.BundleID {
			return nil, fmt.Errorf("appstore: nested transaction bundle id %q is not this app", tx.BundleID)
		}
		if !environmentMatches(c.cfg.Environment, tx.Environment) {
			return nil, fmt.Errorf("appstore: nested transaction environment %q is not accepted", tx.Environment)
		}
		if !sameEnvironment(env.Data.Environment, tx.Environment) {
			return nil, fmt.Errorf("appstore: transaction environment %q does not match notification environment %q", tx.Environment, env.Data.Environment)
		}
		if !c.productAllowed(tx.ProductID) {
			return nil, fmt.Errorf("appstore: product id %q is not configured", tx.ProductID)
		}
		out.Transaction = &tx
	}
	if env.Data.SignedRenewalInfo != "" {
		var renewal RenewalInfo
		if err := c.verifyJWS(env.Data.SignedRenewalInfo, &renewal); err != nil {
			return nil, fmt.Errorf("appstore: nested renewal info: %w", err)
		}
		if !environmentMatches(c.cfg.Environment, renewal.Environment) {
			return nil, fmt.Errorf("appstore: nested renewal environment %q is not accepted", renewal.Environment)
		}
		if !sameEnvironment(env.Data.Environment, renewal.Environment) {
			return nil, fmt.Errorf("appstore: renewal environment %q does not match notification environment %q", renewal.Environment, env.Data.Environment)
		}
		if renewal.AutoRenewProductID != "" && !c.productAllowed(renewal.AutoRenewProductID) {
			return nil, fmt.Errorf("appstore: renewal product id %q is not configured", renewal.AutoRenewProductID)
		}
		out.Renewal = &renewal
	}
	return out, nil
}

// environmentMatches allows an empty payload environment (some fields omit it)
// but otherwise requires an exact match, case-sensitive as Apple sends it.
func environmentMatches(want, got string) bool {
	return got == "" || want == "Both" || want == "both" || got == want
}

func sameEnvironment(outer, inner string) bool {
	return outer == "" || inner == "" || outer == inner
}

func (c *Client) productAllowed(productID string) bool {
	return productID != "" && (productID == c.cfg.ProductIDMonthly || productID == c.cfg.ProductIDYearly)
}

// verifyJWS verifies an Apple JWS: it walks the x5c chain to the trust root,
// checks the ES256 signature against the chain's leaf key, and unmarshals the
// payload into claims. A failure at any step returns an error and claims is left
// untouched.
func (c *Client) verifyJWS(token string, claims jwt.Claims) error {
	parser := jwt.NewParser(jwt.WithValidMethods([]string{"ES256"}))
	_, err := parser.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		return leafKey(t, c.roots)
	})
	if err != nil {
		return fmt.Errorf("appstore: JWS verification failed: %w", err)
	}
	return nil
}

// leafKey extracts the x5c certificate chain from a JWS header, verifies it
// chains to roots, and returns the leaf's public key for signature verification.
// This is where trust is established: an attacker cannot forge a chain that
// verifies against Apple's root.
func leafKey(t *jwt.Token, roots *x509.CertPool) (*ecdsa.PublicKey, error) {
	rawChain, ok := t.Header["x5c"].([]any)
	if !ok || len(rawChain) == 0 {
		return nil, errors.New("appstore: JWS header has no x5c certificate chain")
	}

	certs := make([]*x509.Certificate, 0, len(rawChain))
	for i, raw := range rawChain {
		encoded, ok := raw.(string)
		if !ok {
			return nil, fmt.Errorf("appstore: x5c entry %d is not a string", i)
		}
		der, err := base64.StdEncoding.DecodeString(encoded)
		if err != nil {
			return nil, fmt.Errorf("appstore: x5c entry %d is not base64: %w", i, err)
		}
		cert, err := x509.ParseCertificate(der)
		if err != nil {
			return nil, fmt.Errorf("appstore: x5c entry %d is not a certificate: %w", i, err)
		}
		certs = append(certs, cert)
	}

	leaf := certs[0]
	if !hasExtension(leaf, appStoreReceiptSigningOID) {
		return nil, errors.New("appstore: leaf certificate is not authorised to sign App Store data")
	}
	if len(certs) < 2 || !hasExtension(certs[1], appleWWDRIntermediateOID) {
		return nil, errors.New("appstore: certificate chain has no Apple WWDR intermediate")
	}
	intermediates := x509.NewCertPool()
	for _, cert := range certs[1:] {
		intermediates.AddCert(cert)
	}

	// Apple's leaf certs carry OID extensions rather than standard EKUs, so
	// accept any extended key usage; the chain to Apple's root is the guarantee.
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:         roots,
		Intermediates: intermediates,
		KeyUsages:     []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
		CurrentTime:   time.Now(),
	}); err != nil {
		return nil, fmt.Errorf("appstore: certificate chain does not verify against Apple root: %w", err)
	}

	key, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("appstore: leaf certificate key is not ECDSA")
	}
	return key, nil
}

func hasExtension(cert *x509.Certificate, oid asn1.ObjectIdentifier) bool {
	for _, extension := range cert.Extensions {
		if extension.Id.Equal(oid) {
			return true
		}
	}
	return false
}
