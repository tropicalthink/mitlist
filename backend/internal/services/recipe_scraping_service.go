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

	"github.com/yourorg/mitlist/internal/security"
)

const maxRecipeResponseBytes = 5 * 1024 * 1024

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
// 1) JSON-LD (schema.org)  2) Microdata  3) Heuristics (fallback)
//
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
			Timeout: 15 * time.Second,
			Transport: transport,
		},
	}
}

func (s *RecipeScrapingService) ScrapeRecipe(ctx context.Context, rawURL string) (*RecipeClipResponse, error) {
	u, err := security.ValidateURLForFetch(ctx, rawURL)
	if err != nil {
		return nil, fmt.Errorf("url not allowed: %w", err)
	}

	html, finalURL, err := s.fetchHTML(ctx, u.String())
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return nil, fmt.Errorf("failed to parse html")
	}

	results := make([]tierResult, 0, 3)

	if r, ok := s.tryJSONLD(doc, finalURL); ok && isUsable(r) {
		results = append(results, tierResult{Name: "json-ld", R: r})
	}
	if r, ok := s.tryMicrodata(doc, finalURL); ok && isUsable(r) {
		results = append(results, tierResult{Name: "microdata", R: r})
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
	merged.SourceURL = finalURL
	return &merged, nil
}

// ------------------------------------------------------------------
// Fetching (SSRF-safe + size cap + redirect validation)
// ------------------------------------------------------------------

