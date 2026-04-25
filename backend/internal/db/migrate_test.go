package db

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMigration_Rollback(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping migration test in short mode")
	}

	ctx := context.Background()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" || !strings.Contains(dsn, "mitlist") {
		t.Skip("DATABASE_URL with mitlist not set, skipping migration test")
	}
	adminDSN := strings.Replace(dsn, "/mitlist_test?", "/mitlist?", 1)

	// Connect to admin database to create/drop test database.
	adminPool, err := pgxpool.New(ctx, adminDSN)
	require.NoError(t, err)
	defer adminPool.Close()

	testDBName := "mitlist_migrate_test_" + fmt.Sprintf("%d", time.Now().UnixNano())
	_, err = adminPool.Exec(ctx, fmt.Sprintf("CREATE DATABASE %s", testDBName))
	require.NoError(t, err)
	defer func() {
		// Terminate connections and drop test database.
		_, _ = adminPool.Exec(ctx, fmt.Sprintf(
			"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '%s' AND pid <> pg_backend_pid()", testDBName))
		_, _ = adminPool.Exec(ctx, fmt.Sprintf("DROP DATABASE IF EXISTS %s", testDBName))
	}()

	testDSN := fmt.Sprintf("postgres://oubaste:oubaste@localhost:5432/%s?sslmode=disable", testDBName)

	// Wait for test database to be ready.
	require.NoError(t, waitForPostgres(ctx, testDSN, 10))

	pool, err := pgxpool.New(ctx, testDSN)
	require.NoError(t, err)
	defer pool.Close()

	// Verify empty before migration.
	var countBefore int
	err = pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM information_schema.tables
		WHERE table_schema = 'public'
		AND table_type = 'BASE TABLE'
		AND table_name NOT LIKE 'pg_%'
		AND table_name NOT LIKE 'sql_%'
		AND table_name != 'schema_migrations'
	`).Scan(&countBefore)
	require.NoError(t, err)
	assert.Zero(t, countBefore, "database should be empty before migration")

	// Run migrations up.
	migrationsDir := getMigrationsDir(t)
	m, err := migrate.New(
		"file://"+migrationsDir,
		"pgx5"+testDSN[len("postgres"):],
	)
	require.NoError(t, err)
	defer m.Close()

	err = m.Up()
	require.NoError(t, err)

	version, dirty, err := m.Version()
	require.NoError(t, err)
	assert.False(t, dirty, "migration should not be dirty after up")
	assert.Greater(t, version, uint(0), "migration version should be > 0")

	// Verify schema: check some tables exist.
	tables := []string{
		"users", "groups", "lists", "expenses", "recipes",
		"chores", "vault_items", "living_things", "chat_sessions",
	}
	for _, table := range tables {
		var exists bool
		err := pool.QueryRow(ctx,
			"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1)",
			table,
		).Scan(&exists)
		require.NoError(t, err, "checking table %s", table)
		assert.True(t, exists, "table %s should exist after migration up", table)
	}

	// Run migrations down.
	err = m.Down()
	require.NoError(t, err)

	// Verify database is empty (no user tables remain, excluding schema_migrations).
	var count int
	err = pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM information_schema.tables
		WHERE table_schema = 'public'
		AND table_type = 'BASE TABLE'
		AND table_name NOT LIKE 'pg_%'
		AND table_name NOT LIKE 'sql_%'
		AND table_name != 'schema_migrations'
	`).Scan(&count)
	require.NoError(t, err)
	assert.Zero(t, count, "all user tables should be dropped after migration down")
}

func waitForPostgres(ctx context.Context, dsn string, maxSeconds int) error {
	for i := 0; i < maxSeconds; i++ {
		pool, err := pgxpool.New(ctx, dsn)
		if err == nil {
			pingErr := pool.Ping(ctx)
			pool.Close()
			if pingErr == nil {
				return nil
			}
		}
		time.Sleep(time.Second)
	}
	return fmt.Errorf("postgres not ready after %d seconds", maxSeconds)
}

func getMigrationsDir(t *testing.T) string {
	_, b, _, ok := runtime.Caller(0)
	require.True(t, ok)
	basePath := filepath.Dir(b)
	root := filepath.Join(basePath, "..", "..")
	dir := filepath.Join(root, "migrations")
	dir = filepath.Clean(dir)
	_, err := os.Stat(dir)
	require.NoError(t, err, "migrations directory not found at %s", dir)
	return strings.ReplaceAll(dir, "\\", "/")
}
