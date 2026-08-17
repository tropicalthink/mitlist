package appstore

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"math/big"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// testChain is a throwaway two-cert chain (root + leaf) standing in for Apple's
// real chain, so the x5c verification path can be exercised without Apple's
// private key.
type testChain struct {
	roots     *x509.CertPool
	leafDER   []byte
	issuerDER []byte
	leafKey   *ecdsa.PrivateKey
}

func newTestChain(t *testing.T) *testChain {
	return newTestChainWithPurpose(t, true)
}

func newTestChainWithPurpose(t *testing.T, includeLeafPurpose bool) *testChain {
	t.Helper()

	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("root key: %v", err)
	}
	rootTmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Test Root CA"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTmpl, rootTmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("root cert: %v", err)
	}
	rootCert, _ := x509.ParseCertificate(rootDER)

	issuerKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("issuer key: %v", err)
	}
	issuerTmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(2),
		Subject:               pkix.Name{CommonName: "Test WWDR CA"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
		KeyUsage:              x509.KeyUsageCertSign,
		ExtraExtensions: []pkix.Extension{{
			Id: appleWWDRIntermediateOID, Value: []byte{0x05, 0x00},
		}},
	}
	issuerDER, err := x509.CreateCertificate(rand.Reader, issuerTmpl, rootCert, &issuerKey.PublicKey, rootKey)
	if err != nil {
		t.Fatalf("issuer cert: %v", err)
	}
	issuerCert, _ := x509.ParseCertificate(issuerDER)

	leafKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatalf("leaf key: %v", err)
	}
	leafTmpl := &x509.Certificate{
		SerialNumber: big.NewInt(3),
		Subject:      pkix.Name{CommonName: "Test Leaf"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
	}
	if includeLeafPurpose {
		leafTmpl.ExtraExtensions = []pkix.Extension{{
			Id: appStoreReceiptSigningOID, Value: []byte{0x05, 0x00},
		}}
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTmpl, issuerCert, &leafKey.PublicKey, issuerKey)
	if err != nil {
		t.Fatalf("leaf cert: %v", err)
	}

	roots := x509.NewCertPool()
	roots.AddCert(rootCert)

	return &testChain{roots: roots, leafDER: leafDER, issuerDER: issuerDER, leafKey: leafKey}
}

// sign builds a JWS with the given claims, signed by the leaf key, carrying the
// leaf+root x5c chain — the exact shape Apple produces.
func (tc *testChain) sign(t *testing.T, claims jwt.Claims) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	tok.Header["x5c"] = []string{
		base64.StdEncoding.EncodeToString(tc.leafDER),
		base64.StdEncoding.EncodeToString(tc.issuerDER),
	}
	signed, err := tok.SignedString(tc.leafKey)
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	return signed
}

func (tc *testChain) client(bundleID, env string) *Client {
	return &Client{cfg: Config{
		BundleID: bundleID, Environment: env,
		ProductIDMonthly: "dev.mohamad.mitlist.premium.monthly",
		ProductIDYearly:  "dev.mohamad.mitlist.premium.yearly",
	}, roots: tc.roots}
}

func TestVerifyTransaction_ValidChain(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Sandbox")

	expires := time.Now().Add(365 * 24 * time.Hour).Truncate(time.Millisecond)
	token := tc.sign(t, &TransactionInfo{
		OriginalTransactionID: "orig-123",
		AppAccountToken:       "user-uuid",
		BundleID:              "dev.mohamad.mitlist",
		ProductID:             "dev.mohamad.mitlist.premium.yearly",
		Environment:           "Sandbox",
		ExpiresDate:           expires.UnixMilli(),
	})

	info, err := c.VerifyTransaction(token)
	if err != nil {
		t.Fatalf("VerifyTransaction: %v", err)
	}
	if info.OriginalTransactionID != "orig-123" {
		t.Errorf("original transaction id = %q", info.OriginalTransactionID)
	}
	if info.Revoked() {
		t.Error("unexpectedly revoked")
	}
	if got := info.Expiry().UnixMilli(); got != expires.UnixMilli() {
		t.Errorf("expiry = %d, want %d", got, expires.UnixMilli())
	}
}

func TestVerifyTransaction_WrongBundleRejected(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Sandbox")

	token := tc.sign(t, &TransactionInfo{BundleID: "com.someone.else", Environment: "Sandbox"})
	if _, err := c.VerifyTransaction(token); err == nil {
		t.Fatal("expected rejection of a transaction for another bundle id")
	}
}

func TestVerifyTransaction_WrongEnvironmentRejected(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Production")

	token := tc.sign(t, &TransactionInfo{BundleID: "dev.mohamad.mitlist", Environment: "Sandbox"})
	if _, err := c.VerifyTransaction(token); err == nil {
		t.Fatal("expected rejection of a sandbox receipt on a production server")
	}
}

