package storage

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/require"

	"github.com/mitlist-app/mitlist/internal/config"
)

const testSecret = "unit-test-secret-key-that-is-long-enough"

// A key shaped like buildObjectKey's, with a filename that needs escaping in
// a URL path (space, %, #, ?, non-ASCII).
const testKey = "groups/7d6f0e4e-1d0b-4a8e-9a39-5b0f4b7b2c11/attachments/0b8a6f43-2f5e-4c8c-9f63-0d7c7b7f3e21/receipt 100%#1?é.jpg"

func newTestLocalStore(t *testing.T, publicAPIURL string) (*LocalStore, string) {
	t.Helper()
	dir := t.TempDir()
	l, err := NewLocalStore(dir, []byte(testSecret), publicAPIURL, "/api")
	require.NoError(t, err)
	t.Cleanup(func() { _ = l.root.Close() })
	return l, dir
}

func TestValidateKey(t *testing.T) {
	require.NoError(t, ValidateKey(testKey))
	require.NoError(t, ValidateKey("a"))
	require.NoError(t, ValidateKey("groups/x/..hidden"))

	for _, bad := range []string{
		"",
		"..",
		"../etc/passwd",
		"groups/../../etc/passwd",
		"groups/a/..",
		"./groups/a",
		"groups/./a",
		"/etc/passwd",
		"groups\\..\\..\\etc",
		"groups//a",
		"groups/a/",
		"groups/a\x00b",
		strings.Repeat("a", maxKeyLen+1),
	} {
		require.ErrorIs(t, ValidateKey(bad), errInvalidKey, "key %q", bad)
	}
}

