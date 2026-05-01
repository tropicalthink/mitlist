package services

import (
	"context"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestRecipeScraping_JSONLD_ExtractsAllFields verifies full JSON-LD extraction.
func TestRecipeScraping_JSONLD_ExtractsAllFields(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head><title>Page Title</title></head>
<body>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Recipe",
  "name": "Chocolate Cake",
  "author": {"@type": "Person", "name": "Alice Baker"},
  "aggregateRating": {"ratingValue": "4.8", "ratingCount": "123"},
  "nutrition": {"@type": "NutritionInformation", "calories": "300 kcal"},
  "video": {"@type": "VideoObject", "contentUrl": "https://example.com/video.mp4"},
  "recipeIngredient": ["2 cups flour", "1 cup sugar", "3 eggs"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Mix dry ingredients."},
    {"@type": "HowToStep", "text": "Add wet ingredients."}
  ],
  "prepTime": "PT15M",
  "cookTime": "PT30M",
  "recipeYield": "8 servings",
  "image": ["https://example.com/img1.jpg", "https://example.com/img2.jpg"],
  "keywords": "cake, chocolate, dessert"
}
</script>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	assert.Equal(t, "Chocolate Cake", r.Title)
	assert.Equal(t, "Alice Baker", r.Author)
	assert.InDelta(t, 4.8, r.RatingValue, 0.01)
	assert.Equal(t, 123, r.RatingCount)
	assert.Equal(t, "300 kcal", r.Nutrition["calories"])
	assert.Equal(t, "https://example.com/video.mp4", r.VideoURL)
	assert.Len(t, r.Ingredients, 3)
	assert.Equal(t, "2 cups flour", r.Ingredients[0].RawText)
	assert.True(t, strings.Contains(r.InstructionsMD, "Mix dry ingredients"))
	assert.Equal(t, 15, *r.PrepTimeMinutes)
	assert.Equal(t, 30, *r.CookTimeMinutes)
	assert.Equal(t, "8 servings", *r.Servings)
	assert.Len(t, r.ImageOptions, 2)
	assert.Contains(t, r.Tags, "cake")
}

// TestRecipeScraping_Microdata_ExtractsFields verifies microdata extraction.
func TestRecipeScraping_Microdata_ExtractsFields(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Vanilla Cupcakes</h1>
  <span itemprop="author">Bob Baker</span>
  <ul>
    <li itemprop="recipeIngredient">1 cup flour</li>
    <li itemprop="recipeIngredient">1/2 cup butter</li>
  </ul>
  <div itemprop="recipeInstructions">
    <p>Preheat oven.</p>
    <p>Mix batter.</p>
  </div>
  <meta itemprop="prepTime" content="PT10M">
  <meta itemprop="cookTime" content="PT20M">
  <img itemprop="image" src="https://example.com/cupcake.jpg">
</div>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	assert.Equal(t, "Vanilla Cupcakes", r.Title)
	assert.Equal(t, "Bob Baker", r.Author)
	assert.Len(t, r.Ingredients, 2)
	assert.Equal(t, "1 cup flour", r.Ingredients[0].RawText)
	assert.True(t, strings.Contains(r.InstructionsMD, "Preheat oven"))
	assert.Equal(t, 10, *r.PrepTimeMinutes)
	assert.Equal(t, 20, *r.CookTimeMinutes)
}

// TestRecipeScraping_OpenGraph_Fallback verifies OpenGraph meta fallback.
func TestRecipeScraping_OpenGraph_Fallback(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="OG Pancakes">
  <meta property="og:description" content="Fluffy pancakes recipe">
  <meta property="og:image" content="https://example.com/pancakes.jpg">
</head>
<body>
<h1>Pancakes</h1>
<ul>
  <li>1 cup flour</li>
  <li>1 egg</li>
</ul>
<ol>
  <li>Mix ingredients.</li>
  <li>Cook on griddle.</li>
</ol>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	assert.Equal(t, "OG Pancakes", r.Title)
	assert.Equal(t, "Fluffy pancakes recipe", r.Description)
	assert.Len(t, r.Ingredients, 2)
	assert.Len(t, r.ImageOptions, 1)
	assert.Equal(t, "https://example.com/pancakes.jpg", r.ImageOptions[0])
}

// TestRecipeScraping_MergeTiers verifies that multiple tiers merge correctly.
func TestRecipeScraping_MergeTiers(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="OG Title">
  <meta property="og:image" content="https://example.com/og.jpg">
</head>
<body>
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "JSON-LD Title",
  "recipeIngredient": ["1 apple"],
  "recipeInstructions": [{"text": "Eat."}]
}
</script>
<h1>Heuristic Title</h1>
<ul><li>1 banana</li></ul>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	// JSON-LD title should win over OG and heuristic.
	assert.Equal(t, "JSON-LD Title", r.Title)
	// JSON-LD ingredient should win.
	assert.Len(t, r.Ingredients, 1)
	assert.Equal(t, "1 apple", r.Ingredients[0].RawText)
	// OG image should still be picked up if JSON-LD has none.
	assert.Len(t, r.ImageOptions, 1)
}

// TestRecipeScraping_MalformedJSONLD_HandledGracefully verifies graceful handling of malformed JSON-LD.
func TestRecipeScraping_MalformedJSONLD_HandledGracefully(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script type="application/ld+json">
{ this is not valid json }
</script>
<h1>Fallback Soup</h1>
<ul><li>2 carrots</li><li>1 onion</li></ul>
<ol><li>Chop vegetables.</li><li>Boil.</li></ol>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	assert.Equal(t, "Fallback Soup", r.Title)
	assert.Len(t, r.Ingredients, 2)
	assert.True(t, strings.Contains(r.InstructionsMD, "Chop vegetables"))
}

// TestRecipeScraping_IngredientParser verifies ingredient parsing edge cases.
func TestRecipeScraping_IngredientParser(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Parser Test</h1>
  <ul>
    <li itemprop="recipeIngredient">1 1/2 cups flour</li>
    <li itemprop="recipeIngredient">3/4 tsp salt</li>
    <li itemprop="recipeIngredient">2 eggs</li>
    <li itemprop="recipeIngredient">a pinch of pepper</li>
  </ul>
  <div itemprop="recipeInstructions"><p>Mix.</p></div>
</div>
</body>
</html>`

	r, err := svc.ScrapeRecipe(context.Background(), "data:text/html,"+html)
	require.NoError(t, err)
	require.Len(t, r.Ingredients, 4)
	assert.Equal(t, "1 1/2 cups flour", r.Ingredients[0].RawText)
	assert.Equal(t, "3/4 tsp salt", r.Ingredients[1].RawText)
	assert.Equal(t, "2 eggs", r.Ingredients[2].RawText)
	assert.Equal(t, "a pinch of pepper", r.Ingredients[3].RawText)
}
