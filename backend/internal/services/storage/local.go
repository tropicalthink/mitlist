package storage

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"net/url"
	"os"
	"path"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/rs/zerolog/log"
)

// Local disk storage for self-hosts without S3.
//
// Clients keep the presigned-URL flow they use against S3: the upload intent
// hands them a PUT URL, and download endpoints hand them a short-lived GET URL.
// Both point at the API itself:
//
//	{PUBLIC_API_URL}{API_PREFIX}/v1/files/{key}?exp=<unix>&sig=<hex>                    (GET)
//	{PUBLIC_API_URL}{API_PREFIX}/v1/files/{key}?ct=<type>&exp=<unix>&len=<n>&sig=<hex>  (PUT)
//
// The signature is the credential, so the route is public. It is an
// HMAC-SHA256 under a key derived from SECRET_KEY for this purpose alone, over
// the method, the object key, the expiry and, for PUT, the exact byte length
// and the content type the server accepted at intent time. As with the S3
// presign, the client's own Content-Type header is not bound (shipped app
// versions send types the intent normalizes away); the signed `ct` is what is
// stored and served back.
//
// On disk, under STORAGE_LOCAL_PATH:
//
//	objects/<key>  the bytes
//	meta/<key>     the content type, as plain text
//	tmp/           uploads in flight, renamed into objects/ once complete
//
// All file access goes through an os.Root, so no key can reach outside the
// directory even if the lexical checks in ValidateKey missed something.

const (
	// localDownloadExpiry matches the S3 backend's presigned GET lifetime.
	localDownloadExpiry = 15 * time.Minute
	// localTransferTimeout replaces the server's 30 s read/write timeouts for
	// one file transfer: a 10 MiB photo over a weak mobile link takes longer.
	localTransferTimeout = 10 * time.Minute
	// maxKeyLen mirrors S3's 1024-byte object key limit.
	maxKeyLen = 1024
	// staleTempAge is how old an abandoned tmp/ upload must be before startup
	// removes it.
	staleTempAge = time.Hour

	signingPurpose = "mitlist-local-storage"
	signatureLabel = "mitlist-local-storage/v1"

	objectsDir = "objects"
	metaDir    = "meta"
	tmpDir     = "tmp"

	dirPerm  fs.FileMode = 0o750
	filePerm fs.FileMode = 0o640
)

var (
	errInvalidKey   = errors.New("invalid object key")
	errExpired      = errors.New("signed URL has expired")
	errBadSignature = errors.New("signature does not match")
	errMalformedURL = errors.New("malformed signed URL")
	errSizeMismatch = errors.New("body length does not match the signed length")
)

// LocalStore stores objects on the local filesystem and serves them through
// signed URLs on the API's own origin.
type LocalStore struct {
	root    *os.Root
	signKey []byte
	// baseURL is the absolute URL every object key is appended to, ending in
	// "/files/". Empty when PUBLIC_API_URL is unset: then no URL can be
	// issued and uploads fail, exactly like unconfigured S3.
	baseURL string
	now     func() time.Time
}

// NewLocalStore opens (creating if needed) dir as the storage root. secret is
// SECRET_KEY; publicAPIURL and apiPrefix locate this API's routes from the
// outside.
func NewLocalStore(dir string, secret []byte, publicAPIURL, apiPrefix string) (*LocalStore, error) {
	if len(secret) == 0 {
		return nil, errors.New("SECRET_KEY is empty; local storage cannot sign URLs")
	}
	if err := os.MkdirAll(dir, dirPerm); err != nil {
		return nil, fmt.Errorf("create storage directory: %w", err)
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, fmt.Errorf("open storage directory: %w", err)
	}
	for _, sub := range []string{objectsDir, metaDir, tmpDir} {
		if err := root.MkdirAll(sub, dirPerm); err != nil {
			_ = root.Close()
			return nil, fmt.Errorf("create storage directory %s: %w", sub, err)
		}
	}
	// A probe write surfaces a read-only or wrongly owned volume at startup
	// rather than on the first upload.
	probe := path.Join(tmpDir, ".write-probe")
	if err := root.WriteFile(probe, nil, filePerm); err != nil {
		_ = root.Close()
		return nil, fmt.Errorf("storage directory is not writable: %w", err)
	}
	_ = root.Remove(probe)

	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(signingPurpose))

	l := &LocalStore{
		root:    root,
		signKey: mac.Sum(nil),
		baseURL: localBaseURL(publicAPIURL, apiPrefix),
		now:     time.Now,
	}
	l.removeStaleTemps()
	return l, nil
}

