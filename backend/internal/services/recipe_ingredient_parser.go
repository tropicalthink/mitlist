package services

import (
	"regexp"
	"strings"

	"github.com/mitlist-app/mitlist/pkg/parsing"
)

// ------------------------------------------------------------------
// Ingredient parsing
//
// Shared by the structured-data tiers (via dedupeIngredients) and the
// heuristic tier, which both need to turn a raw ingredient line into
// quantity/unit/name.
// ------------------------------------------------------------------

var ingredientUnits = []string{
	// English
	"cups", "cup", "tablespoons", "tablespoon", "tbsp", "teaspoons", "teaspoon", "tsp",
	"ounces", "ounce", "oz", "pounds", "pound", "lbs", "lb",
	"grams", "gram", "g", "kilograms", "kilogram", "kg", "milligrams", "mg",
	"milliliters", "milliliter", "ml", "liters", "liter", "l", "cl", "dl",
	"cloves", "clove", "slices", "slice", "pieces", "piece", "pinches", "pinch",
	"bunches", "bunch", "sprigs", "sprig", "leaves", "leaf", "stalks", "stalk",
	"cans", "can", "packages", "package", "packs", "pack", "containers", "container",
	"heads", "head", "bulbs", "bulb", "ears", "ear", "strips", "strip",
	"sticks", "stick", "dashes", "dash", "handfuls", "handful", "knobs", "knob",
	"fillets", "fillet", "sheets", "sheet", "jars", "jar", "bottles", "bottle",
	// German
	"el", "tl", "esslöffel", "teelöffel", "stück", "stücke", "messerspitze",
	"bund", "bunde", "zweig", "zweige", "scheibe", "scheiben", "dose", "dosen",
	"packung", "packungen", "päckchen", "flasche", "flaschen", "glas", "gläser",
	"prise", "prisen", "zehe", "zehen", "blatt", "blätter", "becher",
	// French
	"cuillère", "cuilleres", "cuillères", "cas", "café",
	"sachet", "sachets", "boîte", "boite", "boîtes",
	"feuille", "feuilles", "gousse", "gousses", "brin", "brins",
	"pincée", "pincees", "verre", "verres", "tranche", "tranches",
	// Spanish
	"cucharadas", "cucharada", "cucharaditas", "cucharadita",
	"tazas", "taza", "puñado", "puñados", "rodaja", "rodajas",
	"diente", "dientes", "ramita", "ramitas", "lata", "latas",
	"pizca", "pizcas", "vaso", "vasos",
}

// prepPhrasesRe matches trailing preparation notes in any supported language.
// These are stripped from the ingredient name, keeping only the bare noun.
var prepPhrasesRe = regexp.MustCompile(
	`(?i)[,;]\s*.+$|` + // anything after comma/semicolon (e.g. ", sifted", "; finely chopped")
		`\s*\(.*?\)\s*$|` + // parenthetical notes at end (e.g. "(drained)")
		`\s+(?:` +
		// EN prep words
		`chopped|minced|diced|sliced|grated|shredded|peeled|crushed|ground|sifted|` +
		`softened|melted|beaten|cooked|fresh|dried|frozen|optional|divided|halved|quartered|` +
		// DE prep words
		`gehackt|gewürfelt|geschnitten|gerieben|geschält|zerdrückt|gemahlen|gesiegt|` +
		`weich|geschmolzen|getrocknet|tiefgekühlt|frisch|` +
		// FR prep words
		`haché|hachée|coupé|coupée|râpé|râpée|épluché|épluchée|écrasé|écrasée|` +
		`moulu|moulue|tamisé|tamisée|fondu|fondue|frais|fraîche|séché|séchée|` +
		// ES prep words
		`picado|picada|cortado|cortada|rallado|rallada|pelado|pelada|` +
		`molido|molida|tamizado|tamizada|derretido|derretida|fresco|fresca|seco|seca` +
		`)(?:\s+\w+)*$`,
)

var (
	leadingBulletRe = regexp.MustCompile(`^[\s\-–—•*▢☐☑✓✔►◦·]+`)
	// A single quantity token: "1", "1.5", "1,5", "1/2", "1 1/2", "1-1/2", "½", "1½".
	qtyToken          = `(?:\d+\s+\d+\s*/\s*\d+|\d+\s*-\s*\d+\s*/\s*\d+|\d+\s*/\s*\d+|\d+(?:[.,]\d+)?\s*[¼½¾⅓⅔⅛⅜⅝⅞]?|[¼½¾⅓⅔⅛⅜⅝⅞])`
	ingredientPartsRe = regexp.MustCompile(
		`^(?i)\(?\s*(` + qtyToken + `(?:\s*(?:-|–|—|to)\s*` + qtyToken + `)?)\s*\)?\s*(?:(` +
			strings.Join(ingredientUnits, `|`) + `)\b\.?)?\s*(.*)$`,
	)
)

// ParseIngredient extracts quantity, unit, and name from raw ingredient text.
// It handles formats like "2 cups flour", "1 1/2 tsp salt", "1½ cups milk",
// "1-2 cloves garlic", "▢ 3 eggs", and "2 tbsp. butter".
func ParseIngredient(raw string) RecipeClipIngredient {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return RecipeClipIngredient{RawText: raw}
	}

	result := RecipeClipIngredient{RawText: raw}
	work := strings.TrimSpace(leadingBulletRe.ReplaceAllString(raw, ""))
	if work == "" {
		work = raw
	}

	matches := ingredientPartsRe.FindStringSubmatch(work)
	if len(matches) == 4 {
		qtyStr := strings.TrimSpace(matches[1])
		unitStr := strings.TrimSpace(matches[2])
		nameStr := strings.TrimSpace(matches[3])

		if qtyStr != "" {
			// For ranges ("1-2", "1 to 2") parse the lower bound.
			lower := regexp.MustCompile(`(?i)\s*(?:–|—|to)\s*`).Split(qtyStr, 2)[0]
			result.Quantity = parsing.ParseIngredientAmount(lower)
		}
		if unitStr != "" {
			result.Unit = strings.ToLower(unitStr)
		}
		if nameStr != "" {
			name := strings.TrimPrefix(nameStr, "of ")
			// Also strip "de " prefix used in FR/ES ("de aceite" → "aceite")
			name = strings.TrimPrefix(name, "de ")
			name = strings.TrimSpace(name)
			// Strip trailing prep phrases and parenthetical notes.
			name = strings.TrimSpace(prepPhrasesRe.ReplaceAllString(name, ""))
			result.Name = name
		}
	}

	if result.Name == "" {
		result.Name = work
	}

	return result
}
