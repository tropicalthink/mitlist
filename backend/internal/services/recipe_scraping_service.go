package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
	"golang.org/x/net/html/charset"

	"github.com/mitlist-app/mitlist/internal/security"
	"github.com/mitlist-app/mitlist/pkg/parsing"
)

const (
	maxRecipeResponseBytes = 5 * 1024 * 1024
	maxEmbeddedJSONBytes   = 2 * 1024 * 1024
	maxJSONLDDepth         = 12
)

type RecipeClipIngredient struct {
	RawText  string  `json:"raw_text"`
	Name     string  `json:"name"`
	Quantity float64 `json:"quantity"`
	Unit     string  `json:"unit"`
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

	for _, r := range s.tryJSONLD(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "json-ld", R: r})
		}
	}
	if r, ok := s.tryMicrodata(doc, finalURL); ok && isUsable(r) {
		results = append(results, tierResult{Name: "microdata", R: r})
	}
	if r, ok := s.tryRDFa(doc, finalURL); ok && isUsable(r) {
		results = append(results, tierResult{Name: "rdfa", R: r})
	}
	for _, r := range s.tryEmbeddedJSON(doc, finalURL) {
		if isUsable(r) {
			results = append(results, tierResult{Name: "embedded-json", R: r})
		}
	}

	// Always run heuristic fallback to fill gaps.
	heur := s.extractHeuristic(doc, finalURL)
	if isUsable(heur) {
		results = append(results, tierResult{Name: "heuristic", R: heur})
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
	return "", "", lastErr
}

func (s *RecipeScrapingService) fetchOnce(ctx context.Context, validated *security.ValidatedURL, userAgent string) (body, finalURL string, retryable bool, err error) {
	pinned := security.NewPinnedTransport(validated)
	client := *s.client
	if pinned != nil {
		client.Transport = pinned
	}

	redirects := 0
	client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		redirects++
		if redirects > 5 {
			return http.ErrUseLastResponse
		}
		if _, err := security.ValidateURLForFetch(req.Context(), req.URL.String()); err != nil {
			return err
		}
		return nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, validated.URL.String(), nil)
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

	resp, err := client.Do(req)
	if err != nil {
		return "", "", true, fmt.Errorf("failed to fetch page: %w", err)
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

// ------------------------------------------------------------------
// Tier 1: JSON-LD extraction
// ------------------------------------------------------------------

var (
	cdataOpenRe  = regexp.MustCompile(`(?s)/?\*?\s*<!\[CDATA\[\s*\*?/?`)
	cdataCloseRe = regexp.MustCompile(`(?s)/?\*?\s*\]\]>\s*\*?/?`)
)

// sanitizeJSONLD repairs the breakage commonly found in real-world JSON-LD
// blocks: HTML comment wrappers, CDATA wrappers, and raw control characters
// (literal newlines/tabs inside string values are invalid JSON).
func sanitizeJSONLD(raw string) string {
	raw = strings.TrimSpace(raw)
	raw = strings.TrimPrefix(raw, "<!--")
	raw = strings.TrimSuffix(raw, "-->")
	raw = cdataOpenRe.ReplaceAllString(raw, "")
	raw = cdataCloseRe.ReplaceAllString(raw, "")
	var b strings.Builder
	b.Grow(len(raw))
	for _, r := range raw {
		if r < 0x20 && r != '\n' && r != '\r' && r != '\t' {
			continue
		}
		if r == '\n' || r == '\r' || r == '\t' {
			b.WriteRune(' ')
			continue
		}
		b.WriteRune(r)
	}
	return strings.TrimSpace(b.String())
}

// tryJSONLD returns every distinct Recipe object found in any ld+json script,
// at any nesting depth (top level, @graph, mainEntity, arrays, ...).
func (s *RecipeScrapingService) tryJSONLD(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	out := []RecipeClipResponse{}

	doc.Find(`script[type="application/ld+json"]`).Each(func(_ int, sel *goquery.Selection) {
		raw := sanitizeJSONLD(sel.Text())
		if raw == "" {
			return
		}

		// Some sites concatenate several JSON documents in one script tag;
		// decode them as a stream.
		dec := json.NewDecoder(strings.NewReader(raw))
		for {
			var data any
			if err := dec.Decode(&data); err != nil {
				break
			}
			for _, m := range findRecipesInJSONLD(data, 0) {
				out = append(out, convertStructuredData(m, pageURL))
				if len(out) >= 3 {
					return
				}
			}
		}
	})

	return out
}

func findRecipesInJSONLD(data any, depth int) []map[string]any {
	if depth > maxJSONLDDepth {
		return nil
	}
	found := []map[string]any{}
	switch v := data.(type) {
	case map[string]any:
		if isRecipeType(v["@type"]) {
			return []map[string]any{v}
		}
		// Walk well-known containers first for determinism, then everything else.
		for _, key := range []string{"@graph", "mainEntity", "mainEntityOfPage", "itemListElement", "hasPart"} {
			if child, ok := v[key]; ok {
				found = append(found, findRecipesInJSONLD(child, depth+1)...)
			}
		}
		if len(found) > 0 {
			return found
		}
		for key, child := range v {
			switch key {
			case "@graph", "mainEntity", "mainEntityOfPage", "itemListElement", "hasPart":
				continue
			}
			switch child.(type) {
			case map[string]any, []any:
				found = append(found, findRecipesInJSONLD(child, depth+1)...)
			}
		}
	case []any:
		for _, item := range v {
			found = append(found, findRecipesInJSONLD(item, depth+1)...)
		}
	}
	return found
}

func isRecipeType(t any) bool {
	matches := func(s string) bool {
		s = strings.TrimSpace(s)
		s = strings.TrimPrefix(s, "http://schema.org/")
		s = strings.TrimPrefix(s, "https://schema.org/")
		s = strings.TrimPrefix(s, "schema:")
		return strings.EqualFold(s, "Recipe")
	}
	switch v := t.(type) {
	case string:
		return matches(v)
	case []any:
		for _, item := range v {
			if s, ok := item.(string); ok && matches(s) {
				return true
			}
		}
	}
	return false
}

// ------------------------------------------------------------------
// Tier 2: Microdata extraction
// ------------------------------------------------------------------

var recipeItemtypeRe = regexp.MustCompile(`(?i).*Recipe`)

// microdataValue prefers machine-readable attributes over rendered text.
func microdataValue(sel *goquery.Selection) string {
	for _, attr := range []string{"content", "datetime"} {
		if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" {
			return strings.TrimSpace(v)
		}
	}
	return strings.TrimSpace(sel.Text())
}

