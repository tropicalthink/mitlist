package services

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEmbeddedJSONParser_Name(t *testing.T) {
	assert.Equal(t, "embedded-json", embeddedJSONParser{}.name())
}

// TestEmbeddedJSONParser_NextDataShape exercises the strategy in isolation
// on a __NEXT_DATA__ hydration blob with no explicit @type but the
// recipeIngredient/recipeInstructions shape.
func TestEmbeddedJSONParser_NextDataShape(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<script id="__NEXT_DATA__" type="application/json">
{"props":{"pageProps":{"recipe":{"name":"Isolated Bowl","recipeIngredient":["1 cup rice","2 cups water"],"recipeInstructions":["Rinse rice.","Cook rice."]}}}}
</script>
</body></html>`)

	out := embeddedJSONParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Isolated Bowl", r.Title)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "1 cup rice", r.Ingredients[0].RawText)
	assert.Contains(t, r.InstructionsMD, "Rinse rice")
}

// TestEmbeddedJSONParser_ExplicitType finds @type:Recipe objects inside
// generic application/json blobs too.
func TestEmbeddedJSONParser_ExplicitType(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<script type="application/json">
{"store":{"entities":[{"@type":"Recipe","name":"Typed Stew","recipeIngredient":["1 potato"],"recipeInstructions":["Boil."]}]}}
</script>
</body></html>`)

	out := embeddedJSONParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	assert.Equal(t, "Typed Stew", out[0].Title)
}

// TestEmbeddedJSONParser_NoRecipeShape returns no candidates when the JSON
// has neither @type:Recipe nor the ingredient/instruction key pair.
func TestEmbeddedJSONParser_NoRecipeShape(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<script type="application/json">{"props":{"user":{"name":"nobody"}}}</script>
<script type="application/json">this is not json</script>
</body></html>`)

	out := embeddedJSONParser{}.parse(doc, "https://example.com/r")
	assert.Empty(t, out)
}