func TestLocalSignedURLs(t *testing.T) {
	l, _ := newTestLocalStore(t, "https://api.example.test/")
	now := time.Unix(1_800_000_000, 0)
	l.now = func() time.Time { return now }

	putURL := l.GetUploadURL(testKey, "image/jpeg", 1234, 5*time.Minute)
	u, err := url.Parse(putURL)
	require.NoError(t, err)
	require.Equal(t, "https", u.Scheme)
	require.Equal(t, "api.example.test", u.Host)
	require.Equal(t, "/api/v1/files/"+testKey, u.Path)
	q := u.Query()
	require.Equal(t, "1234", q.Get("len"))
	require.Equal(t, "image/jpeg", q.Get("ct"))
	require.Equal(t, "1800000300", q.Get("exp"))

	length, ct, err := l.verify(http.MethodPut, testKey, q)
	require.NoError(t, err)
	require.EqualValues(t, 1234, length)
	require.Equal(t, "image/jpeg", ct)

	t.Run("expired", func(t *testing.T) {
		l.now = func() time.Time { return now.Add(5*time.Minute + time.Second) }
		defer func() { l.now = func() time.Time { return now } }()
		_, _, err := l.verify(http.MethodPut, testKey, q)
		require.ErrorIs(t, err, errExpired)
	})

	t.Run("tampered signature", func(t *testing.T) {
		bad := cloneQuery(q)
		sig := []byte(bad.Get("sig"))
		if sig[0] == 'a' {
			sig[0] = 'b'
		} else {
			sig[0] = 'a'
		}
		bad.Set("sig", string(sig))
		_, _, err := l.verify(http.MethodPut, testKey, bad)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("wrong length", func(t *testing.T) {
		bad := cloneQuery(q)
		bad.Set("len", "99999999")
		_, _, err := l.verify(http.MethodPut, testKey, bad)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("extended expiry", func(t *testing.T) {
		bad := cloneQuery(q)
		bad.Set("exp", "1900000000")
		_, _, err := l.verify(http.MethodPut, testKey, bad)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("swapped content type", func(t *testing.T) {
		bad := cloneQuery(q)
		bad.Set("ct", "text/html")
		_, _, err := l.verify(http.MethodPut, testKey, bad)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("other key", func(t *testing.T) {
		_, _, err := l.verify(http.MethodPut, testKey+"x", q)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("PUT signature does not authorize GET", func(t *testing.T) {
		_, _, err := l.verify(http.MethodGet, testKey, q)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("GET signature does not authorize PUT", func(t *testing.T) {
		g, err := url.Parse(l.GetURL(testKey))
		require.NoError(t, err)
		_, _, err = l.verify(http.MethodGet, testKey, g.Query())
		require.NoError(t, err)
		gq := g.Query()
		gq.Set("len", "0")
		gq.Set("ct", "image/jpeg")
		_, _, err = l.verify(http.MethodPut, testKey, gq)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("other secret", func(t *testing.T) {
		other, err := NewLocalStore(t.TempDir(), []byte("another-secret"), "https://api.example.test", "/api")
		require.NoError(t, err)
		defer other.root.Close()
		other.now = l.now
		_, _, err = other.verify(http.MethodPut, testKey, q)
		require.ErrorIs(t, err, errBadSignature)
	})

	t.Run("malformed", func(t *testing.T) {
		for _, mutate := range []func(url.Values){
			func(v url.Values) { v.Del("sig") },
			func(v url.Values) { v.Set("sig", "zz") },
			func(v url.Values) { v.Del("exp") },
			func(v url.Values) { v.Del("len") },
			func(v url.Values) { v.Set("len", "-1") },
		} {
			bad := cloneQuery(q)
			mutate(bad)
			_, _, err := l.verify(http.MethodPut, testKey, bad)
			require.ErrorIs(t, err, errMalformedURL)
		}
	})

	t.Run("refuses to sign traversal", func(t *testing.T) {
		require.Empty(t, l.GetUploadURL("../../etc/passwd", "text/plain", 1, time.Minute))
		require.Empty(t, l.GetURL("groups/../../etc/passwd"))
	})
}

func TestLocalWithoutPublicAPIURLIssuesNoURLs(t *testing.T) {
	l, _ := newTestLocalStore(t, "")
	require.Empty(t, l.GetUploadURL(testKey, "image/jpeg", 10, time.Minute))
	require.Empty(t, l.GetURL(testKey))
}

// TestLocalHandlerRoundTrip drives the real routes the way the app does: PUT
// the bytes to the upload URL with the client's own Content-Type, then
// finalize-style HeadObjectSize, GET the download URL, and delete.
func TestLocalHandlerRoundTrip(t *testing.T) {
	router := chi.NewRouter()
	srv := httptest.NewServer(router)
	defer srv.Close()

	l, dir := newTestLocalStore(t, srv.URL)
	router.Route("/api/v1", func(r chi.Router) { l.RegisterRoutes(r) })

	payload := bytes.Repeat([]byte("mitlist-"), 1000)
	putURL := l.GetUploadURL(testKey, "image/jpeg", int64(len(payload)), 5*time.Minute)
	require.NotEmpty(t, putURL)

	// Wrong length: the signed len is binding.
	resp := doRequest(t, http.MethodPut, putURL, payload[:len(payload)-1], "image/jpeg")
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	resp = doRequest(t, http.MethodPut, putURL, append(payload, 'x'), "image/jpeg")
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	_, err := l.HeadObjectSize(context.Background(), testKey)
	require.Error(t, err, "a rejected PUT must not store anything")

	// Shipped clients may send a different Content-Type than the intent
	// recorded; it is not part of the signature.
	resp = doRequest(t, http.MethodPut, putURL, payload, "image/*")
	require.Equal(t, http.StatusOK, resp.StatusCode)

	size, err := l.HeadObjectSize(context.Background(), testKey)
	require.NoError(t, err)
	require.EqualValues(t, len(payload), size)

	data, err := l.Download(context.Background(), testKey)
	require.NoError(t, err)
	require.Equal(t, payload, data)

	getURL := l.GetURL(testKey)
	resp = doRequest(t, http.MethodGet, getURL, nil, "")
	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, err := io.ReadAll(resp.Body)
	require.NoError(t, err)
	require.Equal(t, payload, body)
	require.Equal(t, "image/jpeg", resp.Header.Get("Content-Type"), "served type is the signed one, not the client header")
	require.Contains(t, resp.Header.Get("Cache-Control"), "private")

	// Server-side rewrite (recompression) replaces bytes and type.
	require.NoError(t, l.Upload(testKey, []byte("RIFF....WEBP"), "image/webp"))
	resp = doRequest(t, http.MethodGet, getURL, nil, "")
	require.Equal(t, http.StatusOK, resp.StatusCode)
	require.Equal(t, "image/webp", resp.Header.Get("Content-Type"))

	// A tampered or expired GET is refused.
	resp = doRequest(t, http.MethodGet, strings.Replace(getURL, "sig=", "sig=00", 1), nil, "")
	require.Equal(t, http.StatusBadRequest, resp.StatusCode)
	l.now = func() time.Time { return time.Now().Add(16 * time.Minute) }
	resp = doRequest(t, http.MethodGet, getURL, nil, "")
	require.Equal(t, http.StatusForbidden, resp.StatusCode)
	l.now = time.Now

	require.NoError(t, l.Delete(testKey))
	require.NoError(t, l.Delete(testKey), "deleting a missing object succeeds, like S3")
	_, err = l.HeadObjectSize(context.Background(), testKey)
	require.Error(t, err)
	resp = doRequest(t, http.MethodGet, getURL, nil, "")
	require.Equal(t, http.StatusNotFound, resp.StatusCode)

	// The per-attachment directories are pruned; the tree roots stay.
	entries, err := os.ReadDir(filepath.Join(dir, objectsDir))
	require.NoError(t, err)
	require.Empty(t, entries)
	entries, err = os.ReadDir(filepath.Join(dir, tmpDir))
	require.NoError(t, err)
	require.Empty(t, entries, "no temp files left behind")
}

func TestLocalHandlerRejectsTraversal(t *testing.T) {
	l, dir := newTestLocalStore(t, "https://api.example.test")
	router := chi.NewRouter()
	router.Route("/api/v1", func(r chi.Router) { l.RegisterRoutes(r) })
	require.NoError(t, os.WriteFile(filepath.Join(dir, "secret.txt"), []byte("nope"), 0o600))

	for _, p := range []string{
		"/api/v1/files/..%2Fsecret.txt",
		"/api/v1/files/%2E%2E/secret.txt",
		"/api/v1/files/groups/%2E%2E/%2E%2E/secret.txt",
		"/api/v1/files/%2Fetc%2Fpasswd",
		"/api/v1/files/groups%5C..%5Csecret.txt",
	} {
		for _, method := range []string{http.MethodGet, http.MethodPut} {
			req := httptest.NewRequest(method, p+"?exp=9999999999&len=4&ct=text/plain&sig="+strings.Repeat("0", 64), strings.NewReader("evil"))
			rec := httptest.NewRecorder()
			router.ServeHTTP(rec, req)
			require.Equal(t, http.StatusBadRequest, rec.Code, "%s %s", method, p)
		}
	}
	got, err := os.ReadFile(filepath.Join(dir, "secret.txt"))
	require.NoError(t, err)
	require.Equal(t, "nope", string(got))
}

func TestNewSelectsBackend(t *testing.T) {
	t.Run("local when no bucket", func(t *testing.T) {
		svc := New(&config.Config{
			SecretKey:        testSecret,
			StorageLocalPath: t.TempDir(),
			PublicAPIURL:     "https://api.example.test",
			APIPrefix:        "/api",
		})
		require.NotNil(t, svc.Local())
		defer svc.Local().root.Close()
		require.True(t, strings.HasPrefix(svc.GetUploadURL(testKey, "image/png", 3, time.Minute), "https://api.example.test/api/v1/files/groups/"))
		require.NoError(t, svc.Upload(testKey, []byte("abc"), "image/png"))
		size, err := svc.HeadObjectSize(context.Background(), testKey)
		require.NoError(t, err)
		require.EqualValues(t, 3, size)
	})

	t.Run("local without public URL fails uploads gracefully", func(t *testing.T) {
		svc := New(&config.Config{SecretKey: testSecret, StorageLocalPath: t.TempDir(), APIPrefix: "/api"})
		require.NotNil(t, svc.Local())
		defer svc.Local().root.Close()
		require.Empty(t, svc.GetUploadURL(testKey, "image/png", 3, time.Minute))
		require.Empty(t, svc.GetURL(testKey))
	})

	t.Run("S3 wins over local", func(t *testing.T) {
		svc := New(&config.Config{
			SecretKey:          testSecret,
			StorageLocalPath:   t.TempDir(),
			PublicAPIURL:       "https://api.example.test",
			AWSAccessKeyID:     "test-access",
			AWSSecretAccessKey: "test-secret",
			AWSRegion:          "us-east-1",
			S3BucketName:       "test-bucket",
			S3EndpointURL:      "https://example.com",
		})
		require.Nil(t, svc.Local())
		require.True(t, strings.HasPrefix(svc.GetUploadURL("a/b.txt", "text/plain", 3, time.Minute), "https://example.com/test-bucket/a/b.txt?"))
	})

	t.Run("unconfigured", func(t *testing.T) {
		svc := New(&config.Config{})
		require.Nil(t, svc.Local())
		require.Empty(t, svc.GetUploadURL(testKey, "image/png", 3, time.Minute))
		require.Empty(t, svc.GetURL(testKey))
		require.Error(t, svc.Upload(testKey, []byte("abc"), "image/png"))
		require.Error(t, svc.Delete(testKey))
	})
}

func doRequest(t *testing.T, method, rawURL string, body []byte, contentType string) *http.Response {
	t.Helper()
	var rd io.Reader
	if body != nil {
		rd = bytes.NewReader(body)
	}
	req, err := http.NewRequest(method, rawURL, rd)
	require.NoError(t, err)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	t.Cleanup(func() { _ = resp.Body.Close() })
	return resp
}

func cloneQuery(q url.Values) url.Values {
	out := url.Values{}
	for k, v := range q {
		out[k] = append([]string(nil), v...)
	}
	return out
}

// Keys whose path escaping differs from Go's default encoding (";" and ","
// are escaped by PathEscape but not by URL.EscapedPath) make the request carry
// a RawPath, and chi then routes on the escaped form. Both forms must resolve
// to the same key.
func TestLocalHandlerKeyEscapingForms(t *testing.T) {
	router := chi.NewRouter()
	srv := httptest.NewServer(router)
	defer srv.Close()
	l, _ := newTestLocalStore(t, srv.URL)
	router.Route("/api/v1", func(r chi.Router) { l.RegisterRoutes(r) })

	for _, key := range []string{
		"groups/g/attachments/a/plain.png",
		"groups/g/attachments/a/semi;colon,comma+plus=eq@at:colon $&'().png",
		"groups/g/attachments/a/100%25 literal.png",
	} {
		payload := []byte("data for " + key)
		resp := doRequest(t, http.MethodPut, l.GetUploadURL(key, "image/png", int64(len(payload)), time.Minute), payload, "image/png")
		require.Equal(t, http.StatusOK, resp.StatusCode, key)
		got, err := l.Download(context.Background(), key)
		require.NoError(t, err, key)
		require.Equal(t, payload, got, key)
		resp = doRequest(t, http.MethodGet, l.GetURL(key), nil, "")
		require.Equal(t, http.StatusOK, resp.StatusCode, key)
		body, _ := io.ReadAll(resp.Body)
		require.Equal(t, payload, body, key)
	}
}