func (s *RecipeScrapingService) tryMicrodata(doc *goquery.Document, pageURL string) (RecipeClipResponse, bool) {
	containers := doc.Find(`[itemtype]`).FilterFunction(func(_ int, sel *goquery.Selection) bool {
		it, ok := sel.Attr("itemtype")
		return ok && recipeItemtypeRe.MatchString(it)
	})
	if containers.Length() == 0 {
		return RecipeClipResponse{}, false
	}

	container := containers.First()
	data := map[string]any{}

	container.Find(`[itemprop]`).Each(func(_ int, sel *goquery.Selection) {
		prop, _ := sel.Attr("itemprop")
		switch prop {
		case "name":
			if _, ok := data["name"]; !ok {
				data["name"] = strings.TrimSpace(sel.Text())
			}
		case "description":
			if _, ok := data["description"]; !ok {
				data["description"] = microdataValue(sel)
			}
		case "recipeIngredient", "ingredients":
			data["recipeIngredient"] = appendAnyString(data["recipeIngredient"], strings.TrimSpace(sel.Text()))
		case "recipeInstructions":
			data["recipeInstructions"] = appendAnyString(data["recipeInstructions"], strings.TrimSpace(sel.Text()))
		case "prepTime", "cookTime", "totalTime":
			data[prop] = microdataValue(sel)
		case "author":
			data["author"] = strings.TrimSpace(sel.Text())
		case "aggregateRating":
			if s := strings.TrimSpace(sel.Text()); s != "" {
				data["aggregateRating"] = s
			}
		case "nutrition":
			if s := strings.TrimSpace(sel.Text()); s != "" {
				data["nutrition"] = s
			}
		case "video":
			if src, ok := sel.Attr("src"); ok && src != "" {
				data["video"] = src
			}
		case "tool":
			data["tool"] = appendAnyString(data["tool"], strings.TrimSpace(sel.Text()))
		case "recipeYield", "yield", "servings", "servingSize":
			data["recipeYield"] = microdataValue(sel)
		case "image":
			for _, attr := range []string{"src", "content", "href"} {
				if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" {
					data["image"] = appendAnyString(data["image"], v)
					break
				}
			}
		case "recipeCategory":
			data["recipeCategory"] = strings.TrimSpace(sel.Text())
		case "recipeCuisine":
			data["recipeCuisine"] = strings.TrimSpace(sel.Text())
		case "keywords":
			data["keywords"] = strings.TrimSpace(sel.Text())
		}
	})

	if len(data) == 0 {
		return RecipeClipResponse{}, false
	}
	return convertStructuredData(data, pageURL), true
}

func appendAnyString(existing any, s string) any {
	s = strings.TrimSpace(s)
	if s == "" {
		return existing
	}
	switch v := existing.(type) {
	case nil:
		return []any{s}
	case []any:
		return append(v, s)
	case string:
		return []any{v, s}
	default:
		return existing
	}
}

// ------------------------------------------------------------------
// Tier 3: RDFa extraction
// ------------------------------------------------------------------

var rdfaRecipeTypeRe = regexp.MustCompile(`(?i)\bRecipe\b`)

// tryRDFa maps `typeof="...Recipe"` containers with `property` attributes onto
// the same structured-data shape that JSON-LD/microdata use.
func (s *RecipeScrapingService) tryRDFa(doc *goquery.Document, pageURL string) (RecipeClipResponse, bool) {
	containers := doc.Find(`[typeof]`).FilterFunction(func(_ int, sel *goquery.Selection) bool {
		tv, ok := sel.Attr("typeof")
		return ok && rdfaRecipeTypeRe.MatchString(tv)
	})
	if containers.Length() == 0 {
		return RecipeClipResponse{}, false
	}

	container := containers.First()
	data := map[string]any{}

	container.Find(`[property]`).Each(func(_ int, sel *goquery.Selection) {
		prop, _ := sel.Attr("property")
		// Properties may be prefixed (schema:name, v:name); use the local part.
		if i := strings.LastIndexAny(prop, ":/#"); i >= 0 {
			prop = prop[i+1:]
		}
		val := microdataValue(sel)
		switch prop {
		case "name":
			if _, ok := data["name"]; !ok {
				data["name"] = val
			}
		case "description":
			if _, ok := data["description"]; !ok {
				data["description"] = val
			}
		case "recipeIngredient", "ingredients", "ingredient":
			data["recipeIngredient"] = appendAnyString(data["recipeIngredient"], val)
		case "recipeInstructions", "instructions", "instruction":
			data["recipeInstructions"] = appendAnyString(data["recipeInstructions"], val)
		case "prepTime", "cookTime", "totalTime":
			data[prop] = val
		case "author":
			data["author"] = val
		case "recipeYield", "yield":
			data["recipeYield"] = val
		case "image", "photo":
			for _, attr := range []string{"src", "content", "href"} {
				if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" {
					data["image"] = appendAnyString(data["image"], v)
					break
				}
			}
		case "recipeCategory", "recipeCuisine", "keywords":
			data[prop] = val
		}
	})

	if len(data) == 0 {
		return RecipeClipResponse{}, false
	}
	return convertStructuredData(data, pageURL), true
}

