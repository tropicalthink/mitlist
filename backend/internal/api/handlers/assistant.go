package handlers

import (
	"fmt"
	"io"
	"net/http"
	"strings"

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

// RegisterRoutes mounts assistant routes.
func (h *AssistantHandler) RegisterRoutes(r chi.Router) {
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
		api.RespondError(w, &api.ValidationError{Field: "file", Message: "file too large or invalid multipart form"})
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		api.RespondError(w, &api.ValidationError{Field: "file", Message: "file is required"})
		return
	}
	defer file.Close()

	imageBytes, err := io.ReadAll(file)
	if err != nil {
		api.RespondError(w, fmt.Errorf("read uploaded file: %w", err))
		return
	}

	mimeType, ok := allowedScanMimeType(imageBytes, header.Header.Get("Content-Type"))
	if !ok {
		api.RespondError(w, &api.ValidationError{Field: "file", Message: "file must be a supported image"})
		return
	}

	result, err := h.service.ScanImage(r.Context(), imageBytes, mimeType)
	if err != nil {
		api.RespondError(w, err)
		return
	}

	api.RespondJSON(w, http.StatusOK, result)
}

func allowedScanMimeType(data []byte, declared string) (string, bool) {
	detected := http.DetectContentType(data)
	if isAllowedScanImageType(detected) {
		return detected, true
	}

	// Some mobile formats are detected as application/octet-stream by the
	// standard library. Only trust the declared type for those narrow cases.
	declared = strings.ToLower(strings.TrimSpace(strings.Split(declared, ";")[0]))
	switch declared {
	case "image/heic", "image/heif":
		if detected == "application/octet-stream" {
			return declared, true
		}
	}

	return "", false
}

func isAllowedScanImageType(mimeType string) bool {
	switch strings.ToLower(strings.TrimSpace(mimeType)) {
	case "image/jpeg", "image/png", "image/webp", "image/gif":
		return true
	default:
		return false
	}
}
