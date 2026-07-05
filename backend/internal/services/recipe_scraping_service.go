package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/net/html/charset"

	"github.com/mitlist-app/mitlist/internal/security"
)

const (
	maxRecipeResponseBytes = 5 * 1024 * 1024
	maxEmbeddedJSONBytes   = 2 * 1024 * 1024
	maxJSONLDDepth         = 12
)

type RecipeClipIngredient struct {
	RawText         string  `json:"raw_text"`
	Name            string  `json:"name"`
	Quantity        float64 `json:"quantity"`
	Unit            string  `json:"unit"`
	CanonicalItemID *string `json:"canonical_item_id,omitempty"`
}

type RecipeClipResponse struct {
	Title           string                 `json:"title"`
	SourceURL       string                 `json:"source_url"`
	Description     string                 `json:"description,omitempty"`
	Author          string                 `json:"author,omitempty"`
	RatingValue     float64                `json:"rating_value,omitempty"`
	RatingCount     int                    `json:"rating_count,omitempty"`
	Nutrition       map[string]string      `json:"nutrition,omitempty"`
	VideoURL        string                 `json:"video_url,omitempty"`
	Equipment       []string               `json:"equipment,omitempty"`
	InstructionsMD  string                 `json:"instructions_md"`
	PrepTimeMinutes *int                   `json:"prep_time_minutes,omitempty"`
	CookTimeMinutes *int                   `json:"cook_time_minutes,omitempty"`
	Servings        *string                `json:"servings,omitempty"`
	Ingredients     []RecipeClipIngredient `json:"ingredients,omitempty"`
	ImageURL        *string                `json:"image_url,omitempty"`
	ImageOptions    []string               `json:"image_options,omitempty"`
	Tags            []string               `json:"tags,omitempty"`
}

// RecipeScrapingService scrapes a URL into a "clip" payload suitable for prefill.
//
// It uses a multi-tier strategy:
//  1. JSON-LD (schema.org, deep-recursive across all scripts)
//  2. Microdata
//  3. RDFa
//  4. Embedded JSON app state (__NEXT_DATA__ and other application/json blobs)
//  5. Heuristics (recipe-plugin selectors, then generic class hints, then scoring)
//
// Fetching retries through a user-agent ladder when blocked, decodes non-UTF-8
// charsets, and falls back to the page's AMP variant when the result is weak.
// Each tier is validated by a quality gate: ingredients or instructions must exist.
type RecipeScrapingService struct {
	client *http.Client

	// flareSolverURL, when set (env SCRAPER_FLARESOLVER_URL, e.g.
	// http://flaresolverr:8191), is a FlareSolverr endpoint used as a last-resort
	// fallback when a host's bot protection (typically Cloudflare) blocks the
	// direct fetch regardless of user-agent. FlareSolverr drives a real headless
	// browser that solves the challenge and returns the rendered HTML.
	flareSolverURL string
}

func NewRecipeScrapingService() *RecipeScrapingService {
	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
	}
	return &RecipeScrapingService{
		client: &http.Client{
			Timeout:   15 * time.Second,
			Transport: transport,
		},
		flareSolverURL: strings.TrimSpace(os.Getenv("SCRAPER_FLARESOLVER_URL")),
	}
}

func (s *RecipeScrapingService) ScrapeRecipe(ctx context.Context, rawURL string) (*RecipeClipResponse, error) {
	validated, err := security.ValidateAndResolveURL(ctx, rawURL)
	if err != nil {
		return nil, fmt.Errorf("url not allowed: %w", err)
	}

	html, finalURL, err := s.fetchHTML(ctx, validated)
	if err != nil {
		return nil, err
	}

	result, scrapeErr := s.scrapeHTML(html, finalURL)

	// AMP fallback: AMP variants are usually server-rendered and carry clean
	// structured data, which rescues JS-rendered pages.
	if scrapeErr != nil || isWeakResult(result) {
		if amp := s.scrapeAMPVariant(ctx, html, finalURL); amp != nil {
			if scrapeErr != nil || completenessScore(*amp) > completenessScore(*result) {
				amp.SourceURL = finalURL
				return amp, nil
			}
		}
	}

	return result, scrapeErr
}