// ------------------------------------------------------------------
// Tier 4: embedded JSON app state (__NEXT_DATA__, Nuxt, Apollo, ...)
// ------------------------------------------------------------------

// tryEmbeddedJSON digs recipe objects out of JS-framework state blobs. Sites
// rendered with Next.js/Nuxt often omit ld+json but ship the full recipe in a
// serialized store keyed with the same schema.org field names.
func (s *RecipeScrapingService) tryEmbeddedJSON(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	out := []RecipeClipResponse{}

	doc.Find(`script#__NEXT_DATA__, script[type="application/json"]`).EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		raw := strings.TrimSpace(sel.Text())
		if raw == "" || len(raw) > maxEmbeddedJSONBytes {
			return true
		}
		var data any
		if err := json.Unmarshal([]byte(raw), &data); err != nil {
			return true
		}
		for _, m := range findRecipeShapedJSON(data, 0) {
			out = append(out, convertStructuredData(m, pageURL))
			if len(out) >= 3 {
				return false
			}
		}
		return true
	})

	return out
}

// findRecipeShapedJSON finds maps that look like a schema.org recipe even
// without an explicit @type (e.g. hydration stores).
func findRecipeShapedJSON(data any, depth int) []map[string]any {
	if depth > maxJSONLDDepth {
		return nil
	}
	found := []map[string]any{}
	switch v := data.(type) {
	case map[string]any:
		if isRecipeType(v["@type"]) {
			return []map[string]any{v}
		}
		_, hasIngredients := v["recipeIngredient"]
		_, hasInstructions := v["recipeInstructions"]
		if hasIngredients && hasInstructions {
			return []map[string]any{v}
		}
		for _, child := range v {
			switch child.(type) {
			case map[string]any, []any:
				found = append(found, findRecipeShapedJSON(child, depth+1)...)
			}
			if len(found) >= 3 {
				return found
			}
		}
	case []any:
		for _, item := range v {
			found = append(found, findRecipeShapedJSON(item, depth+1)...)
			if len(found) >= 3 {
				return found
			}
		}
	}
	return found
}

// ------------------------------------------------------------------
// Structured data conversion
// ------------------------------------------------------------------

var stepNumberPrefixRe = regexp.MustCompile(`(?i)^(?:step\s*\d+\s*[:.)-]?|\d+\s*[.)])\s+`)

func cleanInstructionStep(s string) string {
	s = strings.TrimSpace(s)
	return strings.TrimSpace(stepNumberPrefixRe.ReplaceAllString(s, ""))
}

func convertStructuredData(data map[string]any, pageURL string) RecipeClipResponse {
	title := strings.TrimSpace(getString(data["name"]))
	if title == "" {
		title = strings.TrimSpace(getString(data["headline"]))
	}
	if title == "" {
		title = "Untitled Recipe"
	}

	ings := make([]RecipeClipIngredient, 0, 16)
	ingredientsRaw := data["recipeIngredient"]
	if ingredientsRaw == nil {
		ingredientsRaw = data["ingredients"]
	}
	for _, v := range asStringSlice(ingredientsRaw) {
		if t := strings.TrimSpace(v); t != "" {
			ings = append(ings, RecipeClipIngredient{RawText: t})
		}
	}

	instructionsParts := make([]string, 0, 16)
	var collectInstruction func(inst any)
	collectInstruction = func(inst any) {
		switch vv := inst.(type) {
		case string:
			for _, line := range strings.Split(vv, "\n") {
				if t := cleanInstructionStep(line); t != "" {
					instructionsParts = append(instructionsParts, t)
				}
			}
		case map[string]any:
			t := strings.TrimSpace(getString(vv["text"]))
			if t == "" {
				t = strings.TrimSpace(getString(vv["name"]))
			}
			if t == "" {
				t = strings.TrimSpace(getString(vv["description"]))
			}
			if t != "" {
				if c := cleanInstructionStep(t); c != "" {
					instructionsParts = append(instructionsParts, c)
				}
			}
			if il, ok := vv["itemListElement"]; ok {
				for _, sub := range asAnySlice(il) {
					collectInstruction(sub)
				}
			}
		case []any:
			for _, sub := range vv {
				collectInstruction(sub)
			}
		}
	}
	for _, inst := range asAnySlice(data["recipeInstructions"]) {
		collectInstruction(inst)
	}

	prep := parseDurationMinutes(getString(data["prepTime"]))
	cook := parseDurationMinutes(getString(data["cookTime"]))
	perform := parseDurationMinutes(getString(data["performTime"]))
	if cook == nil && perform != nil {
		cook = perform
	}
	total := parseDurationMinutes(getString(data["totalTime"]))
	if total != nil && prep == nil && cook == nil {
		p := max(5, *total/4)
		c := *total - p
		prep = &p
		cook = &c
	}

	var servings *string
	if y := data["recipeYield"]; y != nil {
		s := strings.TrimSpace(flattenYield(y))
		if s != "" {
			servings = &s
		}
	}

	imageOptions := extractImages(data["image"], pageURL)
	var imageURL *string
	if len(imageOptions) > 0 {
		imageURL = &imageOptions[0]
	}

	tags := extractTags(data)

	description := strings.TrimSpace(getString(data["description"]))
	author := extractAuthor(data["author"])
	ratingValue, ratingCount := extractRating(data["aggregateRating"])
	nutrition := extractNutrition(data["nutrition"])
	videoURL := extractVideoURL(data["video"])
	equipment := extractEquipment(data["tool"])

	return RecipeClipResponse{
		Title:           title,
		SourceURL:       pageURL,
		Description:     description,
		Author:          author,
		RatingValue:     ratingValue,
		RatingCount:     ratingCount,
		Nutrition:       nutrition,
		VideoURL:        videoURL,
		Equipment:       equipment,
		InstructionsMD:  strings.Join(dedupeStrings(instructionsParts), "\n\n"),
		PrepTimeMinutes: prep,
		CookTimeMinutes: cook,
		Servings:        servings,
		Ingredients:     dedupeIngredients(ings),
		ImageURL:        imageURL,
		ImageOptions:    dedupeStrings(imageOptions),
		Tags:            tags,
	}
}

