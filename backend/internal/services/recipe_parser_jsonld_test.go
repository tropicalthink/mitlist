package services

import (
	"strings"
	"testing"

	"github.com/PuerkitoBio/goquery"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mustParseDoc builds a goquery document for per-strategy parser tests.
func mustParseDoc(t *testing.T, html string) *goquery.Document {
	t.Helper()
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	require.NoError(t, err)
	return doc
}

func TestJSONLDParser_Name(t *testing.T) {
	assert.Equal(t, "json-ld", jsonLDParser{}.name())
}

// TestJSONLDParser_ParsesRecipe exercises the strategy in isolation, without
// going through scrapeHTML or the tier merge.
func TestJSONLDParser_ParsesRecipe(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Isolated Cake",
  "recipeIngredient": ["2 cups flour", "1 cup sugar"],
  "recipeInstructions": [{"@type": "HowToStep", "text": "Mix."}, {"@type": "HowToStep", "text": "Bake."}],
  "prepTime": "PT15M"
}
</script>
</body></html>`)

	out := jsonLDParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Isolated Cake", r.Title)
	assert.Equal(t, "https://example.com/r", r.SourceURL)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "2 cups flour", r.Ingredients[0].RawText)
	assert.Contains(t, r.InstructionsMD, "Mix.")
	assert.Contains(t, r.InstructionsMD, "Bake.")
	require.NotNil(t, r.PrepTimeMinutes)
	assert.Equal(t, 15, *r.PrepTimeMinutes)
}

// TestJSONLDParser_MultipleRecipesCappedPerScript verifies the strategy
// returns each distinct recipe found in a script tag, capped at 3 per tag
// (the cap is per-script: it stops walking that tag, not the whole page).
func TestJSONLDParser_MultipleRecipesCappedPerScript(t *testing.T) {
	var graph []string
	for _, name := range []string{"A", "B", "C", "D"} {
		graph = append(graph, `{"@type":"Recipe","name":"Recipe `+name+`","recipeIngredient":["1 egg"],"recipeInstructions":["Cook."]}`)
	}
	html := `<html><body><script type="application/ld+json">{"@graph":[` +
		strings.Join(graph, ",") + `]}</script></body></html>`
	doc := mustParseDoc(t, html)

	out := jsonLDParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 3)
	assert.Equal(t, "Recipe A", out[0].Title)
	assert.Equal(t, "Recipe C", out[2].Title)
}

// TestJSONLDParser_NoRecipe returns no candidates for pages without a
// Recipe object (this strategy "doesn't apply").
func TestJSONLDParser_NoRecipe(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<script type="application/ld+json">{"@type":"Article","headline":"Not a recipe"}</script>
<script type="application/ld+json">not even json</script>
</body></html>`)

	out := jsonLDParser{}.parse(doc, "https://example.com/r")
	assert.Empty(t, out)
}