func isWeakResult(r *RecipeClipResponse) bool {
	if r == nil {
		return true
	}
	return len(r.Ingredients) == 0 || strings.TrimSpace(r.InstructionsMD) == ""
}

func (s *RecipeScrapingService) scrapeAMPVariant(ctx context.Context, html, finalURL string) *RecipeClipResponse {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil
	}
	href, ok := doc.Find(`link[rel="amphtml"]`).Attr("href")
	if !ok || strings.TrimSpace(href) == "" {
		return nil
	}
	ampURL := resolveURL(finalURL, href)
	if ampURL == finalURL {
		return nil
	}
	validated, err := security.ValidateAndResolveURL(ctx, ampURL)
	if err != nil {
		return nil
	}
	ampHTML, ampFinal, err := s.fetchHTML(ctx, validated)
	if err != nil {
		return nil
	}
	r, err := s.scrapeHTML(ampHTML, ampFinal)
	if err != nil {
		return nil
	}
	return r
}

// scrapeHTML parses raw HTML into a recipe clip. Used internally and in tests.
func (s *RecipeScrapingService) scrapeHTML(html, finalURL string) (*RecipeClipResponse, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil, fmt.Errorf("failed to parse html")
	}

	results := make([]tierResult, 0, 6)

	for _, r := range (jsonLDParser{}).parse(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "json-ld", R: r})
		}
	}
	for _, r := range (microdataParser{}).parse(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "microdata", R: r})
		}
	}
	for _, r := range (rdfaParser{}).parse(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "rdfa", R: r})
		}
	}
	for _, r := range (embeddedJSONParser{}).parse(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "embedded-json", R: r})
		}
	}

	// Always run heuristic fallback to fill gaps.
	for _, r := range (heuristicParser{}).parse(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "heuristic", R: r})
		}
	}

	if len(results) == 0 {
		return nil, fmt.Errorf("could not extract recipe data from this url")
	}

	merged := mergeTierResults(results)
	return &merged, nil
}

// ------------------------------------------------------------------
// Fetching (SSRF-safe + size cap + redirect validation + UA ladder)
// ------------------------------------------------------------------

// scraperUserAgents is the retry ladder used when a host blocks the default
// browser identity. Many recipe sites whitelist search-engine crawlers, so
// Googlebot is the last resort.
var scraperUserAgents = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
	"Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
}

func retryableStatus(code int) bool {
	switch code {
	case http.StatusForbidden,
		http.StatusNotAcceptable,
		http.StatusPreconditionFailed,
		http.StatusTooManyRequests,
		http.StatusInternalServerError,
		http.StatusBadGateway,
		http.StatusServiceUnavailable:
		return true
	}
	return false
}

func (s *RecipeScrapingService) fetchHTML(ctx context.Context, validated *security.ValidatedURL) (string, string, error) {
	var lastErr error
	for attempt, ua := range scraperUserAgents {
		if attempt > 0 {
			select {
			case <-ctx.Done():
				return "", "", ctx.Err()
			case <-time.After(time.Duration(attempt) * 300 * time.Millisecond):
			}
		}
		body, finalURL, retry, err := s.fetchOnce(ctx, validated, ua)
		if err == nil {
			return body, finalURL, nil
		}
		lastErr = err
		if !retry {
			break
		}
	}

	// Last resort: route through FlareSolverr (headless browser) to clear
	// Cloudflare-style challenges that block our direct fetch by IP/fingerprint.
	if s.flareSolverURL != "" {
		if _, err := security.ValidateAndResolveURL(ctx, validated.URL.String()); err != nil {
			lastErr = fmt.Errorf("%v (flaresolverr target revalidation: %v)", lastErr, err)
			return "", "", lastErr
		}
		if body, finalURL, ferr := s.fetchViaFlareSolverr(ctx, validated.URL.String()); ferr == nil {
			return body, finalURL, nil
		} else {
			lastErr = fmt.Errorf("%v (flaresolverr fallback: %v)", lastErr, ferr)
		}
	}

	return "", "", lastErr
}

