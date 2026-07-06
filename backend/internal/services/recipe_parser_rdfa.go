package services

import (
	"regexp"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

// ------------------------------------------------------------------
// Tier 3: RDFa extraction
// ------------------------------------------------------------------

var rdfaRecipeTypeRe = regexp.MustCompile(`(?i)\bRecipe\b`)

// tryRDFa maps `typeof="...Recipe"` containers with `property` attributes onto
// the same structured-data shape that JSON-LD/microdata use.
func tryRDFa(doc *goquery.Document, pageURL string) (RecipeClipResponse, bool) {
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

// rdfaParser implements recipeParser for RDFa (typeof/property) markup.
type rdfaParser struct{}

func (rdfaParser) name() string { return "rdfa" }

func (rdfaParser) parse(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	if r, ok := tryRDFa(doc, pageURL); ok {
		return []RecipeClipResponse{r}
	}
	return nil
}
