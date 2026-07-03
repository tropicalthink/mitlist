package services

import (
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
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

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	require.Len(t, r.Ingredients, 4)
	assert.Equal(t, "1 1/2 cups flour", r.Ingredients[0].RawText)
	assert.Equal(t, "3/4 tsp salt", r.Ingredients[1].RawText)
	assert.Equal(t, "2 eggs", r.Ingredients[2].RawText)
	assert.Equal(t, "a pinch of pepper", r.Ingredients[3].RawText)
}

// ------------------------------------------------------------------
// Regression fixtures
// ------------------------------------------------------------------

// TestRecipeScraping_JSONLD_Graph extracts recipe nested in @graph.
func TestRecipeScraping_JSONLD_Graph(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head><title>Page</title></head>
<body>
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {"@type": "WebPage", "name": "Page"},
    {
      "@type": "Recipe",
      "name": "Graph Cake",
      "recipeIngredient": ["2 cups flour"],
      "recipeInstructions": [{"@type": "HowToStep", "text": "Bake."}]
    }
  ]
}
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Graph Cake", r.Title)
	assert.Len(t, r.Ingredients, 1)
}

// TestRecipeScraping_JSONLD_HTMLComments strips comments inside script.
func TestRecipeScraping_JSONLD_HTMLComments(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script type="application/ld+json">
<!--
{
  "@type": "Recipe",
  "name": "Comment Soup",
  "recipeIngredient": ["1 carrot"],
  "recipeInstructions": ["Boil."]
}
-->
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Comment Soup", r.Title)
	assert.Len(t, r.Ingredients, 1)
}

// TestRecipeScraping_JSONLD_PartialExtraction falls back to heuristic when ingredients missing.
func TestRecipeScraping_JSONLD_PartialExtraction(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Partial Title">
</head>
<body>
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "Partial Recipe",
  "recipeInstructions": [{"text": "Stir continuously over medium heat for five minutes."}],
  "image": "https://example.com/img.jpg"
}
</script>
<ul><li>1 onion</li></ul>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	// JSON-LD has an image and long instructions, so it wins on completeness.
	assert.Equal(t, "Partial Recipe", r.Title)
	assert.True(t, len(r.Ingredients) > 0, "expected heuristic fallback ingredients")
}

// TestRecipeScraping_JSONLD_HowToSection handles HowToSection instructions.
func TestRecipeScraping_JSONLD_HowToSection(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "Section Pie",
  "recipeIngredient": ["1 crust"],
  "recipeInstructions": [
    {
      "@type": "HowToSection",
      "name": "Filling",
      "itemListElement": [
        {"@type": "HowToStep", "text": "Mix filling."},
        {"@type": "HowToStep", "text": "Pour."}
      ]
    }
  ]
}
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Section Pie", r.Title)
	assert.True(t, strings.Contains(r.InstructionsMD, "Mix filling."))
	assert.True(t, strings.Contains(r.InstructionsMD, "Pour."))
}

// TestRecipeScraping_JSONLD_StringInstructions splits newline-separated steps.
func TestRecipeScraping_JSONLD_StringInstructions(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "String Stew",
  "recipeIngredient": ["1 potato"],
  "recipeInstructions": "Peel potato.\nBoil water.\nCook until soft."
}
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "String Stew", r.Title)
	parts := strings.Split(r.InstructionsMD, "\n\n")
	assert.Len(t, parts, 3)
	assert.Equal(t, "Peel potato.", parts[0])
}

// TestRecipeScraping_JSONLD_RelativeImages resolves relative image URLs.
func TestRecipeScraping_JSONLD_RelativeImages(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "Relative Salad",
  "recipeIngredient": ["1 lettuce"],
  "recipeInstructions": ["Chop."],
  "image": "/images/salad.jpg"
}
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipes/salad")
	require.NoError(t, err)
	require.NotNil(t, r.ImageURL)
	assert.Equal(t, "https://example.com/images/salad.jpg", *r.ImageURL)
}