func localBaseURL(publicAPIURL, apiPrefix string) string {
	origin := strings.TrimRight(strings.TrimSpace(publicAPIURL), "/")
	if origin == "" {
		return ""
	}
	if p := strings.Trim(apiPrefix, "/"); p != "" {
		origin += "/" + p
	}
	return origin + "/v1/files/"
}

// ValidateKey rejects object keys that could not be an S3-style key the
// services build (groups/<id>/attachments/<id>/<file>) or that would escape
// the storage directory: empty, over-long, absolute, containing a backslash
// or NUL, or with an empty, "." or ".." segment.
func ValidateKey(key string) error {
	if key == "" || len(key) > maxKeyLen {
		return errInvalidKey
	}
	if strings.HasPrefix(key, "/") || strings.ContainsAny(key, "\\\x00") {
		return errInvalidKey
	}
	for _, seg := range strings.Split(key, "/") {
		if seg == "" || seg == "." || seg == ".." {
			return errInvalidKey
		}
	}
	return nil
}

// RegisterRoutes mounts the signed file endpoints on the /v1 router. They are
// public: the signature in the query is the credential.
func (l *LocalStore) RegisterRoutes(r chi.Router) {
	r.Get("/files/*", l.serveGet)
	r.Put("/files/*", l.servePut)
}

// ---- signing ----

// sign is HMAC-SHA256 over the length-prefixed fields, so no choice of key
// (filenames are user-supplied) can shift bytes from one field into another.
// GET signs length -1 and an empty content type.
func (l *LocalStore) sign(method, key string, exp, length int64, contentType string) []byte {
	mac := hmac.New(sha256.New, l.signKey)
	for _, f := range []string{
		signatureLabel,
		method,
		key,
		strconv.FormatInt(exp, 10),
		strconv.FormatInt(length, 10),
		contentType,
	} {
		var n [4]byte
		binary.BigEndian.PutUint32(n[:], uint32(len(f)))
		mac.Write(n[:])
		mac.Write([]byte(f))
	}
	return mac.Sum(nil)
}

func (l *LocalStore) objectURL(key string, q url.Values) string {
	segs := strings.Split(key, "/")
	for i, s := range segs {
		segs[i] = url.PathEscape(s)
	}
	return l.baseURL + strings.Join(segs, "/") + "?" + q.Encode()
}

// verify checks a signed URL's query for method and key. For PUT it returns
// the signed byte length and content type.
func (l *LocalStore) verify(method, key string, q url.Values) (int64, string, error) {
	exp, err := strconv.ParseInt(q.Get("exp"), 10, 64)
	if err != nil {
		return 0, "", errMalformedURL
	}
	sig, err := hex.DecodeString(q.Get("sig"))
	if err != nil || len(sig) != sha256.Size {
		return 0, "", errMalformedURL
	}
	length := int64(-1)
	contentType := ""
	if method == http.MethodPut {
		length, err = strconv.ParseInt(q.Get("len"), 10, 64)
		if err != nil || length < 0 {
			return 0, "", errMalformedURL
		}
		contentType = q.Get("ct")
	}
	if !hmac.Equal(sig, l.sign(method, key, exp, length, contentType)) {
		return 0, "", errBadSignature
	}
	// Expiry is checked only once the signature proves exp is ours.
	if l.now().Unix() > exp {
		return 0, "", errExpired
	}
	return length, contentType, nil
}

// ---- backend methods (same contracts as the S3 backend) ----

