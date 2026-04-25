package db

import (
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestToMigrateDSN(t *testing.T) {
	t.Run("postgres scheme", func(t *testing.T) {
		got := toMigrateDSN("postgres://user:pass@localhost:5432/mitlist?sslmode=disable")
		require.Equal(t, "pgx5://user:pass@localhost:5432/mitlist?sslmode=disable", got)
	})

	t.Run("postgresql scheme", func(t *testing.T) {
		got := toMigrateDSN("postgresql://user:pass@localhost:5432/mitlist?sslmode=disable")
		require.Equal(t, "pgx5://user:pass@localhost:5432/mitlist?sslmode=disable", got)
	})

	t.Run("already migrated scheme", func(t *testing.T) {
		got := toMigrateDSN("pgx5://user:pass@localhost:5432/mitlist?sslmode=disable")
		require.Equal(t, "pgx5://user:pass@localhost:5432/mitlist?sslmode=disable", got)
	})
}

func TestResolveMigrationsSource(t *testing.T) {
	old := os.Getenv("MIGRATIONS_PATH")
	t.Cleanup(func() {
		if old == "" {
			_ = os.Unsetenv("MIGRATIONS_PATH")
			return
		}
		_ = os.Setenv("MIGRATIONS_PATH", old)
	})

	_ = os.Unsetenv("MIGRATIONS_PATH")

	source, err := resolveMigrationsSource()
	require.NoError(t, err)
	require.True(t, strings.HasPrefix(source, "file://"))
	require.Contains(t, source, "/migrations")
}
