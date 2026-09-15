package onboarding

import "embed"

// heroFiles are the static onboarding illustrations served by the public
// API. Embedding them keeps self-hosted email from loading images elsewhere.
//
//go:embed assets/*.jpg
var heroFiles embed.FS

var allowedHeroFiles = map[string]struct{}{
	"day1-household.jpg": {},
	"day3-lists.jpg":     {},
	"day7-money.jpg":     {},
	"day14-chores.jpg":   {},
	"day30-checkin.jpg":  {},
}

// HeroImage returns a campaign image only when filename is one of the known
// step assets. The explicit allowlist keeps the public handler from becoming a
// general embedded-file server.
func HeroImage(filename string) ([]byte, bool) {
	if _, ok := allowedHeroFiles[filename]; !ok {
		return nil, false
	}
	data, err := heroFiles.ReadFile("assets/" + filename)
	return data, err == nil
}
