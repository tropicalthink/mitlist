package handlers

import (
	"fmt"
	"io"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/internal/api"
	"github.com/mitlist-app/mitlist/internal/services"
)

// AssistantHandler exposes the AI scanner endpoint.
type AssistantHandler struct {
	service *services.ScanService
}

// NewAssistantHandler creates a new AssistantHandler.
func NewAssistantHandler(service *services.ScanService) *AssistantHandler {
	return &AssistantHandler{service: service}
}

func (h *AssistantHandler) Routes(r chi.Router) {
	r.Post("/assistant/scan", h.ScanImage)
}

func (h *AssistantHandler) ScanImage(w http.ResponseWriter, r *http.Request) {
	userID := RequireUser(w, r)
	if userID == uuid.Nil {
		return
	}

	const maxUploadSize = 10 << 20 // 10 MB
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)

	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		respondError(w, &api.ValidationError{Field: "file", Message: "file too large or invalid multipart form"})
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		respondError(w, &api.ValidationError{Field: "file", Message: "file is required"})
		return
	}
	defer file.Close()

	imageBytes, err := io.ReadAll(file)
	if err != nil {
		respondError(w, fmt.Errorf("read uploaded file: %w", err))
		return
	}

	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = "image/jpeg"
	}

	result, err := h.service.ScanImage(r.Context(), imageBytes, mimeType)
	if err != nil {
		respondError(w, err)
		return
	}

	respondJSON(w, http.StatusOK, result)
}