func TestVerifyTransaction_BothEnvironmentsAcceptsSandbox(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Both")
	token := tc.sign(t, &TransactionInfo{
		BundleID:    "dev.mohamad.mitlist",
		ProductID:   "dev.mohamad.mitlist.premium.monthly",
		Environment: "Sandbox",
	})
	if _, err := c.VerifyTransaction(token); err != nil {
		t.Fatalf("Both should accept a signed sandbox transaction: %v", err)
	}
}

func TestVerifyTransaction_UnknownProductRejected(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Sandbox")
	token := tc.sign(t, &TransactionInfo{
		BundleID: "dev.mohamad.mitlist", ProductID: "coins", Environment: "Sandbox",
	})
	if _, err := c.VerifyTransaction(token); err == nil {
		t.Fatal("expected an unconfigured product to be rejected")
	}
}

func TestVerifyNotification_RejectsNestedEnvironmentMismatch(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Both")
	nested := tc.sign(t, &TransactionInfo{
		BundleID: "dev.mohamad.mitlist", ProductID: "dev.mohamad.mitlist.premium.monthly", Environment: "Production",
	})
	var envelope NotificationEnvelope
	envelope.NotificationType = "DID_RENEW"
	envelope.Data.BundleID = "dev.mohamad.mitlist"
	envelope.Data.Environment = "Sandbox"
	envelope.Data.SignedTransactionInfo = nested
	if _, err := c.VerifyNotification(tc.sign(t, &envelope)); err == nil {
		t.Fatal("expected nested transaction environment mismatch to be rejected")
	}
}

func TestVerifyNotification_ValidatesProductionAppAppleID(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Production")
	c.cfg.AppAppleID = 123456789
	var envelope NotificationEnvelope
	envelope.NotificationType = "TEST"
	envelope.Data.BundleID = "dev.mohamad.mitlist"
	envelope.Data.Environment = "Production"
	envelope.Data.AppAppleID = 987654321
	if _, err := c.VerifyNotification(tc.sign(t, &envelope)); err == nil {
		t.Fatal("expected production notification for another app Apple ID to be rejected")
	}
}

func TestVerifyTransaction_UntrustedChainRejected(t *testing.T) {
	signer := newTestChain(t)   // signs with its own root
	verifier := newTestChain(t) // trusts a *different* root

	token := signer.sign(t, &TransactionInfo{BundleID: "dev.mohamad.mitlist", Environment: "Sandbox"})
	c := verifier.client("dev.mohamad.mitlist", "Sandbox")

	if _, err := c.VerifyTransaction(token); err == nil {
		t.Fatal("expected rejection: chain does not verify against the trusted root")
	}
}

func TestVerifyTransaction_WrongCertificatePurposeRejected(t *testing.T) {
	tc := newTestChainWithPurpose(t, false)
	c := tc.client("dev.mohamad.mitlist", "Sandbox")
	token := tc.sign(t, &TransactionInfo{
		BundleID: "dev.mohamad.mitlist", ProductID: "dev.mohamad.mitlist.premium.monthly", Environment: "Sandbox",
	})
	if _, err := c.VerifyTransaction(token); err == nil {
		t.Fatal("expected a leaf without the App Store signing OID to be rejected")
	}
}

func TestVerifyTransaction_TamperedPayloadRejected(t *testing.T) {
	tc := newTestChain(t)
	c := tc.client("dev.mohamad.mitlist", "Sandbox")

	token := tc.sign(t, &TransactionInfo{BundleID: "dev.mohamad.mitlist", Environment: "Sandbox"})
	// Flip a character in the payload segment; the signature must no longer match.
	tampered := []byte(token)
	dot := 0
	for i, ch := range tampered {
		if ch == '.' {
			dot = i
			break
		}
	}
	if tampered[dot+2] == 'A' {
		tampered[dot+2] = 'B'
	} else {
		tampered[dot+2] = 'A'
	}
	if _, err := c.VerifyTransaction(string(tampered)); err == nil {
		t.Fatal("expected rejection of a tampered payload")
	}
}

func TestDisabledClientVerifiesNothing(t *testing.T) {
	c := New(Config{}) // no bundle id
	if c.Enabled() {
		t.Fatal("client with no bundle id should be disabled")
	}
	if _, err := c.VerifyTransaction("anything"); err != ErrDisabled {
		t.Fatalf("want ErrDisabled, got %v", err)
	}
}

func TestRevokedTransaction(t *testing.T) {
	purchased := time.Now().Add(-30 * 24 * time.Hour).Truncate(time.Millisecond)
	revoked := time.Now().Truncate(time.Millisecond)
	info := &TransactionInfo{
		PurchaseDate:   purchased.UnixMilli(),
		RevocationDate: revoked.UnixMilli(),
		SignedDate:     revoked.Add(time.Minute).UnixMilli(),
	}
	if !info.Revoked() {
		t.Error("a transaction with a revocation date should report revoked")
	}
	if got := info.ModifiedAt(); !got.Equal(revoked.Add(time.Minute)) {
		t.Fatalf("modified time = %s, want signed event time %s", got, revoked.Add(time.Minute))
	}
}