// flattenYield turns yield values like ["8", "8 servings"] into a single string.
func flattenYield(y any) string {
	switch v := y.(type) {
	case []any:
		best := ""
		for _, item := range v {
			s := strings.TrimSpace(getString(item))
			if len(s) > len(best) {
				best = s
			}
		}
		return best
	default:
		return getString(y)
	}
}

func extractImages(val any, pageURL string) []string {
	out := []string{}
	appendURL := func(raw string) {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			return
		}
		u, err := url.Parse(raw)
		if err != nil {
			return
		}
		if u.Scheme == "" {
			base, _ := url.Parse(pageURL)
			raw = base.ResolveReference(u).String()
		}
		out = append(out, raw)
	}

	switch v := val.(type) {
	case string:
		appendURL(v)
	case []any:
		for _, item := range v {
			switch iv := item.(type) {
			case string:
				appendURL(iv)
			case map[string]any:
				if u := getString(iv["url"]); u != "" {
					appendURL(u)
				} else if u := getString(iv["contentUrl"]); u != "" {
					appendURL(u)
				}
			}
		}
	case map[string]any:
		if u := getString(v["url"]); u != "" {
			appendURL(u)
		} else if u := getString(v["contentUrl"]); u != "" {
			appendURL(u)
		}
	}
	return out
}

func extractTags(data map[string]any) []string {
	raw := []string{}
	for _, key := range []string{"recipeCategory", "recipeCuisine", "keywords"} {
		if v, ok := data[key]; ok && v != nil {
			switch vv := v.(type) {
			case []any:
				for _, it := range vv {
					if s, ok := it.(string); ok {
						raw = append(raw, splitTags(s)...)
					}
				}
			case string:
				raw = append(raw, splitTags(vv)...)
			default:
				raw = append(raw, splitTags(fmt.Sprint(vv))...)
			}
		}
	}
	return dedupeStrings(raw)
}