// TestRecipeScraping_Microdata_NestedScope extracts nested author scope.
func TestRecipeScraping_Microdata_NestedScope(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Nested Bread</h1>
  <div itemprop="author" itemscope itemtype="https://schema.org/Person">
    <span itemprop="name">Baker Bob</span>
  </div>
  <ul><li itemprop="recipeIngredient">2 cups flour</li></ul>
  <div itemprop="recipeInstructions"><p>Knead.</p></div>
</div>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Nested Bread", r.Title)
	assert.Equal(t, "Baker Bob", r.Author)
}

// TestRecipeScraping_OpenGraph_Only extracts from OpenGraph when no structured data exists.
func TestRecipeScraping_OpenGraph_Only(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="OG Only Soup">
  <meta property="og:description" content="A simple soup.">
  <meta property="og:image" content="https://example.com/soup.jpg">
  <meta property="article:author" content="Chef OG">
</head>
<body>
<h1>OG Only Soup</h1>
<ul><li>2 tomatoes</li><li>1 onion</li></ul>
<ol><li>Chop vegetables.</li><li>Simmer.</li></ol>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "OG Only Soup", r.Title)
	assert.Equal(t, "A simple soup.", r.Description)
	assert.Equal(t, "Chef OG", r.Author)
	assert.Len(t, r.Ingredients, 2)
	assert.True(t, strings.Contains(r.InstructionsMD, "Chop vegetables"))
	require.NotNil(t, r.ImageURL)
	assert.Equal(t, "https://example.com/soup.jpg", *r.ImageURL)
}

// TestRecipeScraping_TwitterCard_Fallback uses twitter:image when og:image is absent.
func TestRecipeScraping_TwitterCard_Fallback(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<head>
  <meta name="twitter:title" content="Twitter Tart">
  <meta name="twitter:description" content="Tasty tart.">
  <meta name="twitter:image" content="https://example.com/tart.jpg">
</head>
<body>
<h1>Twitter Tart</h1>
<ul><li>1 crust</li></ul>
<ol><li>Bake.</li></ol>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Twitter Tart", r.Title)
	assert.Equal(t, "Tasty tart.", r.Description)
	require.NotNil(t, r.ImageURL)
	assert.Equal(t, "https://example.com/tart.jpg", *r.ImageURL)
}

// TestRecipeScraping_Heuristic_Times extracts prep/cook from plain text.
func TestRecipeScraping_Heuristic_Times(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<h1>Text Timing</h1>
<p>Prep time: 10 minutes</p>
<p>Cooking time: 25 mins</p>
<ul><li>1 egg</li></ul>
<ol><li>Fry.</li></ol>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	require.NotNil(t, r.PrepTimeMinutes)
	assert.Equal(t, 10, *r.PrepTimeMinutes)
	require.NotNil(t, r.CookTimeMinutes)
	assert.Equal(t, 25, *r.CookTimeMinutes)
}

// TestRecipeScraping_Heuristic_Rating extracts rating from plain text.
func TestRecipeScraping_Heuristic_Rating(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<h1>Rated Dish</h1>
<p>Rating: 4.5 (123 votes)</p>
<ul><li>1 fish</li></ul>
<ol><li>Grill.</li></ol>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.InDelta(t, 4.5, r.RatingValue, 0.01)
	assert.Equal(t, 123, r.RatingCount)
}

// TestRecipeScraping_MalformedMicrodata_Recovers verifies recovery when microdata is broken.
func TestRecipeScraping_MalformedMicrodata_Recovers(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<div itemscope itemtype="https://schema.org/Recipe">
  <h1 itemprop="name">Broken Microdata</h1>
  <!-- missing closing tags intentionally not an issue for parser -->
  <ul>
    <li itemprop="recipeIngredient">1 tsp pepper</li>
  </ul>
</div>
<ol><li>Roast in the oven at 400F for 20 minutes.</li></ol>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Broken Microdata", r.Title)
	assert.True(t, len(r.Ingredients) > 0)
	assert.True(t, strings.Contains(r.InstructionsMD, "Roast in the oven"))
}

