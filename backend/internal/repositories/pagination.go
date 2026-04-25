package repositories

const (
	defaultLimit = 50
	maxLimit     = 500
)

func normalizeLimit(limit int) int {
	if limit <= 0 {
		return defaultLimit
	}
	if limit > maxLimit {
		return maxLimit
	}
	return limit
}

func clampLimit(limit int) int {
	return normalizeLimit(limit)
}