func splitTags(s string) []string {
	parts := regexp.MustCompile(`[,;|/]`).Split(s, -1)
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.ToLower(strings.TrimSpace(p))
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

func getString(v any) string {
	if v == nil {
		return ""
	}
	switch s := v.(type) {
	case string:
		return s
	default:
		return fmt.Sprint(v)
	}
}

func extractAuthor(v any) string {
	switch vv := v.(type) {
	case string:
		return strings.TrimSpace(vv)
	case []any:
		for _, item := range vv {
			if a := extractAuthor(item); a != "" {
				return a
			}
		}
	case map[string]any:
		if name := getString(vv["name"]); name != "" {
			return strings.TrimSpace(name)
		}
		return strings.TrimSpace(getString(vv["@id"]))
	}
	return ""
}

func extractRating(v any) (float64, int) {
	m, ok := v.(map[string]any)
	if !ok {
		return 0, 0
	}
	var val float64
	if s := getString(m["ratingValue"]); s != "" {
		val, _ = strconv.ParseFloat(strings.ReplaceAll(s, ",", "."), 64)
	}
	var count int
	if s := getString(m["ratingCount"]); s != "" {
		count, _ = strconv.Atoi(s)
	} else if s := getString(m["reviewCount"]); s != "" {
		count, _ = strconv.Atoi(s)
	}
	return val, count
}

func extractNutrition(v any) map[string]string {
	m, ok := v.(map[string]any)
	if !ok {
		return nil
	}
	out := make(map[string]string)
	for _, key := range []string{
		"calories", "proteinContent", "fatContent", "saturatedFatContent",
		"carbohydrateContent", "sodiumContent", "fiberContent", "sugarContent",
		"cholesterolContent", "servingSize",
	} {
		if s := getString(m[key]); s != "" {
			out[key] = s
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func extractVideoURL(v any) string {
	switch vv := v.(type) {
	case string:
		return strings.TrimSpace(vv)
	case []any:
		for _, item := range vv {
			if u := extractVideoURL(item); u != "" {
				return u
			}
		}
	case map[string]any:
		if url := getString(vv["contentUrl"]); url != "" {
			return strings.TrimSpace(url)
		}
		if url := getString(vv["url"]); url != "" {
			return strings.TrimSpace(url)
		}
		if embed := getString(vv["embedUrl"]); embed != "" {
			return strings.TrimSpace(embed)
		}
	}
	return ""
}

func extractEquipment(v any) []string {
	out := []string{}
	for _, it := range asAnySlice(v) {
		switch vv := it.(type) {
		case string:
			if t := strings.TrimSpace(vv); t != "" {
				out = append(out, t)
			}
		case map[string]any:
			if name := getString(vv["name"]); name != "" {
				out = append(out, strings.TrimSpace(name))
			}
		}
	}
	return dedupeStrings(out)
}

func asAnySlice(v any) []any {
	switch vv := v.(type) {
	case nil:
		return nil
	case []any:
		return vv
	case string:
		return []any{vv}
	default:
		return []any{vv}
	}
}

func asStringSlice(v any) []string {
	out := []string{}
	for _, it := range asAnySlice(v) {
		switch s := it.(type) {
		case string:
			if strings.TrimSpace(s) != "" {
				out = append(out, s)
			}
		case map[string]any:
			// e.g. {"@type":"HowToSupply","name":"2 cups flour"}
			if name := strings.TrimSpace(getString(s["name"])); name != "" {
				out = append(out, name)
			} else if text := strings.TrimSpace(getString(s["text"])); text != "" {
				out = append(out, text)
			}
		}
	}
	return out
}

func dedupeIngredients(in []RecipeClipIngredient) []RecipeClipIngredient {
	seen := map[string]struct{}{}
	out := make([]RecipeClipIngredient, 0, len(in))
	for _, ing := range in {
		t := strings.TrimSpace(ing.RawText)
		if t == "" {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		parsed := ParseIngredient(t)
		out = append(out, parsed)
	}
	return out
}

// ------------------------------------------------------------------
// Ingredient parsing
// ------------------------------------------------------------------

var ingredientUnits = []string{
	"cups", "cup", "tablespoons", "tablespoon", "tbsp", "teaspoons", "teaspoon", "tsp",
	"ounces", "ounce", "oz", "pounds", "pound", "lbs", "lb",
	"grams", "gram", "g", "kilograms", "kilogram", "kg", "milligrams", "mg",
	"milliliters", "milliliter", "ml", "liters", "liter", "l", "cl", "dl",
	"cloves", "clove", "slices", "slice", "pieces", "piece", "pinches", "pinch",
	"bunches", "bunch", "sprigs", "sprig", "leaves", "leaf", "stalks", "stalk",
	"cans", "can", "packages", "package", "packs", "pack", "containers", "container",
	"heads", "head", "bulbs", "bulb", "ears", "ear", "strips", "strip",
	"sticks", "stick", "dashes", "dash", "handfuls", "handful", "knobs", "knob",
	"fillets", "fillet", "sheets", "sheet", "jars", "jar", "bottles", "bottle",
}

var (
	leadingBulletRe = regexp.MustCompile(`^[\s\-–—•*▢☐☑✓✔►◦·]+`)
	// A single quantity token: "1", "1.5", "1,5", "1/2", "1 1/2", "1-1/2", "½", "1½".
	qtyToken          = `(?:\d+\s+\d+\s*/\s*\d+|\d+\s*-\s*\d+\s*/\s*\d+|\d+\s*/\s*\d+|\d+(?:[.,]\d+)?\s*[¼½¾⅓⅔⅛⅜⅝⅞]?|[¼½¾⅓⅔⅛⅜⅝⅞])`
	ingredientPartsRe = regexp.MustCompile(
		`^(?i)\(?\s*(` + qtyToken + `(?:\s*(?:-|–|—|to)\s*` + qtyToken + `)?)\s*\)?\s*(?:(` +
			strings.Join(ingredientUnits, `|`) + `)\b\.?)?\s*(.*)$`,
	)
)

// ParseIngredient extracts quantity, unit, and name from raw ingredient text.
// It handles formats like "2 cups flour", "1 1/2 tsp salt", "1½ cups milk",
// "1-2 cloves garlic", "▢ 3 eggs", and "2 tbsp. butter".
func ParseIngredient(raw string) RecipeClipIngredient {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return RecipeClipIngredient{RawText: raw}
	}

	result := RecipeClipIngredient{RawText: raw}
	work := strings.TrimSpace(leadingBulletRe.ReplaceAllString(raw, ""))
	if work == "" {
		work = raw
	}

	matches := ingredientPartsRe.FindStringSubmatch(work)
	if len(matches) == 4 {
		qtyStr := strings.TrimSpace(matches[1])
		unitStr := strings.TrimSpace(matches[2])
		nameStr := strings.TrimSpace(matches[3])

		if qtyStr != "" {
			// For ranges ("1-2", "1 to 2") parse the lower bound.
			lower := regexp.MustCompile(`(?i)\s*(?:–|—|to)\s*`).Split(qtyStr, 2)[0]
			result.Quantity = parsing.ParseIngredientAmount(lower)
		}
		if unitStr != "" {
			result.Unit = strings.ToLower(unitStr)
		}
		if nameStr != "" {
			result.Name = strings.TrimPrefix(nameStr, "of ")
			result.Name = strings.TrimSpace(result.Name)
		}
	}

	if result.Name == "" {
		result.Name = work
	}

	return result
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

// ------------------------------------------------------------------
// Tier 5: heuristic extraction
// ------------------------------------------------------------------

var (
	// Fractions/quantities (language-agnostic). We include common unicode fractions
	// as literal runes because Go's regexp does not support \uXXXX escapes.
	fractionRe         = regexp.MustCompile(`[¼½¾⅓⅔⅛⅜⅝⅞]|\b\d+\s*/\s*\d+\b|\b\d+[.,]\d+\b|\b\d+\b`)
	ingredientClassRe  = regexp.MustCompile(`(?i)ingredi|zutat|ingrédient|składnik|ingrediens`)
	instructionClassRe = regexp.MustCompile(`(?i)instruct|direction|\bstep\b|method|preparat|procedure|étape|schritt|istruz|\bpaso\b|\bstap\b|\bkrok\b`)
)

// Selectors emitted by the dominant recipe-card plugins (WP Recipe Maker,
// Tasty Recipes, Mediavine Create, EasyRecipe, Simple Recipe Pro, and the
// Dotdash/Serious Eats structured markup). These are the highest-precision
// heuristic signals, so they run before the generic class scan.
var pluginIngredientSelectors = []string{
	".wprm-recipe-ingredient",
	".tasty-recipes-ingredients li",
	".tasty-recipe-ingredients li",
	".mv-create-ingredients li",
	".easyrecipe .ingredient",
	".srp-recipe-ingredients li",
	".structured-ingredients__list-item",
	"[data-ingredient-name]",
}

var pluginInstructionSelectors = []string{
	".wprm-recipe-instruction-text",
	".tasty-recipes-instructions li",
	".tasty-recipe-instructions li",
	".mv-create-instructions li",
	".easyrecipe .instruction",
	".srp-recipe-instructions li",
	"#structured-project__steps_1-0 li",
	".comp.mntl-sc-block-startgroup li",
}

var universalUnits = []string{
	"g", "kg", "mg", "ml", "cl", "dl", "l",
	"oz", "lb", "lbs", "tsp", "tbsp", "cup", "cups", "pt", "qt",
}

func (s *RecipeScrapingService) extractHeuristic(doc *goquery.Document, pageURL string) RecipeClipResponse {
	title := extractTitleHeuristic(doc)
	imageOptions := extractImageHeuristic(doc, pageURL)

	ingredientNodes := findNodesBySelectors(doc, pluginIngredientSelectors)
	if len(ingredientNodes) == 0 {
		ingredientNodes = findNodesByClassHint(doc, ingredientClassRe, "li")
	}
	if len(ingredientNodes) == 0 {
		ingredientNodes = findIngredientLiCandidates(doc)
	}

	instructionNodes := findNodesBySelectors(doc, pluginInstructionSelectors)
	if len(instructionNodes) == 0 {
		instructionNodes = findNodesByClassHint(doc, instructionClassRe, "li,p")
	}
	if len(instructionNodes) == 0 {
		instructionNodes = findAllOlItems(doc)
	}

	ingredients := extractIngredientsFromSelections(ingredientNodes)
	instructions := extractInstructionsFromSelections(instructionNodes)
	servings := extractServingsHeuristic(doc)
	description := extractDescriptionHeuristic(doc)
	author := extractAuthorHeuristic(doc)
	ratingValue, ratingCount := extractRatingHeuristic(doc)
	prep, cook := extractTimesHeuristic(doc)

	var imageURL *string
	if len(imageOptions) > 0 {
		imageURL = &imageOptions[0]
	}

	return RecipeClipResponse{
		Title:           title,
		SourceURL:       pageURL,
		Description:     description,
		Author:          author,
		RatingValue:     ratingValue,
		RatingCount:     ratingCount,
		InstructionsMD:  instructions,
		PrepTimeMinutes: prep,
		CookTimeMinutes: cook,
		Servings:        servings,
		Ingredients:     ingredients,
		ImageURL:        imageURL,
		ImageOptions:    imageOptions,
		Tags:            nil,
	}
}

func findNodesBySelectors(doc *goquery.Document, selectors []string) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}
	for _, selector := range selectors {
		doc.Find(selector).Each(func(_ int, sel *goquery.Selection) {
			t := strings.TrimSpace(sel.Text())
			if t == "" {
				return
			}
			if _, ok := seenText[t]; ok {
				return
			}
			seenText[t] = struct{}{}
			out = append(out, sel)
		})
		// One plugin per page; the first selector family that matches wins.
		if len(out) > 0 {
			break
		}
	}
	return out
}

func extractDescriptionHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="og:description"]`,
		`meta[name="twitter:description"]`,
		`meta[property="twitter:description"]`,
		`meta[name="description"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	return ""
}

func extractTitleHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="og:title"]`,
		`meta[name="twitter:title"]`,
		`meta[property="twitter:title"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	if t := strings.TrimSpace(doc.Find("h1").First().Text()); t != "" {
		return t
	}
	if t := strings.TrimSpace(doc.Find("title").First().Text()); t != "" {
		return t
	}
	return "Untitled Recipe"
}

// largestSrcsetCandidate picks the URL with the biggest width descriptor.
func largestSrcsetCandidate(srcset string) string {
	best := ""
	bestW := -1
	for _, part := range strings.Split(srcset, ",") {
		fields := strings.Fields(strings.TrimSpace(part))
		if len(fields) == 0 {
			continue
		}
		w := 0
		if len(fields) > 1 {
			d := fields[1]
			if strings.HasSuffix(d, "w") || strings.HasSuffix(d, "x") {
				w = parseDimension(d)
			}
		}
		if w > bestW {
			bestW = w
			best = fields[0]
		}
	}
	return best
}

// imgCandidateSrc handles lazy-loading attributes and srcset.
func imgCandidateSrc(sel *goquery.Selection) string {
	for _, attr := range []string{"src", "data-src", "data-lazy-src", "data-original"} {
		if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" && !strings.HasPrefix(v, "data:") {
			return strings.TrimSpace(v)
		}
	}
	for _, attr := range []string{"srcset", "data-srcset", "data-lazy-srcset"} {
		if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" {
			if c := largestSrcsetCandidate(v); c != "" && !strings.HasPrefix(c, "data:") {
				return c
			}
		}
	}
	return ""
}

