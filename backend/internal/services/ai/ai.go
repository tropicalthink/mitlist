package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/mitlist-app/mitlist/internal/config"
)

const (
	geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta"
	timeout       = 30 * time.Second
	maxRetries    = 3
)

var (
	// ErrGenerationFailed is returned when the AI response cannot be parsed.
	ErrGenerationFailed = errors.New("ai generation failed")
)

// Client provides access to the Google Gemini REST API.
type Client struct {
	cfg        *config.Config
	httpClient *http.Client
}

// New creates a new Gemini AI client.
func New(cfg *config.Config) *Client {
	return &Client{
		cfg: cfg,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

// Generate sends a prompt to the specified model and returns the generated text.
func (c *Client) Generate(prompt string, model string) (string, error) {
	reqBody := map[string]any{
		"contents": []map[string]any{
			{
				"parts": []map[string]any{
					{"text": prompt},
				},
			},
		},
	}

	respBody, err := c.doRequest(model, reqBody)
	if err != nil {
		return "", err
	}

	text, err := extractText(respBody)
	if err != nil {
		return "", err
	}

	return text, nil
}

// GenerateStructured sends a prompt with a JSON schema and returns the parsed JSON response.
func (c *Client) GenerateStructured(prompt string, model string, schema map[string]any) (map[string]any, error) {
	reqBody := map[string]any{
		"contents": []map[string]any{
			{
				"parts": []map[string]any{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]any{
			"responseMimeType": "application/json",
			"responseSchema":   schema,
		},
	}

	respBody, err := c.doRequest(model, reqBody)
	if err != nil {
		return nil, err
	}

	text, err := extractText(respBody)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		return nil, fmt.Errorf("unmarshal structured response: %w", err)
	}

	return result, nil
}

func (c *Client) doRequest(model string, reqBody map[string]any) (map[string]any, error) {
	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", geminiBaseURL, model, c.cfg.GeminiAPIKey)

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	var lastErr error
	for attempt := 0; attempt < maxRetries; attempt++ {
		if attempt > 0 {
			backoff := time.Duration(1<<attempt) * time.Second
			time.Sleep(backoff)
		}

		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
		if err != nil {
			cancel()
			return nil, fmt.Errorf("create request: %w", err)
		}
		req.Header.Set("Content-Type", "application/json")

		resp, err := c.httpClient.Do(req)
		cancel()
		if err != nil {
			lastErr = err
			continue
		}

		respData, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = fmt.Errorf("read response body: %w", err)
			continue
		}

		if resp.StatusCode >= 500 {
			lastErr = fmt.Errorf("server error %d: %s", resp.StatusCode, string(respData))
			continue
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("gemini API error %d: %s", resp.StatusCode, string(respData))
		}

		var result map[string]any
		if err := json.Unmarshal(respData, &result); err != nil {
			return nil, fmt.Errorf("unmarshal response: %w", err)
		}

		return result, nil
	}

	return nil, fmt.Errorf("gemini request failed after %d attempts: %w", maxRetries, lastErr)
}

func extractText(respBody map[string]any) (string, error) {
	candidates, ok := respBody["candidates"].([]any)
	if !ok || len(candidates) == 0 {
		return "", fmt.Errorf("%w: no candidates in response", ErrGenerationFailed)
	}

	first, ok := candidates[0].(map[string]any)
	if !ok {
		return "", fmt.Errorf("%w: invalid candidate format", ErrGenerationFailed)
	}

	content, ok := first["content"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("%w: missing content in candidate", ErrGenerationFailed)
	}

	parts, ok := content["parts"].([]any)
	if !ok || len(parts) == 0 {
		return "", fmt.Errorf("%w: no parts in content", ErrGenerationFailed)
	}

	part, ok := parts[0].(map[string]any)
	if !ok {
		return "", fmt.Errorf("%w: invalid part format", ErrGenerationFailed)
	}

	text, ok := part["text"].(string)
	if !ok {
		return "", fmt.Errorf("%w: missing text in part", ErrGenerationFailed)
	}

	return text, nil
}
