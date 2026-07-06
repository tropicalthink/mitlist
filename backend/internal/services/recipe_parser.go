package services

import (
	"github.com/PuerkitoBio/goquery"
)

// recipeParser is a single extraction strategy tried against a parsed HTML
// document. Strategies are pure functions of (doc, pageURL): none of the
// built-in strategies read or mutate RecipeScrapingService state, so they
// are implemented as stateless value types rather than service methods.
//
// A strategy may find zero, one, or several candidate recipes on a page
// (e.g. a page can embed more than one JSON-LD Recipe object); each
// candidate is independently gated by isUsable and scored by
// completenessScore, then folded together by mergeTierResults.
type recipeParser interface {
	// name identifies the tier for tierResult bookkeeping.
	name() string
	// parse extracts zero or more recipe candidates from doc. It never
	// returns an error: unusable/malformed input simply yields no
	// candidates.
	parse(doc *goquery.Document, pageURL string) []RecipeClipResponse
}