func extractImageHeuristic(doc *goquery.Document, pageURL string) []string {
	out := []string{}
	for _, sel := range []string{
		`meta[property="og:image"]`,
		`meta[property="og:image:secure_url"]`,
		`meta[name="twitter:image"]`,
		`meta[property="twitter:image"]`,
		`meta[name="twitter:image:src"]`,
		`meta[property="twitter:image:src"]`,
	} {
		doc.Find(sel).Each(func(_ int, m *goquery.Selection) {
			if v, ok := m.Attr("content"); ok {
				if t := strings.TrimSpace(v); t != "" {
					u := resolveURL(pageURL, t)
					if !containsString(out, u) {
						out = append(out, u)
					}
				}
			}
		})
	}
	if v, ok := doc.Find(`link[rel="image_src"]`).Attr("href"); ok {
		if t := strings.TrimSpace(v); t != "" {
			u := resolveURL(pageURL, t)
			if !containsString(out, u) {
				out = append(out, u)
			}
		}
	}

	type scored struct {
		score int
		url   string
	}
	cands := []scored{}
	doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
		src := imgCandidateSrc(sel)
		if src == "" {
			return
		}

		full := resolveURL(pageURL, src)
		if containsString(out, full) {
			return
		}

		score := 0
		if w, ok := sel.Attr("width"); ok {
			if h, ok2 := sel.Attr("height"); ok2 {
				ww := parseDimension(w)
				hh := parseDimension(h)
				if ww > 0 && hh > 0 {
					if ww < 150 || hh < 150 {
						score -= 50
					} else {
						score += min((ww*hh)/10000, 50)
					}
				}
			}
		}
		if alt, ok := sel.Attr("alt"); ok {
			a := strings.ToLower(alt)
			if strings.Contains(strings.ToLower(src), "recipe") || strings.Contains(a, "recipe") ||
				strings.Contains(strings.ToLower(src), "food") || strings.Contains(a, "food") ||
				strings.Contains(strings.ToLower(src), "dish") || strings.Contains(a, "dish") {
				score += 20
			}
		}
		if class, ok := sel.Attr("class"); ok {
			c := strings.ToLower(class)
			if strings.Contains(c, "wprm-recipe-image") || strings.Contains(c, "tasty-recipes-image") ||
				strings.Contains(c, "recipe-image") || strings.Contains(c, "hero") {
				score += 30
			}
		}
		if score > 0 {
			cands = append(cands, scored{score: score, url: full})
		}
	})
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
	for _, c := range cands {
		out = append(out, c.url)
		if len(out) >= 10 {
			break
		}
	}
	return dedupeStrings(out)
}

