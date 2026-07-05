package services

import (
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"

	"github.com/PuerkitoBio/goquery"
)

// ------------------------------------------------------------------
// Tier 5: heuristic extraction
// ------------------------------------------------------------------

var (
	// Fractions/quantities (language-agnostic). We include common unicode fractions
	// as literal runes because Go's regexp does not support \uXXXX escapes.
	fractionRe         = regexp.MustCompile(`[¼½¾⅓⅔⅛⅜⅝⅞]|\b\d+\s*/\s*\d+\b|\b\d+[.,]\d+\b|\b\d+\b`)
	ingredientClassRe  = regexp.MustCompile(`(?i)ingredi|zutat|ingrédient|składnik|ingrediens`)
	instructionClassRe = regexp.MustCompile(`(?i)instruct|direction|\bstep\b|method|preparat|procedure|étape|schritt|istruz|\bpaso\b|\bstap\b|\bkrok\b`)
)

// Selectors emitted by the dominant recipe-card plugins (WP Recipe Maker,
// Tasty Recipes, Mediavine Create, EasyRecipe, Simple Recipe Pro, and the
// Dotdash/Serious Eats structured markup). These are the highest-precision
// heuristic signals, so they run before the generic class scan.
var pluginIngredientSelectors = []string{
	".wprm-recipe-ingredient",
	".tasty-recipes-ingredients li",
	".tasty-recipe-ingredients li",
	".mv-create-ingredients li",
	".easyrecipe .ingredient",
	".srp-recipe-ingredients li",
	".structured-ingredients__list-item",
	"[data-ingredient-name]",
}

var pluginInstructionSelectors = []string{
	".wprm-recipe-instruction-text",
	".tasty-recipes-instructions li",
	".tasty-recipe-instructions li",
	".mv-create-instructions li",
	".easyrecipe .instruction",
	".srp-recipe-instructions li",
	"#structured-project__steps_1-0 li",
	".comp.mntl-sc-block-startgroup li",
}

var universalUnits = []string{
	"g", "kg", "mg", "ml", "cl", "dl", "l",
	"oz", "lb", "lbs", "tsp", "tbsp", "cup", "cups", "pt", "qt",
}

func extractHeuristic(doc *goquery.Document, pageURL string) RecipeClipResponse {
	title := extractTitleHeuristic(doc)
	imageOptions := extractImageHeuristic(doc, pageURL)

	ingredientNodes := findNodesBySelectors(doc, pluginIngredientSelectors)
	if len(ingredientNodes) == 0 {
		ingredientNodes = findNodesByClassHint(doc, ingredientClassRe, "li")
	}
	if len(ingredientNodes) == 0 {
		ingredientNodes = findIngredientLiCandidates(doc)
	}

	instructionNodes := findNodesBySelectors(doc, pluginInstructionSelectors)
	if len(instructionNodes) == 0 {
		instructionNodes = findNodesByClassHint(doc, instructionClassRe, "li,p")
	}
	if len(instructionNodes) == 0 {
		instructionNodes = findAllOlItems(doc)
	}

	ingredients := extractIngredientsFromSelections(ingredientNodes)
	instructions := extractInstructionsFromSelections(instructionNodes)
	servings := extractServingsHeuristic(doc)
	description := extractDescriptionHeuristic(doc)
	author := extractAuthorHeuristic(doc)
	ratingValue, ratingCount := extractRatingHeuristic(doc)
	prep, cook := extractTimesHeuristic(doc)

	var imageURL *string
	if len(imageOptions) > 0 {
		imageURL = &imageOptions[0]
	}

	return RecipeClipResponse{
		Title:           title,
		SourceURL:       pageURL,
		Description:     description,
		Author:          author,
		RatingValue:     ratingValue,
		RatingCount:     ratingCount,
		InstructionsMD:  instructions,
		PrepTimeMinutes: prep,
		CookTimeMinutes: cook,
		Servings:        servings,
		Ingredients:     ingredients,
		ImageURL:        imageURL,
		ImageOptions:    imageOptions,
		Tags:            nil,
	}
}

func findNodesBySelectors(doc *goquery.Document, selectors []string) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}
	for _, selector := range selectors {
		doc.Find(selector).Each(func(_ int, sel *goquery.Selection) {
			t := strings.TrimSpace(sel.Text())
			if t == "" {
				return
			}
			if _, ok := seenText[t]; ok {
				return
			}
			seenText[t] = struct{}{}
			out = append(out, sel)
		})
		// One plugin per page; the first selector family that matches wins.
		if len(out) > 0 {
			break
		}
	}
	return out
}

func extractDescriptionHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="og:description"]`,
		`meta[name="twitter:description"]`,
		`meta[property="twitter:description"]`,
		`meta[name="description"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	return ""
}

func extractTitleHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="og:title"]`,
		`meta[name="twitter:title"]`,
		`meta[property="twitter:title"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	if t := strings.TrimSpace(doc.Find("h1").First().Text()); t != "" {
		return t
	}
	if t := strings.TrimSpace(doc.Find("title").First().Text()); t != "" {
		return t
	}
	return "Untitled Recipe"
}

// largestSrcsetCandidate picks the URL with the biggest width descriptor.
func largestSrcsetCandidate(srcset string) string {
	best := ""
	bestW := -1
	for _, part := range strings.Split(srcset, ",") {
		fields := strings.Fields(strings.TrimSpace(part))
		if len(fields) == 0 {
			continue
		}
		w := 0
		if len(fields) > 1 {
			d := fields[1]
			if strings.HasSuffix(d, "w") || strings.HasSuffix(d, "x") {
				w = parseDimension(d)
			}
		}
		if w > bestW {
			bestW = w
			best = fields[0]
		}
	}
	return best
}

// imgCandidateSrc handles lazy-loading attributes and srcset.
func imgCandidateSrc(sel *goquery.Selection) string {
	for _, attr := range []string{"src", "data-src", "data-lazy-src", "data-original"} {
		if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" && !strings.HasPrefix(v, "data:") {
			return strings.TrimSpace(v)
		}
	}
	for _, attr := range []string{"srcset", "data-srcset", "data-lazy-srcset"} {
		if v, ok := sel.Attr(attr); ok && strings.TrimSpace(v) != "" {
			if c := largestSrcsetCandidate(v); c != "" && !strings.HasPrefix(c, "data:") {
				return c
			}
		}
	}
	return ""
}

func extractImageHeuristic(doc *goquery.Document, pageURL string) []string {
	out := []string{}
	for _, sel := range []string{
		`meta[property="og:image"]`,
		`meta[property="og:image:secure_url"]`,
		`meta[name="twitter:image"]`,
		`meta[property="twitter:image"]`,
		`meta[name="twitter:image:src"]`,
		`meta[property="twitter:image:src"]`,
	} {
		doc.Find(sel).Each(func(_ int, m *goquery.Selection) {
			if v, ok := m.Attr("content"); ok {
				if t := strings.TrimSpace(v); t != "" {
					u := resolveURL(pageURL, t)
					if !containsString(out, u) {
						out = append(out, u)
					}
				}
			}
		})
	}
	if v, ok := doc.Find(`link[rel="image_src"]`).Attr("href"); ok {
		if t := strings.TrimSpace(v); t != "" {
			u := resolveURL(pageURL, t)
			if !containsString(out, u) {
				out = append(out, u)
			}
		}
	}

	type scored struct {
		score int
		url   string
	}
	cands := []scored{}
	doc.Find("img").Each(func(_ int, sel *goquery.Selection) {
		src := imgCandidateSrc(sel)
		if src == "" {
			return
		}

		full := resolveURL(pageURL, src)
		if containsString(out, full) {
			return
		}

		score := 0
		if w, ok := sel.Attr("width"); ok {
			if h, ok2 := sel.Attr("height"); ok2 {
				ww := parseDimension(w)
				hh := parseDimension(h)
				if ww > 0 && hh > 0 {
					if ww < 150 || hh < 150 {
						score -= 50
					} else {
						score += min((ww*hh)/10000, 50)
					}
				}
			}
		}
		if alt, ok := sel.Attr("alt"); ok {
			a := strings.ToLower(alt)
			if strings.Contains(strings.ToLower(src), "recipe") || strings.Contains(a, "recipe") ||
				strings.Contains(strings.ToLower(src), "food") || strings.Contains(a, "food") ||
				strings.Contains(strings.ToLower(src), "dish") || strings.Contains(a, "dish") {
				score += 20
			}
		}
		if class, ok := sel.Attr("class"); ok {
			c := strings.ToLower(class)
			if strings.Contains(c, "wprm-recipe-image") || strings.Contains(c, "tasty-recipes-image") ||
				strings.Contains(c, "recipe-image") || strings.Contains(c, "hero") {
				score += 30
			}
		}
		if score > 0 {
			cands = append(cands, scored{score: score, url: full})
		}
	})
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
	for _, c := range cands {
		out = append(out, c.url)
		if len(out) >= 10 {
			break
		}
	}
	return dedupeStrings(out)
}

func parseDimension(s string) int {
	s = regexp.MustCompile(`[^0-9]`).ReplaceAllString(s, "")
	if s == "" {
		return 0
	}
	n, _ := strconv.Atoi(s)
	return n
}

