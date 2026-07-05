package services

import (
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

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

func tryMicrodata(doc *goquery.Document, pageURL string) (RecipeClipResponse, bool) {
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

// microdataParser implements recipeParser for schema.org microdata
// (itemscope/itemtype/itemprop) markup.
type microdataParser struct{}

func (microdataParser) name() string { return "microdata" }

func (microdataParser) parse(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	if r, ok := tryMicrodata(doc, pageURL); ok {
		return []RecipeClipResponse{r}
	}
	return nil
}