func parseDimension(s string) int {
	s = regexp.MustCompile(`[^0-9]`).ReplaceAllString(s, "")
	if s == "" {
		return 0
	}
	n, _ := strconv.Atoi(s)
	return n
}

func resolveURL(base, raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return raw
	}
	if u.Scheme != "" {
		return u.String()
	}
	b, err := url.Parse(base)
	if err != nil {
		return raw
	}
	return b.ResolveReference(u).String()
}

func findNodesByClassHint(doc *goquery.Document, re *regexp.Regexp, selector string) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}

	doc.Find("*").Each(func(_ int, sel *goquery.Selection) {
		class, _ := sel.Attr("class")
		id, _ := sel.Attr("id")
		target := strings.TrimSpace(class + " " + id)
		if target == "" || !re.MatchString(target) {
			return
		}
		sel.Find(selector).Each(func(_ int, child *goquery.Selection) {
			t := strings.TrimSpace(child.Text())
			if t == "" {
				return
			}
			if _, ok := seenText[t]; ok {
				return
			}
			seenText[t] = struct{}{}
			out = append(out, child)
		})
	})
	return out
}

func findIngredientLiCandidates(doc *goquery.Document) []*goquery.Selection {
	type cand struct {
		score int
		sel   *goquery.Selection
	}
	cands := []cand{}
	seenText := map[string]struct{}{}

	doc.Find("li").Each(func(_ int, sel *goquery.Selection) {
		text := strings.TrimSpace(sel.Text())
		if text == "" || len(text) > 200 {
			return
		}
		if _, ok := seenText[text]; ok {
			return
		}
		score := scoreIngredientText(text)
		if score > 20 {
			seenText[text] = struct{}{}
			cands = append(cands, cand{score: score, sel: sel})
		}
	})
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
	out := []*goquery.Selection{}
	for i := 0; i < len(cands) && i < 30; i++ {
		out = append(out, cands[i].sel)
	}
	return out
}

func findAllOlItems(doc *goquery.Document) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}
	doc.Find("ol li").Each(func(_ int, sel *goquery.Selection) {
		text := strings.TrimSpace(sel.Text())
		if text == "" || len(text) < 15 {
			return
		}
		if _, ok := seenText[text]; ok {
			return
		}
		seenText[text] = struct{}{}
		out = append(out, sel)
	})
	return out
}

func extractIngredientsFromSelections(nodes []*goquery.Selection) []RecipeClipIngredient {
	out := []RecipeClipIngredient{}
	seen := map[string]struct{}{}
	for _, sel := range nodes {
		t := strings.TrimSpace(sel.Text())
		if t == "" || len(t) > 200 {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		out = append(out, ParseIngredient(t))
	}
	return out
}

func extractInstructionsFromSelections(nodes []*goquery.Selection) string {
	parts := []string{}
	seen := map[string]struct{}{}
	for _, sel := range nodes {
		t := strings.TrimSpace(sel.Text())
		if t == "" || len(t) < 15 {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		parts = append(parts, t)
	}
	return strings.Join(parts, "\n\n")
}

func extractAuthorHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="article:author"]`,
		`meta[name="twitter:creator"]`,
		`meta[property="twitter:creator"]`,
		`meta[name="author"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	// Try common author class/id patterns.
	found := ""
	doc.Find("[class*='author'],[class*='byline'],[id*='author'],[id*='byline']").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		t := strings.TrimSpace(sel.Text())
		if t != "" && len(t) < 100 {
			found = strings.TrimSpace(strings.TrimPrefix(strings.TrimPrefix(t, "By "), "by "))
			return false
		}
		return true
	})
	return found
}

func extractRatingHeuristic(doc *goquery.Document) (float64, int) {
	text := doc.Text()
	// Look for patterns like "4.5 stars", "Rating: 4.5 (123 votes)", "4.5/5"
	patterns := []string{
		`(?i)(?:rating|rated?)[:\s]*(\d+(?:\.\d+)?)\s*(?:/\s*5)?\s*(?:stars?)?\s*\(?\s*(\d+)\s*(?:votes?|reviews?|ratings?)?\s*\)?`,
		`(?i)(\d+(?:\.\d+)?)\s*(?:out of|\/)\s*5\s*(?:stars?)?\s*\(?\s*(\d+)\s*(?:votes?|reviews?|ratings?)?\s*\)?`,
		`(?i)(\d+(?:\.\d+)?)\s*\/?\s*5\s*stars?`,
	}
	for _, p := range patterns {
		re := regexp.MustCompile(p)
		if m := re.FindStringSubmatch(text); len(m) >= 2 {
			val, _ := strconv.ParseFloat(strings.TrimSpace(m[1]), 64)
			count := 0
			if len(m) >= 3 {
				count, _ = strconv.Atoi(strings.TrimSpace(m[2]))
			}
			if val > 0 && val <= 5 {
				return val, count
			}
		}
	}
	return 0, 0
}

