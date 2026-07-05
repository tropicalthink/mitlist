package services

import (
	"encoding/json"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

// ------------------------------------------------------------------
// Tier 4: embedded JSON app state (__NEXT_DATA__, Nuxt, Apollo, ...)
// ------------------------------------------------------------------

// tryEmbeddedJSON digs recipe objects out of JS-framework state blobs. Sites
// rendered with Next.js/Nuxt often omit ld+json but ship the full recipe in a
// serialized store keyed with the same schema.org field names.
func tryEmbeddedJSON(doc *goquery.Document, pageURL string) []RecipeClipResponse {
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

// embeddedJSONParser implements recipeParser for JS-framework hydration
// state (__NEXT_DATA__, Nuxt, Apollo, ...).
type embeddedJSONParser struct{}

func (embeddedJSONParser) name() string { return "embedded-json" }

func (embeddedJSONParser) parse(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	return tryEmbeddedJSON(doc, pageURL)
}