type flareSolverrResponse struct {
	Status   string `json:"status"`
	Message  string `json:"message"`
	Solution struct {
		URL      string `json:"url"`
		Status   int    `json:"status"`
		Response string `json:"response"`
	} `json:"solution"`
}

// fetchViaFlareSolverr proxies the fetch through a FlareSolverr instance, which
// uses a real browser to solve JS/Cloudflare challenges and returns the
// rendered HTML. targetURL must already be SSRF-validated by the caller.
func (s *RecipeScrapingService) fetchViaFlareSolverr(ctx context.Context, targetURL string) (body, finalURL string, err error) {
	// Challenge solving is slow; give it its own bounded deadline.
	ctx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()

	payload, _ := json.Marshal(map[string]any{
		"cmd":        "request.get",
		"url":        targetURL,
		"maxTimeout": 60000,
	})
	endpoint := strings.TrimRight(s.flareSolverURL, "/") + "/v1"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(payload))
	if err != nil {
		return "", "", fmt.Errorf("invalid flaresolverr request")
	}
	req.Header.Set("Content-Type", "application/json")

	// Dedicated client: the shared one's 15s timeout is too short for challenge
	// solving, and we must not pin to the target host (we talk to FlareSolverr).
	client := &http.Client{Timeout: 95 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("flaresolverr unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("flaresolverr http %d", resp.StatusCode)
	}

	raw, err := readUpTo(resp.Body, maxRecipeResponseBytes*2)
	if err != nil {
		return "", "", err
	}

	var fr flareSolverrResponse
	if jerr := json.Unmarshal(raw, &fr); jerr != nil {
		return "", "", fmt.Errorf("invalid flaresolverr response")
	}
	if fr.Status != "ok" {
		return "", "", fmt.Errorf("flaresolverr: %s", fr.Message)
	}
	if fr.Solution.Status >= http.StatusBadRequest {
		return "", "", fmt.Errorf("http %d", fr.Solution.Status)
	}
	if strings.TrimSpace(fr.Solution.Response) == "" {
		return "", "", fmt.Errorf("flaresolverr returned empty body")
	}

	final := fr.Solution.URL
	if strings.TrimSpace(final) == "" {
		final = targetURL
	}
	return fr.Solution.Response, final, nil
}

func (s *RecipeScrapingService) fetchOnce(ctx context.Context, validated *security.ValidatedURL, userAgent string) (body, finalURL string, retryable bool, err error) {
	current := validated
	var resp *http.Response
	for redirects := 0; ; redirects++ {
		pinned := security.NewPinnedTransport(current)
		client := *s.client
		if pinned != nil {
			client.Transport = pinned
		}
		client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		}

		req, err := http.NewRequestWithContext(ctx, http.MethodGet, current.URL.String(), nil)
		if err != nil {
			return "", "", false, fmt.Errorf("invalid request")
		}
		req.Header.Set("User-Agent", userAgent)
		req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8")
		req.Header.Set("Accept-Language", "en-US,en;q=0.9")
		req.Header.Set("Cache-Control", "no-cache")
		req.Header.Set("Sec-Fetch-Dest", "document")
		req.Header.Set("Sec-Fetch-Mode", "navigate")
		req.Header.Set("Sec-Fetch-Site", "none")
		req.Header.Set("Upgrade-Insecure-Requests", "1")

		resp, err = client.Do(req)
		if err != nil {
			return "", "", true, fmt.Errorf("failed to fetch page: %w", err)
		}
		if resp.StatusCode < 300 || resp.StatusCode >= 400 {
			break
		}
		if redirects >= 5 {
			break
		}
		nextURL, err := resp.Location()
		resp.Body.Close()
		if err != nil {
			return "", "", false, fmt.Errorf("invalid redirect")
		}
		current, err = security.ValidateAndResolveURL(ctx, nextURL.String())
		if err != nil {
			return "", "", false, err
		}
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", "", retryableStatus(resp.StatusCode), fmt.Errorf("http %d", resp.StatusCode)
	}

	ct := strings.ToLower(resp.Header.Get("Content-Type"))
	for _, blocked := range []string{"application/pdf", "application/octet-stream", "image/", "video/", "audio/"} {
		if strings.Contains(ct, blocked) {
			return "", "", false, fmt.Errorf("unsupported content type")
		}
	}

	raw, err := readUpTo(resp.Body, maxRecipeResponseBytes)
	if err != nil {
		return "", "", false, err
	}

	// Decode legacy charsets (ISO-8859-1, Shift_JIS, ...) into UTF-8 so the
	// HTML parser and downstream regexes see clean text.
	if utf8Reader, cerr := charset.NewReader(bytes.NewReader(raw), resp.Header.Get("Content-Type")); cerr == nil {
		if decoded, derr := io.ReadAll(utf8Reader); derr == nil && len(decoded) > 0 {
			raw = decoded
		}
	}

	if looksLikeBotWall(raw) {
		return "", "", true, fmt.Errorf("blocked by bot protection")
	}

	return string(raw), resp.Request.URL.String(), false, nil
}

