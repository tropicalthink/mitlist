package db

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"

	"github.com/yourorg/mitlist/internal/config"
	"github.com/yourorg/mitlist/pkg/logger"
)

// RunMigrations applies all pending database migrations before the API starts
// serving traffic.
func RunMigrations(cfg *config.Config, log *logger.Logger) error {
	source, err := resolveMigrationsSource()
	if err != nil {
		return err
	}

	m, err := migrate.New(source, toMigrateDSN(cfg.DatabaseURL))
	if err != nil {
		return fmt.Errorf("create migrator: %w", err)
	}
	defer func() {
		srcErr, dbErr := m.Close()
		if srcErr != nil {
			log.Warn().Err(srcErr).Msg("failed to close migration source cleanly")
		}
		if dbErr != nil {
			log.Warn().Err(dbErr).Msg("failed to close migration database cleanly")
		}
	}()

	if err := m.Up(); err != nil {
		if errors.Is(err, migrate.ErrNoChange) {
			log.Info().Str("source", source).Msg("no startup migrations to apply")
			return nil
		}
		return fmt.Errorf("apply migrations: %w", err)
	}

	version, dirty, err := m.Version()
	if err != nil && !errors.Is(err, migrate.ErrNilVersion) {
		return fmt.Errorf("read migration version: %w", err)
	}

	log.Info().
		Str("source", source).
		Uint("version", version).
		Bool("dirty", dirty).
		Msg("startup migrations applied")

	return nil
}

func resolveMigrationsSource() (string, error) {
	if source := os.Getenv("MIGRATIONS_PATH"); source != "" {
		if strings.Contains(source, "://") {
			return source, nil
		}

		absSource, err := filepath.Abs(source)
		if err != nil {
			return "", fmt.Errorf("resolve MIGRATIONS_PATH: %w", err)
		}
		return "file://" + filepath.ToSlash(absSource), nil
	}

	_, filename, _, ok := runtime.Caller(0)
	if !ok {
		return "", fmt.Errorf("resolve migrations directory: runtime caller unavailable")
	}

	migrationsDir := filepath.Clean(filepath.Join(filepath.Dir(filename), "..", "..", "migrations"))
	if _, err := os.Stat(migrationsDir); err != nil {
		return "", fmt.Errorf("resolve migrations directory: %w", err)
	}

	return "file://" + filepath.ToSlash(migrationsDir), nil
}

func toMigrateDSN(databaseURL string) string {
	// golang-migrate pgx v5 driver expects the pgx5:// scheme.
	if strings.HasPrefix(databaseURL, "postgres://") {
		return "pgx5" + databaseURL[len("postgres"):]
	}
	if strings.HasPrefix(databaseURL, "postgresql://") {
		return "pgx5" + databaseURL[len("postgresql"):]
	}
	return databaseURL
}