// GetUploadURL returns a signed PUT URL bound to exactly contentLength bytes.
func (l *LocalStore) GetUploadURL(key string, contentType string, contentLength int64, expires time.Duration) string {
	if l.baseURL == "" {
		log.Error().Str("key", key).Msg("cannot issue a local upload URL: PUBLIC_API_URL is not set")
		return ""
	}
	if err := ValidateKey(key); err != nil || contentLength < 0 {
		log.Error().Str("key", key).Int64("content_length", contentLength).Msg("refusing to sign a local upload URL for an invalid key or length")
		return ""
	}
	if expires <= 0 {
		expires = 15 * time.Minute
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	exp := l.now().Add(expires).Unix()
	q := url.Values{}
	q.Set("exp", strconv.FormatInt(exp, 10))
	q.Set("len", strconv.FormatInt(contentLength, 10))
	q.Set("ct", contentType)
	q.Set("sig", hex.EncodeToString(l.sign(http.MethodPut, key, exp, contentLength, contentType)))
	return l.objectURL(key, q)
}

// GetURL returns a signed GET URL valid for 15 minutes.
func (l *LocalStore) GetURL(key string) string {
	if l.baseURL == "" {
		log.Error().Str("key", key).Msg("cannot issue a local download URL: PUBLIC_API_URL is not set")
		return ""
	}
	if err := ValidateKey(key); err != nil {
		log.Error().Str("key", key).Msg("refusing to sign a local download URL for an invalid key")
		return ""
	}
	exp := l.now().Add(localDownloadExpiry).Unix()
	q := url.Values{}
	q.Set("exp", strconv.FormatInt(exp, 10))
	q.Set("sig", hex.EncodeToString(l.sign(http.MethodGet, key, exp, -1, "")))
	return l.objectURL(key, q)
}

// Upload stores data at key, replacing any existing object atomically.
func (l *LocalStore) Upload(key string, data []byte, contentType string) error {
	if err := ValidateKey(key); err != nil {
		return err
	}
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	if err := l.put(key, bytes.NewReader(data), int64(len(data)), contentType); err != nil {
		return fmt.Errorf("upload to local storage: %w", err)
	}
	return nil
}

// Download reads the whole object at key.
func (l *LocalStore) Download(ctx context.Context, key string) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if err := ValidateKey(key); err != nil {
		return nil, err
	}
	data, err := l.root.ReadFile(path.Join(objectsDir, key))
	if err != nil {
		return nil, fmt.Errorf("download from local storage: %w", err)
	}
	return data, nil
}

// HeadObjectSize returns the stored object's size in bytes.
func (l *LocalStore) HeadObjectSize(ctx context.Context, key string) (int64, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	if err := ValidateKey(key); err != nil {
		return 0, err
	}
	fi, err := l.root.Stat(path.Join(objectsDir, key))
	if err != nil {
		return 0, fmt.Errorf("head object in local storage: %w", err)
	}
	if !fi.Mode().IsRegular() {
		return 0, fmt.Errorf("head object in local storage: %s is not a file", key)
	}
	return fi.Size(), nil
}

// Delete removes the object at key. Like S3's DeleteObject, deleting a
// missing object succeeds. Directories the object leaves empty are removed.
func (l *LocalStore) Delete(key string) error {
	if err := ValidateKey(key); err != nil {
		return err
	}
	for _, base := range []string{objectsDir, metaDir} {
		if err := l.root.Remove(path.Join(base, key)); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return fmt.Errorf("delete from local storage: %w", err)
		}
		// Remove refuses a non-empty directory, which ends the walk.
		for dir := path.Dir(key); dir != "."; dir = path.Dir(dir) {
			if l.root.Remove(path.Join(base, dir)) != nil {
				break
			}
		}
	}
	return nil
}

// ---- file plumbing ----

// put streams r into a temp file, checks it is exactly size bytes, and
// renames it over objects/<key>; then records the content type.
func (l *LocalStore) put(key string, r io.Reader, size int64, contentType string) error {
	if err := l.writeAtomic(path.Join(objectsDir, key), r, size); err != nil {
		return err
	}
	if err := l.writeAtomic(path.Join(metaDir, key), strings.NewReader(contentType), int64(len(contentType))); err != nil {
		// The object is in place; downloads fall back to sniffing its type.
		log.Warn().Err(err).Str("key", key).Msg("local storage: could not record content type")
	}
	return nil
}

func (l *LocalStore) writeAtomic(dst string, r io.Reader, size int64) (err error) {
	var rnd [16]byte
	if _, err := rand.Read(rnd[:]); err != nil {
		return err
	}
	tmp := path.Join(tmpDir, hex.EncodeToString(rnd[:]))
	f, err := l.root.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_EXCL, filePerm)
	if err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = l.root.Remove(tmp)
		}
	}()
	n, err := io.Copy(f, r)
	if err == nil && n != size {
		err = errSizeMismatch
	}
	if err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	// A concurrent Delete can prune the parent directory between MkdirAll
	// and Rename; one retry covers that.
	for attempt := 0; ; attempt++ {
		if err = l.root.MkdirAll(path.Dir(dst), dirPerm); err == nil {
			if err = l.root.Rename(tmp, dst); err == nil {
				return nil
			}
		}
		if attempt > 0 || !errors.Is(err, fs.ErrNotExist) {
			return err
		}
	}
}