var botWallRe = regexp.MustCompile(`(?i)(verify you are a human|are you a robot|enable javascript and cookies|attention required!?\s*\|\s*cloudflare|access denied|captcha)`)

// looksLikeBotWall detects challenge/interstitial pages so we retry with a
// different identity instead of "successfully" scraping a CAPTCHA page.
func looksLikeBotWall(body []byte) bool {
	if len(body) > 30*1024 {
		return false
	}
	return botWallRe.Match(body)
}

func readUpTo(r io.Reader, max int) ([]byte, error) {
	var buf bytes.Buffer
	if _, err := io.CopyN(&buf, r, int64(max)+1); err != nil && err != io.EOF {
		return nil, fmt.Errorf("failed to read response")
	}
	if buf.Len() > max {
		return nil, fmt.Errorf("response too large")
	}
	return buf.Bytes(), nil
}

// ------------------------------------------------------------------
// Tier merging and scoring
// ------------------------------------------------------------------

type tierResult struct {
	Name string
	R    RecipeClipResponse
}

func mergeTierResults(results []tierResult) RecipeClipResponse {
	sort.SliceStable(results, func(i, j int) bool {
		return completenessScore(results[i].R) > completenessScore(results[j].R)
	})

	base := results[0].R
	others := make([]RecipeClipResponse, 0, len(results)-1)
	for i := 1; i < len(results); i++ {
		others = append(others, results[i].R)
	}

	title := base.Title
	if title == "" || title == "Untitled Recipe" {
		title = ""
	}
	description := strings.TrimSpace(base.Description)
	author := strings.TrimSpace(base.Author)
	ratingValue := base.RatingValue
	ratingCount := base.RatingCount
	nutrition := base.Nutrition
	videoURL := strings.TrimSpace(base.VideoURL)
	equipment := append([]string(nil), base.Equipment...)
	instructions := strings.TrimSpace(base.InstructionsMD)
	ingredients := append([]RecipeClipIngredient(nil), base.Ingredients...)
	prep := base.PrepTimeMinutes
	cook := base.CookTimeMinutes
	servings := base.Servings
	imageURL := base.ImageURL
	imageOptions := append([]string(nil), base.ImageOptions...)
	tags := append([]string(nil), base.Tags...)

	for _, o := range others {
		if title == "" && o.Title != "" && o.Title != "Untitled Recipe" {
			title = o.Title
		}
		if description == "" && strings.TrimSpace(o.Description) != "" {
			description = strings.TrimSpace(o.Description)
		}
		if author == "" && strings.TrimSpace(o.Author) != "" {
			author = strings.TrimSpace(o.Author)
		}
		if ratingValue == 0 && o.RatingValue > 0 {
			ratingValue = o.RatingValue
		}
		if ratingCount == 0 && o.RatingCount > 0 {
			ratingCount = o.RatingCount
		}
		if len(nutrition) == 0 && len(o.Nutrition) > 0 {
			nutrition = make(map[string]string, len(o.Nutrition))
			for k, v := range o.Nutrition {
				nutrition[k] = v
			}
		}
		if videoURL == "" && strings.TrimSpace(o.VideoURL) != "" {
			videoURL = strings.TrimSpace(o.VideoURL)
		}
		if len(equipment) == 0 && len(o.Equipment) > 0 {
			equipment = append([]string(nil), o.Equipment...)
		}

		otherInstr := strings.TrimSpace(o.InstructionsMD)
		if instructions == "" && otherInstr != "" {
			instructions = otherInstr
		} else if otherInstr != "" && len(otherInstr) > len(instructions)*2 {
			instructions = otherInstr
		}

		if len(ingredients) == 0 && len(o.Ingredients) > 0 {
			ingredients = append([]RecipeClipIngredient(nil), o.Ingredients...)
		} else if len(o.Ingredients) >= len(ingredients)+3 {
			ingredients = append([]RecipeClipIngredient(nil), o.Ingredients...)
		}

		if prep == nil && o.PrepTimeMinutes != nil {
			prep = o.PrepTimeMinutes
		}
		if cook == nil && o.CookTimeMinutes != nil {
			cook = o.CookTimeMinutes
		}
		if servings == nil && o.Servings != nil {
			servings = o.Servings
		}
		if imageURL == nil && o.ImageURL != nil {
			imageURL = o.ImageURL
		}

		for _, img := range o.ImageOptions {
			if img == "" {
				continue
			}
			if !containsString(imageOptions, img) {
				imageOptions = append(imageOptions, img)
			}
		}
		for _, t := range o.Tags {
			if t == "" {
				continue
			}
			if !containsString(tags, t) {
				tags = append(tags, t)
			}
		}
	}

	if title == "" {
		title = "Untitled Recipe"
	}
	if len(imageOptions) > 10 {
		imageOptions = imageOptions[:10]
	}

	return RecipeClipResponse{
		Title:           title,
		SourceURL:       base.SourceURL,
		Description:     description,
		Author:          author,
		RatingValue:     ratingValue,
		RatingCount:     ratingCount,
		Nutrition:       nutrition,
		VideoURL:        videoURL,
		Equipment:       equipment,
		InstructionsMD:  instructions,
		PrepTimeMinutes: prep,
		CookTimeMinutes: cook,
		Servings:        servings,
		Ingredients:     ingredients,
		ImageURL:        imageURL,
		ImageOptions:    imageOptions,
		Tags:            tags,
	}
}

