package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"
)

const defaultMigrationsPath = "file://migrations"

func main() {
	_ = godotenv.Load()

	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal().Msg("DATABASE_URL environment variable is required")
	}

	migrationsPath := os.Getenv("MIGRATIONS_PATH")
	if migrationsPath == "" {
		migrationsPath = defaultMigrationsPath
	}

	m, err := migrate.New(migrationsPath, toMigrateDSN(databaseURL))
	if err != nil {
		log.Fatal().Err(err).Msg("failed to create migrate instance")
	}

	subcommand := os.Args[1]
	switch subcommand {
	case "up":
		up(m)
	case "down":
		down(m)
	case "version":
		version(m)
	case "force":
		force(m)
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand: %s\n", subcommand)
		printUsage()
		os.Exit(1)
	}
}

func up(m *migrate.Migrate) {
	fs := flag.NewFlagSet("up", flag.ExitOnError)
	steps := fs.Int("steps", 0, "number of migrations to apply (0 = all)")
	_ = fs.Parse(os.Args[2:])

	var err error
	if *steps > 0 {
		err = m.Steps(*steps)
	} else {
		err = m.Up()
	}

	if err != nil {
		if err == migrate.ErrNoChange {
			log.Info().Msg("no migrations to apply")
			return
		}
		log.Fatal().Err(err).Msg("migration up failed")
	}

	v, dirty, _ := m.Version()
	log.Info().Uint("version", v).Bool("dirty", dirty).Msg("migrations applied successfully")
}

func down(m *migrate.Migrate) {
	fs := flag.NewFlagSet("down", flag.ExitOnError)
	steps := fs.Int("steps", 1, "number of migrations to rollback (default 1)")
	_ = fs.Parse(os.Args[2:])

	err := m.Steps(-*steps)
	if err != nil {
		if err == migrate.ErrNoChange {
			log.Info().Msg("no migrations to rollback")
			return
		}
		log.Fatal().Err(err).Msg("migration down failed")
	}

	v, dirty, _ := m.Version()
	log.Info().Uint("version", v).Bool("dirty", dirty).Msg("migrations rolled back successfully")
}

func version(m *migrate.Migrate) {
	v, dirty, err := m.Version()
	if err != nil {
		if err == migrate.ErrNilVersion {
			fmt.Println("version: nil (no migrations applied)")
			return
		}
		log.Fatal().Err(err).Msg("failed to get migration version")
	}
	fmt.Printf("version: %d dirty: %v\n", v, dirty)
}

func force(m *migrate.Migrate) {
	fs := flag.NewFlagSet("force", flag.ExitOnError)
	v := fs.Int("version", -1, "target version to force")
	_ = fs.Parse(os.Args[2:])

	if *v < 0 {
		fmt.Fprintln(os.Stderr, "usage: force -version=N")
		os.Exit(1)
	}

	if err := m.Force(*v); err != nil {
		log.Fatal().Err(err).Int("version", *v).Msg("force version failed")
	}
	log.Info().Int("version", *v).Msg("version forced")
}

func toMigrateDSN(databaseURL string) string {
	// golang-migrate pgx v5 driver expects pgx5:// scheme
	if strings.HasPrefix(databaseURL, "postgres://") {
		return "pgx5" + databaseURL[len("postgres"):]
	}
	if strings.HasPrefix(databaseURL, "postgresql://") {
		return "pgx5" + databaseURL[len("postgresql"):]
	}
	return databaseURL
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "Usage: migrate <subcommand> [options]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Subcommands:")
	fmt.Fprintln(os.Stderr, "  up       [-steps=N]   Apply migrations (all if steps=0)")
	fmt.Fprintln(os.Stderr, "  down     [-steps=N]   Rollback migrations (default 1)")
	fmt.Fprintln(os.Stderr, "  version               Print current migration version")
	fmt.Fprintln(os.Stderr, "  force    -version=N   Force migration version (repair dirty state)")
}

