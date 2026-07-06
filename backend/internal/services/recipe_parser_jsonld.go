package services

import (
	"encoding/json"
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

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
func tryJSONLD(doc *goquery.Document, pageURL string) []RecipeClipResponse {
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

// jsonLDParser implements recipeParser for schema.org JSON-LD script tags.
type jsonLDParser struct{}

func (jsonLDParser) name() string { return "json-ld" }

func (jsonLDParser) parse(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	return tryJSONLD(doc, pageURL)
}
