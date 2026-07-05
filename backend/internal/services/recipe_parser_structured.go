package services

import (
	"fmt"
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

// ------------------------------------------------------------------
// Structured data conversion
//
// Shared by every tier that yields schema.org-shaped data: JSON-LD,
// microdata, RDFa, and embedded app-state JSON.
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