func (l *LocalStore) removeStaleTemps() {
	f, err := l.root.Open(tmpDir)
	if err != nil {
		return
	}
	defer f.Close()
	entries, err := f.ReadDir(-1)
	if err != nil {
		return
	}
	cutoff := l.now().Add(-staleTempAge)
	for _, e := range entries {
		if info, err := e.Info(); err == nil && info.Mode().IsRegular() && info.ModTime().Before(cutoff) {
			_ = l.root.Remove(path.Join(tmpDir, e.Name()))
		}
	}
}

// ---- HTTP ----

// keyFromRequest recovers the object key from the /files/* wildcard. chi
// matches on the escaped path whenever the request has one that differs from
// the default encoding (RawPath), and the decoded path otherwise.
func keyFromRequest(r *http.Request) (string, error) {
	key := chi.URLParam(r, "*")
	if r.URL.RawPath != "" {
		var err error
		if key, err = url.PathUnescape(key); err != nil {
			return "", errInvalidKey
		}
	}
	if err := ValidateKey(key); err != nil {
		return "", err
	}
	return key, nil
}

func writeVerifyError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, errExpired), errors.Is(err, errBadSignature):
		http.Error(w, err.Error(), http.StatusForbidden)
	default:
		http.Error(w, err.Error(), http.StatusBadRequest)
	}
}

func (l *LocalStore) servePut(w http.ResponseWriter, r *http.Request) {
	key, err := keyFromRequest(r)
	if err != nil {
		writeVerifyError(w, err)
		return
	}
	length, contentType, err := l.verify(http.MethodPut, key, r.URL.Query())
	if err != nil {
		writeVerifyError(w, err)
		return
	}
	if r.ContentLength < 0 {
		http.Error(w, "Content-Length is required", http.StatusLengthRequired)
		return
	}
	if r.ContentLength != length {
		http.Error(w, errSizeMismatch.Error(), http.StatusBadRequest)
		return
	}
	_ = http.NewResponseController(w).SetReadDeadline(time.Now().Add(localTransferTimeout))

	body := http.MaxBytesReader(w, r.Body, length)
	if err := l.put(key, body, length, contentType); err != nil {
		var tooLarge *http.MaxBytesError
		switch {
		case errors.As(err, &tooLarge):
			http.Error(w, errSizeMismatch.Error(), http.StatusRequestEntityTooLarge)
		case errors.Is(err, errSizeMismatch), errors.Is(err, io.ErrUnexpectedEOF):
			http.Error(w, errSizeMismatch.Error(), http.StatusBadRequest)
		default:
			log.Error().Err(err).Str("key", key).Msg("local storage: upload failed")
			http.Error(w, "upload failed", http.StatusInternalServerError)
		}
		return
	}
	w.WriteHeader(http.StatusOK)
}

func (l *LocalStore) serveGet(w http.ResponseWriter, r *http.Request) {
	key, err := keyFromRequest(r)
	if err != nil {
		writeVerifyError(w, err)
		return
	}
	if _, _, err := l.verify(http.MethodGet, key, r.URL.Query()); err != nil {
		writeVerifyError(w, err)
		return
	}
	f, err := l.root.Open(path.Join(objectsDir, key))
	if err != nil {
		if !errors.Is(err, fs.ErrNotExist) {
			log.Error().Err(err).Str("key", key).Msg("local storage: open failed")
		}
		http.NotFound(w, r)
		return
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil || !fi.Mode().IsRegular() {
		http.NotFound(w, r)
		return
	}

	h := w.Header()
	if ct, err := l.root.ReadFile(path.Join(metaDir, key)); err == nil && len(ct) > 0 {
		h.Set("Content-Type", string(ct))
	}
	// Without a recorded type, ServeContent infers one from the extension
	// or by sniffing the first 512 bytes.
	h.Set("Cache-Control", "private, max-age="+strconv.Itoa(int(localDownloadExpiry.Seconds())))
	// The global SecurityHeaders middleware sends CORP same-origin, which
	// would stop the web app on another origin from showing these images.
	// The signed URL is the access control, as with an S3 presigned GET.
	h.Set("Cross-Origin-Resource-Policy", "cross-origin")
	_ = http.NewResponseController(w).SetWriteDeadline(time.Now().Add(localTransferTimeout))
	http.ServeContent(w, r, path.Base(key), fi.ModTime(), f)
}
