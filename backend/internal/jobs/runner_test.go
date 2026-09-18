package jobs

import (
	"testing"

	"github.com/mitlist-app/mitlist/pkg/logger"
	"github.com/stretchr/testify/assert"
)

func TestRunner_RegisterAll(t *testing.T) {
	log := logger.New("test")
	r := NewRunner(nil, nil, log)
	r.RegisterAll()

	assert.Len(t, r.jobs, 7)

	expected := map[string]struct {
		schedule string
		enabled  bool
	}{
		"chore-scheduler":   {"1 0 * * *", true},
		"recurring-expense": {"0 * * * *", true},
		"chore-reminder":    {"0 9 * * *", true},
		"weekly-summary":    {"0 9 * * 1", true},
		"pinwall-reminder":  {"* * * * *", true},
		"list-reminder":     {"* * * * *", true},
		"guest-cleanup":     {"15 3 * * *", true},
	}

	for _, j := range r.jobs {
		exp, ok := expected[j.Name]
		assert.True(t, ok, "unexpected job %s", j.Name)
		assert.Equal(t, exp.schedule, j.Schedule, "job %s schedule mismatch", j.Name)
		assert.Equal(t, exp.enabled, j.Enabled, "job %s enabled mismatch", j.Name)
	}
}

func TestRunner_RegisterAll_WithDispatcherRegistersListDigest(t *testing.T) {
	log := logger.New("test")
	r := NewRunnerWithDispatcher(nil, &capturedDispatch{}, log)
	r.RegisterAll()

	assert.Len(t, r.jobs, 8)
	found := false
	for _, job := range r.jobs {
		if job.Name == "list-notification-digest" {
			found = true
			assert.Equal(t, "* * * * *", job.Schedule)
			assert.True(t, job.Enabled)
		}
	}
	assert.True(t, found)
}