func completenessScore(r RecipeClipResponse) int {
	score := 0
	if r.Title != "" && r.Title != "Untitled Recipe" {
		score += 2
	}
	if len(r.Ingredients) > 0 {
		score += 5 + min(len(r.Ingredients), 15)
	}
	if strings.TrimSpace(r.InstructionsMD) != "" {
		score += 5 + min(len(strings.TrimSpace(r.InstructionsMD))/100, 10)
	}
	if r.PrepTimeMinutes != nil {
		score++
	}
	if r.CookTimeMinutes != nil {
		score++
	}
	if r.Servings != nil && strings.TrimSpace(*r.Servings) != "" {
		score++
	}
	if r.ImageURL != nil && strings.TrimSpace(*r.ImageURL) != "" {
		score += 2
	}
	if len(r.Tags) > 0 {
		score++
	}
	return score
}

func isUsable(r RecipeClipResponse) bool {
	return len(r.Ingredients) > 0 || strings.TrimSpace(r.InstructionsMD) != ""
}

func containsString(xs []string, v string) bool {
	for _, x := range xs {
		if x == v {
			return true
		}
	}
	return false
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func dedupeStrings(in []string) []string {
	seen := map[string]struct{}{}
	out := make([]string, 0, len(in))
	for _, s := range in {
		t := strings.TrimSpace(s)
		if t == "" {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		out = append(out, t)
	}
	return out
}
