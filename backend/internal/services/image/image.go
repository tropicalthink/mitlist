package image

import (
	"bytes"
	"fmt"
	"image"
	_ "image/jpeg" // registered for image.Decode
	"image/png"
	"io"
	"os"
	"os/exec"

	"github.com/rwcarlsen/goexif/exif"
	"golang.org/x/image/draw"
	_ "golang.org/x/image/webp" // registered for image.Decode
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

// Decoding is bounded before any pixels are allocated: a small header can
// declare a multi-gigabyte bitmap, and this runs on user uploads.
const maxDecodePixels = 50_000_000

// CompressToWebP decodes an image (JPEG, PNG or WebP), applies any EXIF
// orientation, scales it down so neither side exceeds maxDim, and encodes it
// as lossy WebP via the cwebp binary (libwebp-tools). The EXIF step matters:
// phone JPEGs are usually stored unrotated with an orientation tag, WebP has
// no such tag, and viewers would otherwise show the photo sideways.
//
// Returns an error when cwebp is unavailable; callers treat compression as
// best-effort and keep the original upload.
func (s *Service) CompressToWebP(data []byte, maxDim, quality int) ([]byte, error) {
	if quality < 1 || quality > 100 {
		quality = 75
	}

	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("decode config: %w", err)
	}
	if cfg.Width <= 0 || cfg.Height <= 0 || cfg.Width*cfg.Height > maxDecodePixels {
		return nil, fmt.Errorf("image dimensions %dx%d out of bounds", cfg.Width, cfg.Height)
	}

	src, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, fmt.Errorf("decode image: %w", err)
	}

	src = applyEXIFOrientation(src, data)

	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	if maxDim > 0 && (w > maxDim || h > maxDim) {
		dw, dh := maxDim, h*maxDim/w
		if h > w {
			dw, dh = w*maxDim/h, maxDim
		}
		dst := image.NewRGBA(image.Rect(0, 0, max(dw, 1), max(dh, 1)))
		draw.CatmullRom.Scale(dst, dst.Bounds(), src, b, draw.Over, nil)
		src = dst
	}

	// PNG intermediate: lossless input to the encoder, and a format cwebp
	// always understands regardless of what was uploaded.
	inFile, err := os.CreateTemp("", "mitlist-img-*.png")
	if err != nil {
		return nil, fmt.Errorf("create temp input file: %w", err)
	}
	inName := inFile.Name()
	defer os.Remove(inName)
	if err := png.Encode(inFile, src); err != nil {
		inFile.Close()
		return nil, fmt.Errorf("encode intermediate png: %w", err)
	}
	inFile.Close()

	outFile, err := os.CreateTemp("", "mitlist-img-*.webp")
	if err != nil {
		return nil, fmt.Errorf("create temp output file: %w", err)
	}
	outName := outFile.Name()
	outFile.Close()
	defer os.Remove(outName)

	cmd := exec.Command("cwebp", "-quiet", "-metadata", "none",
		"-q", fmt.Sprintf("%d", quality), inName, "-o", outName)
	if out, err := cmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("cwebp failed: %w (output: %s)", err, string(out))
	}

	result, err := os.ReadFile(outName)
	if err != nil {
		return nil, fmt.Errorf("read webp output: %w", err)
	}
	return result, nil
}

// applyEXIFOrientation bakes the EXIF orientation tag into the pixels. Images
// without EXIF (or with the upright orientation) come back unchanged.
func applyEXIFOrientation(src image.Image, raw []byte) image.Image {
	x, err := exif.Decode(bytes.NewReader(raw))
	if err != nil {
		return src
	}
	tag, err := x.Get(exif.Orientation)
	if err != nil {
		return src
	}
	orientation, err := tag.Int(0)
	if err != nil {
		return src
	}

	switch orientation {
	case 2:
		return transform(src, func(w, h, x, y int) (int, int) { return w - 1 - x, y })
	case 3:
		return transform(src, func(w, h, x, y int) (int, int) { return w - 1 - x, h - 1 - y })
	case 4:
		return transform(src, func(w, h, x, y int) (int, int) { return x, h - 1 - y })
	case 5:
		return transformSwapped(src, func(w, h, x, y int) (int, int) { return y, x })
	case 6:
		return transformSwapped(src, func(w, h, x, y int) (int, int) { return y, h - 1 - x })
	case 7:
		return transformSwapped(src, func(w, h, x, y int) (int, int) { return w - 1 - y, h - 1 - x })
	case 8:
		return transformSwapped(src, func(w, h, x, y int) (int, int) { return w - 1 - y, x })
	default:
		return src
	}
}

// transform maps each destination pixel (x, y) to a source pixel via move,
// keeping the source dimensions. move receives the source width and height.
func transform(src image.Image, move func(w, h, x, y int) (int, int)) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	dst := image.NewRGBA(image.Rect(0, 0, w, h))
	for y := range h {
		for x := range w {
			sx, sy := move(w, h, x, y)
			dst.Set(x, y, src.At(b.Min.X+sx, b.Min.Y+sy))
		}
	}
	return dst
}

// transformSwapped is transform for the four orientations that exchange the
// axes: the destination is h×w and move maps destination (x, y) into the
// source's coordinate space.
func transformSwapped(src image.Image, move func(w, h, x, y int) (int, int)) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	dst := image.NewRGBA(image.Rect(0, 0, h, w))
	for y := range w {
		for x := range h {
			sx, sy := move(w, h, x, y)
			dst.Set(x, y, src.At(b.Min.X+sx, b.Min.Y+sy))
		}
	}
	return dst
}
