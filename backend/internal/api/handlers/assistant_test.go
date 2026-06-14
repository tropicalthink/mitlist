package handlers

import "testing"

func TestAllowedScanMimeTypeAcceptsSniffedImages(t *testing.T) {
	png := []byte{
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
		0x00, 0x00, 0x00, 0x0d,
	}

	got, ok := allowedScanMimeType(png, "text/plain")
	if !ok {
		t.Fatal("expected PNG bytes to be accepted")
	}
	if got != "image/png" {
		t.Fatalf("mime type = %q, want image/png", got)
	}
}

func TestAllowedScanMimeTypeRejectsSpoofedImageContentType(t *testing.T) {
	payload := []byte("not an image")

	if got, ok := allowedScanMimeType(payload, "image/jpeg"); ok {
		t.Fatalf("expected spoofed image upload to be rejected, got %q", got)
	}
}

func TestAllowedScanMimeTypeAllowsDeclaredHEICWhenOpaque(t *testing.T) {
	opaque := []byte{0x00, 0x01, 0x02, 0x03}

	got, ok := allowedScanMimeType(opaque, "image/heic; charset=binary")
	if !ok {
		t.Fatal("expected declared HEIC upload to be accepted")
	}
	if got != "image/heic" {
		t.Fatalf("mime type = %q, want image/heic", got)
	}
}