func extractTimesHeuristic(doc *goquery.Document) (*int, *int) {
	text := doc.Text()
	var prep, cook *int

	// ISO-like in text: PT15M
	isoRe := regexp.MustCompile(`(?i)prep(?:aration)?\s*time[:\s]*PT(?:(\d+)H)?(?:(\d+)M)?`)
	if m := isoRe.FindStringSubmatch(text); len(m) >= 3 {
		h := atoi0(m[1])
		mins := atoi0(m[2])
		if h > 0 || mins > 0 {
			v := h*60 + mins
			prep = &v
		}
	}

	isoCookRe := regexp.MustCompile(`(?i)cook(?:ing)?\s*time[:\s]*PT(?:(\d+)H)?(?:(\d+)M)?`)
	if m := isoCookRe.FindStringSubmatch(text); len(m) >= 3 {
		h := atoi0(m[1])
		mins := atoi0(m[2])
		if h > 0 || mins > 0 {
			v := h*60 + mins
			cook = &v
		}
	}

	// Plain text: "Prep: 15 mins", "Cook time: 30 minutes", "Prep time: 1 hour 20 minutes"
	if prep == nil {
		re := regexp.MustCompile(`(?i)(?:prep(?:aration)?\s*time|prep)[:\s]*(?:(\d+)\s*(?:hours?|hrs?|h)\s*)?(\d+)?(?:\s*-\s*\d+)?\s*(?:min|mins|minutes?)`)
		if m := re.FindStringSubmatch(text); len(m) >= 3 {
			v := atoi0(m[1])*60 + atoi0(m[2])
			if v > 0 {
				prep = &v
			}
		}
	}
	if cook == nil {
		re := regexp.MustCompile(`(?i)(?:cook(?:ing)?\s*time|cook)[:\s]*(?:(\d+)\s*(?:hours?|hrs?|h)\s*)?(\d+)?(?:\s*-\s*\d+)?\s*(?:min|mins|minutes?)`)
		if m := re.FindStringSubmatch(text); len(m) >= 3 {
			v := atoi0(m[1])*60 + atoi0(m[2])
			if v > 0 {
				cook = &v
			}
		}
	}

	return prep, cook
}

func extractServingsHeuristic(doc *goquery.Document) *string {
	text := doc.Text()
	patterns := []string{
		`(?i)(?:serves?|servings?|makes?|yields?)[:\s]*(\d+(?:\s*-\s*\d+)?)`,
		`(?i)(\d+(?:\s*-\s*\d+)?)\s*(?:servings?|portions?|people?)`,
	}
	for _, p := range patterns {
		re := regexp.MustCompile(p)
		if m := re.FindStringSubmatch(text); len(m) >= 2 {
			v := strings.TrimSpace(m[1])
			if v != "" {
				return &v
			}
		}
	}
	return nil
}

func scoreIngredientText(text string) int {
	score := 0
	if len(text) < 60 {
		score += 20
	} else if len(text) < 120 {
		score += 10
	}
	if fractionRe.MatchString(text) {
		score += 30
	}
	lower := strings.ToLower(text)
	for _, unit := range universalUnits {
		// Go regex (RE2) doesn't support lookbehind. Approximate word boundaries:
		// unit must be separated by non-word chars (or edges).
		re := regexp.MustCompile(`(^|[^A-Za-z0-9_])` + regexp.QuoteMeta(unit) + `([^A-Za-z0-9_]|$)`)
		if re.MatchString(lower) {
			score += 20
			break
		}
	}
	score -= len(regexp.MustCompile(`[.!?]`).FindAllString(text, -1)) * 8
	if len(text) > 200 {
		score -= 30
	}
	if score < 0 {
		return 0
	}
	return score
}

// ------------------------------------------------------------------
// Duration parsing
// ------------------------------------------------------------------

var isoDurationRe = regexp.MustCompile(`(?i)^P(?:(\d+)D)?T?(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+)S)?$`)

func parseDurationMinutes(v string) *int {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	if m := isoDurationRe.FindStringSubmatch(v); len(m) > 0 {
		days := atoi0(m[1])
		h, _ := strconv.ParseFloat(strings.TrimSpace(m[2]), 64)
		mins, _ := strconv.ParseFloat(strings.TrimSpace(m[3]), 64)
		total := days*24*60 + int(h*60) + int(mins)
		if total == 0 {
			return nil
		}
		return &total
	}

	// Free-text durations: "1 hour 20 minutes", "90 min", "2 hrs".
	hourRe := regexp.MustCompile(`(?i)(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h\b)`)
	minRe := regexp.MustCompile(`(?i)(\d+)\s*(?:minutes?|mins?|m\b)`)
	total := 0
	if m := hourRe.FindStringSubmatch(v); len(m) >= 2 {
		h, _ := strconv.ParseFloat(m[1], 64)
		total += int(h * 60)
	}
	if m := minRe.FindStringSubmatch(v); len(m) >= 2 {
		total += atoi0(m[1])
	}
	if total > 0 {
		return &total
	}

	re := regexp.MustCompile(`(\d+)`)
	if m := re.FindStringSubmatch(v); len(m) >= 2 {
		out := atoi0(m[1])
		return &out
	}
	return nil
}

func atoi0(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}
