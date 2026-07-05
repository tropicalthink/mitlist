package services

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHeuristicParser_Name(t *testing.T) {
	assert.Equal(t, "heuristic", heuristicParser{}.name())
}

// TestHeuristicParser_PluginSelectors exercises the highest-precision
// heuristic path (recipe-card plugin CSS selectors) in isolation.
func TestHeuristicParser_PluginSelectors(t *testing.T) {
	doc := mustParseDoc(t, `
<html>
<head><meta property="og:title" content="Plugin Pasta"></head>
<body>
<ul>
  <li class="wprm-recipe-ingredient">200 g spaghetti</li>
  <li class="wprm-recipe-ingredient">2 cloves garlic</li>
</ul>
<div>
  <p class="wprm-recipe-instruction-text">Boil the spaghetti until al dente.</p>
  <p class="wprm-recipe-instruction-text">Toss with garlic and olive oil.</p>
</div>
</body></html>`)

	out := heuristicParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Plugin Pasta", r.Title)
	require.Len(t, r.Ingredients, 2)
	assert.Equal(t, "200 g spaghetti", r.Ingredients[0].RawText)
	assert.Contains(t, r.InstructionsMD, "Boil the spaghetti")
	assert.Contains(t, r.InstructionsMD, "Toss with garlic")
}

// TestHeuristicParser_GenericFallback exercises the generic class-hint and
// ordered-list fallbacks with no plugin markup at all.
func TestHeuristicParser_GenericFallback(t *testing.T) {
	doc := mustParseDoc(t, `
<html><body>
<h1>Plain Pancakes</h1>
<div class="ingredients"><ul><li>1 cup flour</li><li>1 egg</li></ul></div>
<ol><li>Mix all the ingredients together.</li><li>Cook on a hot griddle.</li></ol>
</body></html>`)

	out := heuristicParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	r := out[0]
	assert.Equal(t, "Plain Pancakes", r.Title)
	require.Len(t, r.Ingredients, 2)
	assert.Contains(t, r.InstructionsMD, "Mix all the ingredients")
}

// TestHeuristicParser_AlwaysReturnsCandidate documents that this tier always
// yields exactly one candidate (possibly unusable); the isUsable gate in
// scrapeHTML is what filters it out for empty pages.
func TestHeuristicParser_AlwaysReturnsCandidate(t *testing.T) {
	doc := mustParseDoc(t, `<html><head><title>Empty</title></head><body></body></html>`)

	out := heuristicParser{}.parse(doc, "https://example.com/r")
	require.Len(t, out, 1)
	assert.False(t, isUsable(out[0]))
}
