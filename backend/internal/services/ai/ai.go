package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/mitlist-app/mitlist/internal/config"
)

const (
	timeout    = 60 * time.Second
	maxRetries = 3
)

var (
	ErrGenerationFailed = errors.New("ai generation failed")
)

// Client provides access to the CrofAI OpenAI-compatible API.
type Client struct {
	cfg        *config.Config
	httpClient *http.Client
}

// New creates a new AI client for CrofAI.
func New(cfg *config.Config) *Client {
	return &Client{
		cfg: cfg,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}
}

// GenerateImage sends an image + prompt to the vision model and returns structured JSON.
func (c *Client) GenerateImage(imageBytes []byte, mimeType string, prompt string, model string, schema map[string]any) (map[string]any, error) {
	encoded := base64.StdEncoding.EncodeToString(imageBytes)
	dataURL := fmt.Sprintf("data:%s;base64,%s", mimeType, encoded)

	schemaName := "scan_result"
	if name, ok := schema["name"].(string); ok {
		schemaName = name
	}

	reqBody := map[string]any{
		"model": model,
		"messages": []map[string]any{
			{
				"role": "user",
				"content": []map[string]any{
					{"type": "text", "text": prompt},
					{
						"type": "image_url",
						"image_url": map[string]any{
							"url": dataURL,
						},
					},
				},
			},
		},
		"response_format": map[string]any{
			"type": "json_schema",
			"json_schema": map[string]any{
				"name":   schemaName,
				"strict": true,
				"schema": schema,
			},
		},
	}

	respBody, err := c.doRequest(reqBody)
	if err != nil {
		return nil, err
	}

	text, err := extractContent(respBody)
	if err != nil {
		return nil, err
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(text), &result); err != nil {
		return nil, fmt.Errorf("unmarshal structured response: %w", err)
	}

	return result, nil
}

func (c *Client) doRequest(reqBody map[string]any) (map[string]any, error) {
	baseURL := c.cfg.CrofAIBaseURL
	if baseURL == "" {
		baseURL = "https://crof.ai/v1"
	}
	url := baseURL + "/chat/completions"

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
		req.Header.Set("Authorization", "Bearer "+c.cfg.CrofAIAPIKey)

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
			return nil, fmt.Errorf("crofai API error %d: %s", resp.StatusCode, string(respData))
		}

		var result map[string]any
		if err := json.Unmarshal(respData, &result); err != nil {
			return nil, fmt.Errorf("unmarshal response: %w", err)
		}

		return result, nil
	}

	return nil, fmt.Errorf("crofai request failed after %d attempts: %w", maxRetries, lastErr)
}

func extractContent(respBody map[string]any) (string, error) {
	choices, ok := respBody["choices"].([]any)
	if !ok || len(choices) == 0 {
		return "", fmt.Errorf("%w: no choices in response", ErrGenerationFailed)
	}

	first, ok := choices[0].(map[string]any)
	if !ok {
		return "", fmt.Errorf("%w: invalid choice format", ErrGenerationFailed)
	}

	message, ok := first["message"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("%w: missing message in choice", ErrGenerationFailed)
	}

	content, ok := message["content"].(string)
	if !ok || content == "" {
		return "", fmt.Errorf("%w: empty content in message", ErrGenerationFailed)
	}

	return content, nil
}
