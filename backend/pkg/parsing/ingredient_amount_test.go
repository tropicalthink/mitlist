package parsing

import (
	"math"
	"testing"
)

func TestParseIngredientAmount(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected float64
	}{
		{name: "empty string", input: "", expected: 1},
		{name: "simple integer", input: "2", expected: 2},
		{name: "simple float", input: "1.5", expected: 1.5},
		{name: "comma decimal", input: "1,5", expected: 1.5},
		{name: "with unit cups", input: "2 cups flour", expected: 2},
		{name: "with unit tbsp", input: "3 tbsp sugar", expected: 3},
		{name: "simple fraction 1/2", input: "1/2 cup milk", expected: 0.5},
		{name: "simple fraction 3/4", input: "3/4 tsp salt", expected: 0.75},
		{name: "mixed number 1 1/2", input: "1 1/2 cups flour", expected: 1.5},
		{name: "mixed number 2 3/4", input: "2 3/4 lbs chicken", expected: 2.75},
		{name: "mixed number with dash", input: "1-1/2 cups flour", expected: 1.5},
		{name: "unicode half", input: "½ cup milk", expected: 0.5},
		{name: "unicode quarter", input: "¼ tsp salt", expected: 0.25},
		{name: "unicode three-quarters", input: "¾ cup flour", expected: 0.75},
		{name: "unicode one-third", input: "⅓ cup sugar", expected: 1.0 / 3.0},
		{name: "mixed unicode 1½", input: "1½ cups flour", expected: 1.5},
		{name: "mixed unicode 2¼", input: "2¼ tsp", expected: 2.25},
		{name: "decimal with unit", input: "2.5 oz cheese", expected: 2.5},
		{name: "no number just unit", input: "cups flour", expected: 1},
		{name: "just name", input: "eggs", expected: 1},
		{name: "leading space", input: "  3 eggs", expected: 3},
		{name: "zero value", input: "0", expected: 1},
		{name: "negative value", input: "-1 cup", expected: 1},
		{name: "unicode one-eighth", input: "⅛ tsp", expected: 0.125},
		{name: "unicode three-eighths", input: "⅜ cup", expected: 0.375},
		{name: "unicode five-eighths", input: "⅝ cup", expected: 0.625},
		{name: "unicode seven-eighths", input: "⅞ cup", expected: 0.875},
		{name: "unicode two-thirds", input: "⅔ cup", expected: 2.0 / 3.0},
		{name: "spaces around fraction", input: "2  /  3 cup", expected: 2},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ParseIngredientAmount(tt.input)
			if math.Abs(result-tt.expected) > 0.001 {
				t.Errorf("ParseIngredientAmount(%q) = %v; want %v", tt.input, result, tt.expected)
			}
		})
	}
}