func resolveURL(base, raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return raw
	}
	if u.Scheme != "" {
		return u.String()
	}
	b, err := url.Parse(base)
	if err != nil {
		return raw
	}
	return b.ResolveReference(u).String()
}

func findNodesByClassHint(doc *goquery.Document, re *regexp.Regexp, selector string) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}

	doc.Find("*").Each(func(_ int, sel *goquery.Selection) {
		class, _ := sel.Attr("class")
		id, _ := sel.Attr("id")
		target := strings.TrimSpace(class + " " + id)
		if target == "" || !re.MatchString(target) {
			return
		}
		sel.Find(selector).Each(func(_ int, child *goquery.Selection) {
			t := strings.TrimSpace(child.Text())
			if t == "" {
				return
			}
			if _, ok := seenText[t]; ok {
				return
			}
			seenText[t] = struct{}{}
			out = append(out, child)
		})
	})
	return out
}

func findIngredientLiCandidates(doc *goquery.Document) []*goquery.Selection {
	type cand struct {
		score int
		sel   *goquery.Selection
	}
	cands := []cand{}
	seenText := map[string]struct{}{}

	doc.Find("li").Each(func(_ int, sel *goquery.Selection) {
		text := strings.TrimSpace(sel.Text())
		if text == "" || len(text) > 200 {
			return
		}
		if _, ok := seenText[text]; ok {
			return
		}
		score := scoreIngredientText(text)
		if score > 20 {
			seenText[text] = struct{}{}
			cands = append(cands, cand{score: score, sel: sel})
		}
	})
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].score > cands[j].score })
	out := []*goquery.Selection{}
	for i := 0; i < len(cands) && i < 30; i++ {
		out = append(out, cands[i].sel)
	}
	return out
}

func findAllOlItems(doc *goquery.Document) []*goquery.Selection {
	out := []*goquery.Selection{}
	seenText := map[string]struct{}{}
	doc.Find("ol li").Each(func(_ int, sel *goquery.Selection) {
		text := strings.TrimSpace(sel.Text())
		if text == "" || len(text) < 15 {
			return
		}
		if _, ok := seenText[text]; ok {
			return
		}
		seenText[text] = struct{}{}
		out = append(out, sel)
	})
	return out
}

