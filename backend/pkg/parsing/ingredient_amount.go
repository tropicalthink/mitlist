package parsing

import (
	"fmt"
	"strconv"
	"strings"
)

var unicodeFractions = map[rune]float64{
	'¼': 0.25, '½': 0.5, '¾': 0.75,
	'⅓': 1.0 / 3.0, '⅔': 2.0 / 3.0,
	'⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
}

func parseSimpleFraction(s string) (float64, error) {
	parts := strings.Split(s, "/")
	if len(parts) == 2 {
		num, err1 := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
		den, err2 := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
		if err1 == nil && err2 == nil && den != 0 {
			return num / den, nil
		}
	}
	return 0, fmt.Errorf("not a fraction")
}

func ParseIngredientAmount(raw string) float64 {
	raw = strings.TrimSpace(strings.ReplaceAll(raw, ",", "."))
	if raw == "" {
		return 1
	}

	for r, v := range unicodeFractions {
		if strings.ContainsRune(raw, r) {
			before := strings.TrimSpace(strings.Split(raw, string(r))[0])
			if before != "" {
				if whole, err := strconv.ParseFloat(before, 64); err == nil {
					return whole + v
				}
			}
			return v
		}
	}

	raw = strings.ReplaceAll(raw, "-", " ")
	fields := strings.Fields(raw)

	if len(fields) >= 2 {
		w, err1 := strconv.ParseFloat(fields[0], 64)
		f, err2 := parseSimpleFraction(fields[1])
		if err1 == nil && err2 == nil {
			return w + f
		}
	}

	if len(fields) >= 1 {
		if v, err := parseSimpleFraction(fields[0]); err == nil {
			return v
		}
	}

	for _, field := range fields {
		if n, err := strconv.ParseFloat(field, 64); err == nil && n > 0 {
			return n
		}
	}

	if n, err := strconv.ParseFloat(raw, 64); err == nil && n > 0 {
		return n
	}

	return 1
}
