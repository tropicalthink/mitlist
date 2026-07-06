package services

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMicrodataParser_Name(t *testing.T) {
	assert.Equal(t, "microdata", microdataParser{}.name())
}

// TestMicrodataParser_ParsesRecipe exercises the strategy in isolation.
func TestMicrodataParser_ParsesRecipe(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Isolated Cupcakes</h1>
  <ul>
    <li itemprop="recipeIngredient">1 cup flour</li>
    <li itemprop="recipeIngredient">1/2 cup butter</li>
  </ul>
  <div itemprop="recipeInstructions"><p>Preheat oven. Mix batter thoroughly.</p></div>
  <meta itemprop="prepTime" content="PT10M">
  <meta itemprop="cookTime" content="PT20M">
</div>
</body></html>`)

	out := microdataParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Isolated Cupcakes", r.Title)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "1 cup flour", r.Ingredients[0].RawText)
	assert.Contains(t, r.InstructionsMD, "Preheat oven")
	require.NotNil(t, r.PrepTimeMinutes)
	assert.Equal(t, 10, *r.PrepTimeMinutes)
	require.NotNil(t, r.CookTimeMinutes)
	assert.Equal(t, 20, *r.CookTimeMinutes)
}

// TestMicrodataParser_NoRecipeContainer returns no candidates when nothing
// on the page carries a Recipe itemtype.
func TestMicrodataParser_NoRecipeContainer(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<div itemscope itemtype="https://schema.org/Article">
  <h1 itemprop="name">Just an article</h1>
</div>
</body></html>`)

	out := microdataParser{}.parse(doc, "https://example.com/r")
	assert.Empty(t, out)
}
