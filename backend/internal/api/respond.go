package api

import (
	"encoding/json"
	"net/http"
)

// RespondJSON writes a JSON response with the given status code.
func RespondJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if data != nil {
		_ = json.NewEncoder(w).Encode(data)
	}
}

// RespondError maps domain errors to HTTP status codes and writes a JSON error response.
func RespondError(w http.ResponseWriter, err error) {
	WriteError(w, err)
}