func (s *RecipeScrapingService) fetchHTML(ctx context.Context, raw string) (string, string, error) {
	redirects := 0
	client := *s.client
	client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
		redirects++
		if redirects > 3 {
			return http.ErrUseLastResponse
		}
		if _, err := security.ValidateURLForFetch(req.Context(), req.URL.String()); err != nil {
			return err
		}
		return nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, raw, nil)
	if err != nil {
		return "", "", fmt.Errorf("invalid request")
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

	resp, err := client.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("failed to fetch page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", "", fmt.Errorf("http %d", resp.StatusCode)
	}

	body, err := readUpTo(resp.Body, maxRecipeResponseBytes)
	if err != nil {
		return "", "", err
	}

	ct := resp.Header.Get("Content-Type")
	if strings.Contains(strings.ToLower(ct), "application/pdf") {
		return "", "", fmt.Errorf("unsupported content type")
	}

	return string(body), resp.Request.URL.String(), nil
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
	sort.Slice(results, func(i, j int) bool {
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

func (s *RecipeScrapingService) tryJSONLD(doc *goquery.Document, pageURL string) (RecipeClipResponse, bool) {
	var found map[string]any

	doc.Find(`script[type="application/ld+json"]`).EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		raw := strings.TrimSpace(sel.Text())
		if raw == "" {
			return true
		}

		var data any
		if err := json.Unmarshal([]byte(raw), &data); err != nil {
			return true
		}

		if m := findRecipeInJSONLD(data); m != nil {
			found = m
			return false
		}
		return true
	})

	if found == nil {
		return RecipeClipResponse{}, false
	}

	r := convertStructuredData(found, pageURL)
	return r, true
}

func findRecipeInJSONLD(data any) map[string]any {
	switch v := data.(type) {
	case map[string]any:
		if isRecipeType(v["@type"]) {
			return v
		}
		if g, ok := v["@graph"]; ok {
			if arr, ok := g.([]any); ok {
				for _, item := range arr {
					if m, ok := item.(map[string]any); ok && isRecipeType(m["@type"]) {
						return m
					}
				}
			}
		}
	case []any:
		for _, item := range v {
			if m, ok := item.(map[string]any); ok && isRecipeType(m["@type"]) {
				return m
			}
		}
	}
	return nil
}

func isRecipeType(t any) bool {
	types := map[string]struct{}{
		"Recipe":                 {},
		"recipe":                 {},
		"http://schema.org/Recipe":  {},
		"https://schema.org/Recipe": {},
	}
	switch v := t.(type) {
	case string:
		_, ok := types[v]
		return ok
	case []any:
		for _, item := range v {
			if s, ok := item.(string); ok {
				if _, ok := types[s]; ok {
					return true
				}
			}
		}
	}
	return false
}

// ------------------------------------------------------------------
// Tier 2: Microdata extraction
// ------------------------------------------------------------------

var recipeItemtypeRe = regexp.MustCompile(`(?i).*Recipe`)

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
		case "recipeIngredient":
			data["recipeIngredient"] = appendAnyString(data["recipeIngredient"], strings.TrimSpace(sel.Text()))
		case "recipeInstructions":
			data["recipeInstructions"] = appendAnyString(data["recipeInstructions"], strings.TrimSpace(sel.Text()))
		case "prepTime", "cookTime", "totalTime":
			if dt, ok := sel.Attr("datetime"); ok && strings.TrimSpace(dt) != "" {
				data[prop] = strings.TrimSpace(dt)
			} else {
				data[prop] = strings.TrimSpace(sel.Text())
			}
		case "recipeYield", "yield", "servings", "servingSize":
			data["recipeYield"] = strings.TrimSpace(sel.Text())
		case "image":
			if src, ok := sel.Attr("src"); ok && src != "" {
				data["image"] = appendAnyString(data["image"], src)
			} else if c, ok := sel.Attr("content"); ok && c != "" {
				data["image"] = appendAnyString(data["image"], c)
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
// Structured data conversion
// ------------------------------------------------------------------

func convertStructuredData(data map[string]any, pageURL string) RecipeClipResponse {
	title := getString(data["name"])
	if title == "" {
		title = "Untitled Recipe"
	}

	ings := make([]RecipeClipIngredient, 0, 16)
	for _, v := range asStringSlice(data["recipeIngredient"]) {
		if t := strings.TrimSpace(v); t != "" {
			ings = append(ings, RecipeClipIngredient{RawText: t})
		}
	}

	instructionsParts := make([]string, 0, 16)
	for _, inst := range asAnySlice(data["recipeInstructions"]) {
		switch vv := inst.(type) {
		case string:
			if t := strings.TrimSpace(vv); t != "" {
				instructionsParts = append(instructionsParts, t)
			}
		case map[string]any:
			t := strings.TrimSpace(getString(vv["text"]))
			if t == "" {
				t = strings.TrimSpace(getString(vv["name"]))
			}
			if t != "" {
				instructionsParts = append(instructionsParts, t)
			}
			if il, ok := vv["itemListElement"]; ok {
				for _, sub := range asAnySlice(il) {
					if m, ok := sub.(map[string]any); ok {
						st := strings.TrimSpace(getString(m["text"]))
						if st == "" {
							st = strings.TrimSpace(getString(m["name"]))
						}
						if st != "" {
							instructionsParts = append(instructionsParts, st)
						}
					}
				}
			}
		case []any:
			for _, sub := range vv {
				if m, ok := sub.(map[string]any); ok {
					st := strings.TrimSpace(getString(m["text"]))
					if st == "" {
						st = strings.TrimSpace(getString(m["name"]))
					}
					if st != "" {
						instructionsParts = append(instructionsParts, st)
					}
				}
			}
		}
	}

	prep := parseDurationMinutes(getString(data["prepTime"]))
	cook := parseDurationMinutes(getString(data["cookTime"]))
	total := parseDurationMinutes(getString(data["totalTime"]))
	if total != nil && prep == nil && cook == nil {
		p := max(5, *total/4)
		c := *total - p
		prep = &p
		cook = &c
	}

	var servings *string
	if y := data["recipeYield"]; y != nil {
		s := strings.TrimSpace(fmt.Sprint(y))
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

	// Extract new fields
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
				}
			}
		}
	case map[string]any:
		if u := getString(v["url"]); u != "" {
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
		val, _ = strconv.ParseFloat(s, 64)
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
	for _, key := range []string{"calories", "proteinContent", "fatContent", "carbohydrateContent", "sodiumContent", "fiberContent", "sugarContent"} {
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
		if s, ok := it.(string); ok && strings.TrimSpace(s) != "" {
			out = append(out, s)
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

// ParseIngredient extracts quantity, unit, and name from raw ingredient text.
// It handles common formats like "2 cups flour", "1/2 tsp salt", "3 eggs".
func ParseIngredient(raw string) RecipeClipIngredient {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return RecipeClipIngredient{RawText: raw}
	}

	result := RecipeClipIngredient{RawText: raw}

	// Common units to match
	units := []string{
		"cups", "cup", "tbsp", "tsp", "tablespoons", "tablespoon", "teaspoons", "teaspoon",
		"oz", "ounces", "ounce", "lbs", "lb", "pounds", "pound",
		"g", "grams", "gram", "kg", "kilograms", "kilogram",
		"ml", "milliliters", "milliliter", "l", "liters", "liter",
		"cloves", "clove", "slices", "slice", "pieces", "piece", "pinches", "pinch",
		"bunches", "bunch", "sprigs", "sprig", "leaves", "leaf", "stalks", "stalk",
		"cans", "can", "packages", "package", "packs", "pack", "containers", "container",
		"heads", "head", "bulbs", "bulb", "ears", "ear", "strips", "strip",
	}

	// Build regex: optional quantity (number/fraction) + optional unit + rest = name
	// Pattern: ^(\d+(?:\.\d+)?\s*(?:/\s*\d+)?|\d+\/\d+|¼|½|¾|⅓|⅔|⅛|⅜|⅝|⅞)?\s*(\w+)?\s*(.*)$
	re := regexp.MustCompile(`^(?i)(\d+(?:\.\d+)?\s*(?:/\s*\d+)?|\d+\/\d+|¼|½|¾|⅓|⅔|⅛|⅜|⅝|⅞)?\s*(` + strings.Join(units, `|`) + `)?\s*(.*)$`)

	matches := re.FindStringSubmatch(raw)
	if len(matches) == 4 {
		qtyStr := strings.TrimSpace(matches[1])
		unitStr := strings.TrimSpace(matches[2])
		nameStr := strings.TrimSpace(matches[3])

		if qtyStr != "" {
			result.Quantity = parseFraction(qtyStr)
		}
		if unitStr != "" {
			result.Unit = unitStr
		}
		if nameStr != "" {
			result.Name = nameStr
		}
	}

	// Fallback: if no name parsed, use the whole raw text
	if result.Name == "" {
		result.Name = raw
	}

	return result
}

// parseFraction converts strings like "1/2", "¼", "2 1/2" to float64.
func parseFraction(s string) float64 {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}

	// Unicode fractions
	fractions := map[rune]float64{
		'¼': 0.25, '½': 0.5, '¾': 0.75,
		'⅓': 1.0 / 3.0, '⅔': 2.0 / 3.0,
		'⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
	}
	for r, v := range fractions {
		if strings.ContainsRune(s, r) {
			// Check for mixed number like "1½"
			before := strings.TrimSpace(strings.Split(s, string(r))[0])
			if before != "" {
				if whole, err := strconv.ParseFloat(before, 64); err == nil {
					return whole + v
				}
			}
			return v
		}
	}

	// Mixed fraction like "1 1/2" or "1-1/2"
	s = strings.ReplaceAll(s, "-", " ")
	parts := strings.Fields(s)
	if len(parts) == 2 {
		whole, err1 := strconv.ParseFloat(parts[0], 64)
		frac, err2 := parseSimpleFraction(parts[1])
		if err1 == nil && err2 == nil {
			return whole + frac
		}
	}

	// Simple fraction like "1/2"
	if v, err := parseSimpleFraction(s); err == nil {
		return v
	}

	// Plain number
	if v, err := strconv.ParseFloat(s, 64); err == nil {
		return v
	}

	return 0
}

func parseSimpleFraction(s string) (float64, error) {
	parts := strings.Split(s, "/")
	if len(parts) == 2 {
		num, err1 := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
		den, err2 := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
		if err1 == nil && err2 == nil && den != 0 {
			return num / den, nil
		}
	}
	return 0, fmt.Errorf("not a fraction")
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
// Tier 3: heuristic extraction
// ------------------------------------------------------------------

var (
	// Fractions/quantities (language-agnostic). We include common unicode fractions
	// as literal runes because Go's regexp does not support \uXXXX escapes.
	fractionRe = regexp.MustCompile(`[¼½¾⅓⅔⅛⅜⅝⅞]|\b\d+\s*/\s*\d+\b|\b\d+[.,]\d+\b|\b\d+\b`)
	ingredientClassRe = regexp.MustCompile(`(?i)ingredi|zutat|ingrédient|składnik|ingrediens`)
	instructionClassRe = regexp.MustCompile(`(?i)instruct|direction|\bstep\b|method|preparat|procedure|étape|schritt|istruz|\bpaso\b|\bstap\b|\bkrok\b`)
)

var universalUnits = []string{
	"g", "kg", "mg", "ml", "cl", "dl", "l",
	"oz", "lb", "lbs", "tsp", "tbsp", "cup", "cups", "pt", "qt",
}

func (s *RecipeScrapingService) extractHeuristic(doc *goquery.Document, pageURL string) RecipeClipResponse {
	title := extractTitleHeuristic(doc)
	imageOptions := extractImageHeuristic(doc, pageURL)
	ingredientNodes := findNodesByClassHint(doc, ingredientClassRe, "li")
	if len(ingredientNodes) == 0 {
		ingredientNodes = findIngredientLiCandidates(doc)
	}
	instructionNodes := findNodesByClassHint(doc, instructionClassRe, "li,p")
	if len(instructionNodes) == 0 {
		instructionNodes = findAllOlItems(doc)
	}

	ingredients := extractIngredientsFromSelections(ingredientNodes)
	instructions := extractInstructionsFromSelections(instructionNodes)
	servings := extractServingsHeuristic(doc)

	var imageURL *string
	if len(imageOptions) > 0 {
		imageURL = &imageOptions[0]
	}

	return RecipeClipResponse{
		Title:          title,
		SourceURL:      pageURL,
		InstructionsMD: instructions,
		Servings:       servings,
		Ingredients:    ingredients,
		ImageURL:       imageURL,
		ImageOptions:   imageOptions,
		Tags:           nil,
	}
}

func extractTitleHeuristic(doc *goquery.Document) string {
	if v, ok := doc.Find(`meta[property="og:title"]`).Attr("content"); ok {
		if t := strings.TrimSpace(v); t != "" {
			return t
		}
	}
	if t := strings.TrimSpace(doc.Find("title").First().Text()); t != "" {
		return t
	}
	return "Untitled Recipe"
}

func extractImageHeuristic(doc *goquery.Document, pageURL string) []string {
	out := []string{}
	if v, ok := doc.Find(`meta[property="og:image"]`).Attr("content"); ok {
		if t := strings.TrimSpace(v); t != "" {
			out = append(out, resolveURL(pageURL, t))
		}
	}

	type scored struct {
		score int
		url   string
	}
	cands := []scored{}
	doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
		src, _ := sel.Attr("src")
		if strings.TrimSpace(src) == "" {
			src, _ = sel.Attr("data-src")
		}
		if strings.TrimSpace(src) == "" {
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
		if score > 0 {
			cands = append(cands, scored{score: score, url: full})
		}
	})
	sort.Slice(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
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
	sort.Slice(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
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
		out = append(out, RecipeClipIngredient{RawText: t})
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

var isoDurationRe = regexp.MustCompile(`(?i)^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$`)

func parseDurationMinutes(v string) *int {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	if m := isoDurationRe.FindStringSubmatch(v); len(m) > 0 {
		h := atoi0(m[1])
		mins := atoi0(m[2])
		if h == 0 && mins == 0 {
			return nil
		}
		out := h*60 + mins
		return &out
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

