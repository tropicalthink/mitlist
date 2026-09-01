package image

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"os/exec"
	"testing"

	_ "golang.org/x/image/webp"
)

// testJPEG renders a noisy gradient so the JPEG has realistic entropy; a flat
// fill would compress to almost nothing and hide size regressions.
func testJPEG(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			img.Set(x, y, color.RGBA{
				R: uint8(x * 255 / w),
				G: uint8(y * 255 / h),
				B: uint8((x*7 + y*13) % 256),
				A: 255,
			})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 92}); err != nil {
		t.Fatalf("encode test jpeg: %v", err)
	}
	return buf.Bytes()
}

func TestCompressToWebPShrinksAndDownscales(t *testing.T) {
	if _, err := exec.LookPath("cwebp"); err != nil {
		t.Skip("cwebp not installed")
	}
	src := testJPEG(t, 3000, 2000)

	out, err := New().CompressToWebP(src, 2048, 75)
	if err != nil {
		t.Fatalf("CompressToWebP: %v", err)
	}
	if len(out) >= len(src) {
		t.Fatalf("expected smaller output, got %d -> %d bytes", len(src), len(out))
	}

	cfg, format, err := image.DecodeConfig(bytes.NewReader(out))
	if err != nil {
		t.Fatalf("decode output config: %v", err)
	}
	if format != "webp" {
		t.Fatalf("expected webp output, got %q", format)
	}
	if cfg.Width != 2048 {
		t.Fatalf("expected width capped at 2048, got %dx%d", cfg.Width, cfg.Height)
	}
}

func TestCompressToWebPRejectsNonImage(t *testing.T) {
	if _, err := New().CompressToWebP([]byte("definitely not an image"), 2048, 75); err == nil {
		t.Fatal("expected an error for non-image bytes")
	}
}
