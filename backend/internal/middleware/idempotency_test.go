package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type memoryIdempotencyDB struct {
	mu      sync.Mutex
	records map[string]idempotencyRecord
}

func (d *memoryIdempotencyDB) Exec(_ context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if strings.Contains(sql, "WHERE expires_at < NOW()") {
		return pgconn.NewCommandTag("DELETE 0"), nil
	}
	key := args[0].(uuid.UUID).String() + ":" + args[1].(string)
	switch {
	case strings.Contains(sql, "INSERT INTO request_idempotency"):
		if _, exists := d.records[key]; exists {
			return pgconn.NewCommandTag("UPDATE 0"), nil
		}
		d.records[key] = idempotencyRecord{requestHash: args[2].(string), state: "processing"}
		return pgconn.NewCommandTag("INSERT 0 1"), nil
	case strings.Contains(sql, "SET state = 'completed'"):
		record := d.records[key]
		record.state = "completed"
		record.status = args[2].(int)
		record.contentType = args[3].(string)
		record.body = append([]byte(nil), args[4].([]byte)...)
		d.records[key] = record
		return pgconn.NewCommandTag("UPDATE 1"), nil
	case strings.Contains(sql, "DELETE FROM request_idempotency"):
		delete(d.records, key)
		return pgconn.NewCommandTag("DELETE 1"), nil
	default:
		return pgconn.CommandTag{}, errors.New("unexpected query")
	}
}

func (d *memoryIdempotencyDB) QueryRow(_ context.Context, _ string, args ...any) pgx.Row {
	d.mu.Lock()
	defer d.mu.Unlock()
	key := args[0].(uuid.UUID).String() + ":" + args[1].(string)
	record, ok := d.records[key]
	return idempotencyRow{record: record, ok: ok}
}

type idempotencyRow struct {
	record idempotencyRecord
	ok     bool
}

func (r idempotencyRow) Scan(dest ...any) error {
	if !r.ok {
		return pgx.ErrNoRows
	}
	*(dest[0].(*string)) = r.record.requestHash
	*(dest[1].(*string)) = r.record.state
	*(dest[2].(*int)) = r.record.status
	*(dest[3].(*string)) = r.record.contentType
	*(dest[4].(*[]byte)) = append([]byte(nil), r.record.body...)
	return nil
}

func TestIdempotency_ReplaysCompletedMutation(t *testing.T) {
	db := &memoryIdempotencyDB{records: make(map[string]idempotencyRecord)}
	calls := 0
	handler := Idempotency(db)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"id":"one"}`))
	}))
	userID := uuid.New().String()

	request := func(body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/api/v1/expenses", strings.NewReader(body))
		req = req.WithContext(WithUserID(req.Context(), userID))
		req.Header.Set("Idempotency-Key", "create-expense:one")
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, req)
		return response
	}

	first := request(`{"amount":100}`)
	second := request(`{"amount":100}`)
	require.Equal(t, http.StatusCreated, first.Code)
	require.Equal(t, first.Body.String(), second.Body.String())
	assert.Equal(t, "true", second.Header().Get("Idempotency-Replayed"))
	assert.Equal(t, 1, calls)

	mismatch := request(`{"amount":200}`)
	assert.Equal(t, http.StatusConflict, mismatch.Code)
	assert.Equal(t, 1, calls)
}