func extractIngredientsFromSelections(nodes []*goquery.Selection) []RecipeClipIngredient {
	out := []RecipeClipIngredient{}
	seen := map[string]struct{}{}
	for _, sel := range nodes {
		t := strings.TrimSpace(sel.Text())
		if t == "" || len(t) > 200 {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		out = append(out, ParseIngredient(t))
	}
	return out
}

func extractInstructionsFromSelections(nodes []*goquery.Selection) string {
	parts := []string{}
	seen := map[string]struct{}{}
	for _, sel := range nodes {
		t := strings.TrimSpace(sel.Text())
		if t == "" || len(t) < 15 {
			continue
		}
		if _, ok := seen[t]; ok {
			continue
		}
		seen[t] = struct{}{}
		parts = append(parts, t)
	}
	return strings.Join(parts, "\n\n")
}

func extractAuthorHeuristic(doc *goquery.Document) string {
	for _, sel := range []string{
		`meta[property="article:author"]`,
		`meta[name="twitter:creator"]`,
		`meta[property="twitter:creator"]`,
		`meta[name="author"]`,
	} {
		if v, ok := doc.Find(sel).Attr("content"); ok {
			if t := strings.TrimSpace(v); t != "" {
				return t
			}
		}
	}
	// Try common author class/id patterns.
	found := ""
	doc.Find("[class*='author'],[class*='byline'],[id*='author'],[id*='byline']").EachWithBreak(func(_ int, sel *goquery.Selection) bool {
		t := strings.TrimSpace(sel.Text())
		if t != "" && len(t) < 100 {
			found = strings.TrimSpace(strings.TrimPrefix(strings.TrimPrefix(t, "By "), "by "))
			return false
		}
		return true
	})
	return found
}

func extractRatingHeuristic(doc *goquery.Document) (float64, int) {
	text := doc.Text()
	// Look for patterns like "4.5 stars", "Rating: 4.5 (123 votes)", "4.5/5"
	patterns := []string{
		`(?i)(?:rating|rated?)[:\s]*(\d+(?:\.\d+)?)\s*(?:/\s*5)?\s*(?:stars?)?\s*\(?\s*(\d+)\s*(?:votes?|reviews?|ratings?)?\s*\)?`,
		`(?i)(\d+(?:\.\d+)?)\s*(?:out of|\/)\s*5\s*(?:stars?)?\s*\(?\s*(\d+)\s*(?:votes?|reviews?|ratings?)?\s*\)?`,
		`(?i)(\d+(?:\.\d+)?)\s*\/?\s*5\s*stars?`,
	}
	for _, p := range patterns {
		re := regexp.MustCompile(p)
		if m := re.FindStringSubmatch(text); len(m) >= 2 {
			val, _ := strconv.ParseFloat(strings.TrimSpace(m[1]), 64)
			count := 0
			if len(m) >= 3 {
				count, _ = strconv.Atoi(strings.TrimSpace(m[2]))
			}
			if val > 0 && val <= 5 {
				return val, count
			}
		}
	}
	return 0, 0
}

func extractTimesHeuristic(doc *goquery.Document) (*int, *int) {
	text := doc.Text()
	var prep, cook *int

	// ISO-like in text: PT15M
	isoRe := regexp.MustCompile(`(?i)prep(?:aration)?\s*time[:\s]*PT(?:(\d+)H)?(?:(\d+)M)?`)
	if m := isoRe.FindStringSubmatch(text); len(m) >= 3 {
		h := atoi0(m[1])
		mins := atoi0(m[2])
		if h > 0 || mins > 0 {
			v := h*60 + mins
			prep = &v
		}
	}

	isoCookRe := regexp.MustCompile(`(?i)cook(?:ing)?\s*time[:\s]*PT(?:(\d+)H)?(?:(\d+)M)?`)
	if m := isoCookRe.FindStringSubmatch(text); len(m) >= 3 {
		h := atoi0(m[1])
		mins := atoi0(m[2])
		if h > 0 || mins > 0 {
			v := h*60 + mins
			cook = &v
		}
	}

	// Plain text: "Prep: 15 mins", "Cook time: 30 minutes", "Prep time: 1 hour 20 minutes"
	if prep == nil {
		re := regexp.MustCompile(`(?i)(?:prep(?:aration)?\s*time|prep)[:\s]*(?:(\d+)\s*(?:hours?|hrs?|h)\s*)?(\d+)?(?:\s*-\s*\d+)?\s*(?:min|mins|minutes?)`)
		if m := re.FindStringSubmatch(text); len(m) >= 3 {
			v := atoi0(m[1])*60 + atoi0(m[2])
			if v > 0 {
				prep = &v
			}
		}
	}
	if cook == nil {
		re := regexp.MustCompile(`(?i)(?:cook(?:ing)?\s*time|cook)[:\s]*(?:(\d+)\s*(?:hours?|hrs?|h)\s*)?(\d+)?(?:\s*-\s*\d+)?\s*(?:min|mins|minutes?)`)
		if m := re.FindStringSubmatch(text); len(m) >= 3 {
			v := atoi0(m[1])*60 + atoi0(m[2])
			if v > 0 {
				cook = &v
			}
		}
	}

	return prep, cook
}

func extractServingsHeuristic(doc *goquery.Document) *string {
	text := doc.Text()
	patterns := []string{
		`(?i)(?:serves?|servings?|makes?|yields?)[:\s]*(\d+(?:\s*-\s*\d+)?)`,
		`(?i)(\d+(?:\s*-\s*\d+)?)\s*(?:servings?|portions?|people?)`,
	}
	for _, p := range patterns {
		re := regexp.MustCompile(p)
		if m := re.FindStringSubmatch(text); len(m) >= 2 {
			v := strings.TrimSpace(m[1])
			if v != "" {
				return &v
			}
		}
	}
	return nil
}

func scoreIngredientText(text string) int {
	score := 0
	if len(text) < 60 {
		score += 20
	} else if len(text) < 120 {
		score += 10
	}
	if fractionRe.MatchString(text) {
		score += 30
	}
	lower := strings.ToLower(text)
	for _, unit := range universalUnits {
		// Go regex (RE2) doesn't support lookbehind. Approximate word boundaries:
		// unit must be separated by non-word chars (or edges).
		re := regexp.MustCompile(`(^|[^A-Za-z0-9_])` + regexp.QuoteMeta(unit) + `([^A-Za-z0-9_]|$)`)
		if re.MatchString(lower) {
			score += 20
			break
		}
	}
	score -= len(regexp.MustCompile(`[.!?]`).FindAllString(text, -1)) * 8
	if len(text) > 200 {
		score -= 30
	}
	if score < 0 {
		return 0
	}
	return score
}

// heuristicParser implements recipeParser as the last-resort, gap-filling
// tier: meta tags, recipe-plugin CSS selectors, and generic class/text
// scoring. Always runs, and unlike the structured-data tiers is expected to
// sometimes return a low-quality candidate rather than none at all.
type heuristicParser struct{}

func (heuristicParser) name() string { return "heuristic" }

func (heuristicParser) parse(doc *goquery.Document, pageURL string) []RecipeClipResponse {
	return []RecipeClipResponse{extractHeuristic(doc, pageURL)}
}
