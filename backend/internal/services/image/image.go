package image

import (
	"bytes"
	"fmt"
	"image"
	"image/png"
	"io"
	"os"
	"os/exec"

	"golang.org/x/image/draw"
)

// Service provides image processing operations.
type Service struct{}

// New creates a new image processing service.
func New() *Service {
	return &Service{}
}

// Resize decodes an image, scales it down if wider than maxWidth while preserving
// aspect ratio, and returns the encoded PNG bytes.
func (s *Service) Resize(file io.Reader, maxWidth int) ([]byte, error) {
	if maxWidth <= 0 {
		return nil, fmt.Errorf("maxWidth must be positive")
	}

	src, _, err := image.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("decode image: %w", err)
	}

	bounds := src.Bounds()
	srcW := bounds.Dx()
	srcH := bounds.Dy()

	if srcW <= maxWidth {
		var buf bytes.Buffer
		if err := png.Encode(&buf, src); err != nil {
			return nil, fmt.Errorf("encode png: %w", err)
		}
		return buf.Bytes(), nil
	}

	dstW := maxWidth
	dstH := srcH * maxWidth / srcW

	dst := image.NewRGBA(image.Rect(0, 0, dstW, dstH))
	draw.CatmullRom.Scale(dst, dst.Bounds(), src, bounds, draw.Over, nil)

	var buf bytes.Buffer
	if err := png.Encode(&buf, dst); err != nil {
		return nil, fmt.Errorf("encode png: %w", err)
	}
	return buf.Bytes(), nil
}

// ConvertToWebP decodes an image and encodes it as WebP with the given quality.
// It shells out to the cwebp binary; if cwebp is not available an error is returned.
func (s *Service) ConvertToWebP(file io.Reader, quality int) ([]byte, error) {
	if quality < 1 || quality > 100 {
		quality = 85
	}

	// Write input to a temporary file.
	inFile, err := os.CreateTemp("", "mitlist-img-*")
	if err != nil {
		return nil, fmt.Errorf("create temp input file: %w", err)
	}
	inName := inFile.Name()
	if _, err := io.Copy(inFile, file); err != nil {
		inFile.Close()
		os.Remove(inName)
		return nil, fmt.Errorf("write temp input file: %w", err)
	}
	inFile.Close()
	defer os.Remove(inName)

	outFile, err := os.CreateTemp("", "mitlist-img-*.webp")
	if err != nil {
		return nil, fmt.Errorf("create temp output file: %w", err)
	}
	outName := outFile.Name()
	outFile.Close()
	defer os.Remove(outName)

	cmd := exec.Command("cwebp", "-q", fmt.Sprintf("%d", quality), inName, "-o", outName)
	if out, err := cmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("cwebp failed: %w (output: %s)", err, string(out))
	}

	data, err := os.ReadFile(outName)
	if err != nil {
		return nil, fmt.Errorf("read webp output: %w", err)
	}
	return data, nil
}
