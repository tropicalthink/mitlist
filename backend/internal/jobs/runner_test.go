package jobs

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

func TestRunner_RegisterAll(t *testing.T) {
	log := logger.New("test")
	r := NewRunner(nil, nil, log)
	r.RegisterAll()

	assert.Len(t, r.jobs, 5)

	expected := map[string]struct {
		schedule string
		enabled  bool
	}{
		"chore-scheduler":   {"1 0 * * *", true},
		"recurring-expense": {"0 * * * *", true},
		"chore-reminder":    {"0 9 * * *", true},
		"weekly-summary":    {"0 9 * * 1", true},
		"pinwall-reminder":  {"* * * * *", true},
	}

	for _, j := range r.jobs {
		exp, ok := expected[j.Name]
		assert.True(t, ok, "unexpected job %s", j.Name)
		assert.Equal(t, exp.schedule, j.Schedule, "job %s schedule mismatch", j.Name)
		assert.Equal(t, exp.enabled, j.Enabled, "job %s enabled mismatch", j.Name)
	}
}
