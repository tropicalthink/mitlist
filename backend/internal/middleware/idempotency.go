package middleware

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const maxIdempotencyBodyBytes = 2 << 20

type idempotencyDB interface {
	Exec(ctx context.Context, sql string, arguments ...any) (pgconn.CommandTag, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type idempotencyRecord struct {
	requestHash string
	state       string
	status      int
	contentType string
	body        []byte
}

// Idempotency makes authenticated mutations replay-safe. Clients send a stable
// Idempotency-Key for an outbox operation; the first response is persisted and
// later attempts receive that exact result without executing the handler again.
func Idempotency(db idempotencyDB) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			key := strings.TrimSpace(r.Header.Get("Idempotency-Key"))
			if key == "" || !isMutation(r.Method) {
				next.ServeHTTP(w, r)
				return
			}
			if len(key) > 128 {
				http.Error(w, "invalid idempotency key", http.StatusBadRequest)
				return
			}
			userID, err := uuid.Parse(UserIDFromContext(r.Context()))
			if err != nil {
				http.Error(w, "authentication required", http.StatusUnauthorized)
				return
			}
			body, err := io.ReadAll(io.LimitReader(r.Body, maxIdempotencyBodyBytes+1))
			if err != nil || len(body) > maxIdempotencyBodyBytes {
				http.Error(w, "request body too large for idempotent replay", http.StatusRequestEntityTooLarge)
				return
			}
			r.Body = io.NopCloser(bytes.NewReader(body))
			digest := sha256.Sum256(append([]byte(r.Method+"\n"+r.URL.RequestURI()+"\n"), body...))
			requestHash := hex.EncodeToString(digest[:])

			claimed, err := claimIdempotency(r.Context(), db, userID, key, requestHash)
			if err != nil {
				http.Error(w, "unable to reserve idempotent request", http.StatusServiceUnavailable)
				return
			}
			if !claimed {
				replayIdempotency(w, r, db, userID, key, requestHash)
				return
			}

			recorder := newBufferedResponse()
			next.ServeHTTP(recorder, r)
			status := recorder.status
			if status == 0 {
				status = http.StatusOK
			}
			if status >= 500 {
				_, _ = db.Exec(r.Context(), `DELETE FROM request_idempotency WHERE user_id = $1 AND idempotency_key = $2`, userID, key)
			} else {
				_, err = db.Exec(r.Context(), `
					UPDATE request_idempotency
					SET state = 'completed', response_status = $3, response_content_type = $4,
					    response_body = $5, completed_at = NOW()
					WHERE user_id = $1 AND idempotency_key = $2
				`, userID, key, status, recorder.header.Get("Content-Type"), recorder.body.Bytes())
				if err != nil {
					http.Error(w, "request completed but replay state could not be persisted", http.StatusServiceUnavailable)
					return
				}
			}
			recorder.copyTo(w, status)
		})
	}
}

func claimIdempotency(ctx context.Context, db idempotencyDB, userID uuid.UUID, key, requestHash string) (bool, error) {
	// Keep the replay table bounded without another scheduler dependency. The
	// expiry index makes the common no-op cleanup cheap.
	_, _ = db.Exec(ctx, `DELETE FROM request_idempotency WHERE expires_at < NOW()`)
	tag, err := db.Exec(ctx, `
		INSERT INTO request_idempotency (user_id, idempotency_key, request_hash)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, idempotency_key) DO UPDATE SET
			request_hash = EXCLUDED.request_hash, state = 'processing', created_at = NOW(),
			response_status = NULL, response_content_type = NULL, response_body = NULL,
			completed_at = NULL, expires_at = NOW() + INTERVAL '7 days'
		WHERE request_idempotency.expires_at < NOW()
		   OR (request_idempotency.state = 'processing'
		       AND request_idempotency.created_at < NOW() - INTERVAL '5 minutes')
	`, userID, key, requestHash)
	return tag.RowsAffected() == 1, err
}

func replayIdempotency(w http.ResponseWriter, r *http.Request, db idempotencyDB, userID uuid.UUID, key, requestHash string) {
	var record idempotencyRecord
	err := db.QueryRow(r.Context(), `
		SELECT request_hash, state, COALESCE(response_status, 0),
		       COALESCE(response_content_type, ''), COALESCE(response_body, ''::bytea)
		FROM request_idempotency WHERE user_id = $1 AND idempotency_key = $2
	`, userID, key).Scan(&record.requestHash, &record.state, &record.status, &record.contentType, &record.body)
	if err != nil {
		http.Error(w, "unable to replay idempotent request", http.StatusServiceUnavailable)
		return
	}
	if record.requestHash != requestHash {
		http.Error(w, "idempotency key was already used for a different request", http.StatusConflict)
		return
	}
	if record.state != "completed" {
		w.Header().Set("Retry-After", "2")
		http.Error(w, "request with this idempotency key is still processing", http.StatusConflict)
		return
	}
	if record.contentType != "" {
		w.Header().Set("Content-Type", record.contentType)
	}
	w.Header().Set("Idempotency-Replayed", "true")
	w.WriteHeader(record.status)
	_, _ = w.Write(record.body)
}

func isMutation(method string) bool {
	switch method {
	case http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete:
		return true
	default:
		return false
	}
}

type bufferedResponse struct {
	header http.Header
	body   bytes.Buffer
	status int
}

func newBufferedResponse() *bufferedResponse    { return &bufferedResponse{header: make(http.Header)} }
func (r *bufferedResponse) Header() http.Header { return r.header }
func (r *bufferedResponse) WriteHeader(status int) {
	if r.status == 0 {
		r.status = status
	}
}
func (r *bufferedResponse) Write(body []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	return r.body.Write(body)
}
func (r *bufferedResponse) copyTo(w http.ResponseWriter, status int) {
	for key, values := range r.header {
		for _, value := range values {
			w.Header().Add(key, value)
		}
	}
	w.WriteHeader(status)
	_, _ = w.Write(r.body.Bytes())
}