// TestRecipeScraping_EmptyPage_ReturnsError verifies empty pages fail gracefully.
func TestRecipeScraping_EmptyPage_ReturnsError(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `<!DOCTYPE html><html><head><title>Empty</title></head><body></body></html>`
	_, err := svc.scrapeHTML(html, "https://example.com/recipe")
	assert.Error(t, err)
}

// ------------------------------------------------------------------
// Characterization tests (plan 038): pin behavior of tiers not yet
// covered above, before any code is moved.
// ------------------------------------------------------------------

// TestRecipeScraping_RDFa_ExtractsFields verifies RDFa (typeof/property) extraction.
func TestRecipeScraping_RDFa_ExtractsFields(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<div typeof="schema:Recipe">
  <h1 property="schema:name">RDFa Roast</h1>
  <span property="schema:author">Chef RDFa</span>
  <ul>
    <li property="schema:recipeIngredient">2 lb chicken</li>
    <li property="schema:recipeIngredient">1 tbsp salt</li>
  </ul>
  <div property="schema:recipeInstructions">Roast at 400F for one hour.</div>
  <meta property="schema:prepTime" content="PT10M">
  <meta property="schema:cookTime" content="PT60M">
</div>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "RDFa Roast", r.Title)
	assert.Equal(t, "Chef RDFa", r.Author)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "2 lb chicken", r.Ingredients[0].RawText)
	assert.True(t, strings.Contains(r.InstructionsMD, "Roast at 400F"))
	require.NotNil(t, r.PrepTimeMinutes)
	assert.Equal(t, 10, *r.PrepTimeMinutes)
	require.NotNil(t, r.CookTimeMinutes)
	assert.Equal(t, 60, *r.CookTimeMinutes)
}

// TestRecipeScraping_EmbeddedJSON_NextData verifies extraction from a
// __NEXT_DATA__ hydration blob that has no explicit @type but has the
// recipeIngredient/recipeInstructions shape.
func TestRecipeScraping_EmbeddedJSON_NextData(t *testing.T) {
	svc := NewRecipeScrapingService()
	html := `
<!DOCTYPE html>
<html>
<body>
<script id="__NEXT_DATA__" type="application/json">
{"props":{"pageProps":{"recipe":{"name":"Next Data Bowl","recipeIngredient":["1 cup rice","2 cups water"],"recipeInstructions":["Rinse rice.","Cook rice."]}}}}
</script>
</body>
</html>`

	r, err := svc.scrapeHTML(html, "https://example.com/recipe")
	require.NoError(t, err)
	assert.Equal(t, "Next Data Bowl", r.Title)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "1 cup rice", r.Ingredients[0].RawText)
	assert.True(t, strings.Contains(r.InstructionsMD, "Rinse rice"))
}

// TestRecipeScraping_IsWeakResult pins the completeness gate that decides
// whether ScrapeRecipe attempts the AMP-variant fallback.
func TestRecipeScraping_IsWeakResult(t *testing.T) {
	assert.True(t, isWeakResult(nil))
	assert.True(t, isWeakResult(&RecipeClipResponse{}))
	assert.True(t, isWeakResult(&RecipeClipResponse{
		Ingredients: []RecipeClipIngredient{{RawText: "1 egg"}},
	}), "no instructions is still weak")
	assert.True(t, isWeakResult(&RecipeClipResponse{
		InstructionsMD: "Fry it.",
	}), "no ingredients is still weak")
	assert.False(t, isWeakResult(&RecipeClipResponse{
		Ingredients:    []RecipeClipIngredient{{RawText: "1 egg"}},
		InstructionsMD: "Fry it.",
	}))
}

