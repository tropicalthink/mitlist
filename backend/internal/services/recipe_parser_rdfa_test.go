package services

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRDFaParser_Name(t *testing.T) {
	assert.Equal(t, "rdfa", rdfaParser{}.name())
}

// TestRDFaParser_ParsesRecipe exercises the strategy in isolation, including
// prefixed property names (schema:...).
func TestRDFaParser_ParsesRecipe(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<div typeof="schema:Recipe">
  <h1 property="schema:name">Isolated Roast</h1>
  <span property="schema:author">Chef Iso</span>
  <ul>
    <li property="schema:recipeIngredient">2 lb chicken</li>
    <li property="schema:recipeIngredient">1 tbsp salt</li>
  </ul>
  <div property="schema:recipeInstructions">Roast at 400F until done.</div>
  <meta property="schema:cookTime" content="PT60M">
</div>
</body></html>`)

	out := rdfaParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Isolated Roast", r.Title)
	assert.Equal(t, "Chef Iso", r.Author)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "2 lb chicken", r.Ingredients[0].RawText)
	assert.Contains(t, r.InstructionsMD, "Roast at 400F")
	require.NotNil(t, r.CookTimeMinutes)
	assert.Equal(t, 60, *r.CookTimeMinutes)
}

// TestRDFaParser_NoTypeof returns no candidates when no element carries a
// Recipe typeof.
func TestRDFaParser_NoTypeof(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<div typeof="schema:Article"><span property="schema:name">Article</span></div>
</body></html>`)

	out := rdfaParser{}.parse(doc, "https://example.com/r")
	assert.Empty(t, out)
}