// TestRecipeScraping_CompletenessScore_PrefersMoreComplete pins the ordering
// completenessScore imposes, which mergeTierResults and the AMP-fallback
// comparison both depend on.
func TestRecipeScraping_CompletenessScore_PrefersMoreComplete(t *testing.T) {
	sparse := RecipeClipResponse{
		Title:       "Untitled Recipe",
		Ingredients: []RecipeClipIngredient{{RawText: "1 egg"}},
	}
	richTitle := "Full Recipe"
	rich := RecipeClipResponse{
		Title:           richTitle,
		Ingredients:     []RecipeClipIngredient{{RawText: "1 egg"}, {RawText: "1 cup flour"}},
		InstructionsMD:  "Mix.\n\nBake for a while until golden brown and delicious.",
		PrepTimeMinutes: intPtr(10),
		CookTimeMinutes: intPtr(20),
		ImageURL:        strPtr("https://example.com/img.jpg"),
		Tags:            []string{"dessert"},
	}
	assert.Greater(t, completenessScore(rich), completenessScore(sparse))
}

func intPtr(v int) *int       { return &v }
func strPtr(v string) *string { return &v }

// TestIngredientParser_Multilingual verifies ParseIngredient across EN/DE/FR/ES.
func TestIngredientParser_Multilingual(t *testing.T) {
	cases := []struct {
		raw      string
		qty      float64
		unit     string
		name     string
	}{
		// English
		{"2 cups flour", 2, "cups", "flour"},
		{"1 cup all-purpose flour, sifted", 1, "cup", "all-purpose flour"},
		{"1 1/2 tsp salt", 1.5, "tsp", "salt"},
		{"3 cloves garlic, minced", 3, "cloves", "garlic"},
		{"200 g butter, softened", 200, "g", "butter"},
		// German
		{"200 g Mehl", 200, "g", "Mehl"},
		{"2 EL Olivenöl", 2, "el", "Olivenöl"},
		{"1 TL Salz", 1, "tl", "Salz"},
		{"3 Stück Kartoffeln, gehackt", 3, "stück", "Kartoffeln"},
		// French
		{"2 cuillères à soupe d'huile", 2, "cuillères", "à soupe d'huile"},
		{"1 gousse d'ail", 1, "gousse", "d'ail"},
		// Spanish
		{"2 cucharadas de aceite", 2, "cucharadas", "aceite"},
		{"1 taza de harina", 1, "taza", "harina"},
		{"3 dientes de ajo", 3, "dientes", "ajo"},
		// Bare name (no qty/unit)
		{"Salz", 0, "", "Salz"},
		// Empty
		{"", 0, "", ""},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.raw, func(t *testing.T) {
			got := ParseIngredient(tc.raw)
			assert.Equal(t, tc.raw, got.RawText, "RawText preserved")
			assert.InDelta(t, tc.qty, got.Quantity, 0.001, "Quantity")
			assert.Equal(t, tc.unit, got.Unit, "Unit")
			assert.Equal(t, tc.name, got.Name, "Name")
		})
	}
}

// TestIngredientParser_PrepPhraseStripping verifies trailing prep notes are removed.
func TestIngredientParser_PrepPhraseStripping(t *testing.T) {
	cases := []struct {
		raw  string
		name string
	}{
		{"1 cup flour, sifted", "flour"},
		{"2 cloves garlic, minced", "garlic"},
		{"100 g butter, softened", "butter"},
		{"200 g Mehl, gesiebt", "Mehl"},
		{"3 Stück Kartoffeln, gehackt", "Kartoffeln"},
		{"1 taza harina tamizada", "harina"},
		{"1 cup sugar (optional)", "sugar"},
	}
	for _, tc := range cases {
		tc := tc
		t.Run(tc.raw, func(t *testing.T) {
			got := ParseIngredient(tc.raw)
			assert.Equal(t, tc.name, got.Name, "Name after prep strip")
		})
	}
}

// TestIngredientParser_NeverPanics confirms ParseIngredient is total (no panics).
func TestIngredientParser_NeverPanics(t *testing.T) {
	inputs := []string{
		"", " ", "   ", "½", "¼ tsp", "a", "some flour",
		"1-2 cloves garlic", "3 to 4 cups milk",
	}
	for _, raw := range inputs {
		raw := raw
		t.Run(raw, func(t *testing.T) {
			assert.NotPanics(t, func() { ParseIngredient(raw) })
		})
	}
}
