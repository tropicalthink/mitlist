package handlers

import (
	"context"
	"testing"
	"time"

	"github.com/mitlist-app/mitlist/internal/repositories"
)

func TestTestingSignupRepositoryDeduplicates(t *testing.T) {
	email := "testing-signup-" + time.Now().Format("20060102150405.000000000") + "@example.com"
	t.Cleanup(func() { _, _ = testDB.Exec(context.Background(), "DELETE FROM testing_signups WHERE email=$1", email) })
	repo := repositories.NewTestingSignupRepository(testDB)
	for _, platform := range []string{"android", "android", "ios"} {
		if err := repo.Create(context.Background(), email, platform, testingConsentVersion, false, launchUpdatesConsentVersion); err != nil {
			t.Fatal(err)
		}
	}
	if err := repo.Create(context.Background(), email, "android", testingConsentVersion, true, launchUpdatesConsentVersion); err != nil {
		t.Fatal(err)
	}
	var count int
	if err := testDB.QueryRow(context.Background(), "SELECT count(*) FROM testing_signups WHERE email=$1", email).Scan(&count); err != nil || count != 2 {
		t.Fatalf("count=%d err=%v", count, err)
	}
	var launchUpdates bool
	var launchVersion *string
	var launchConsentedAt *time.Time
	if err := testDB.QueryRow(context.Background(), `SELECT launch_updates, launch_consent_version, launch_consented_at
		FROM testing_signups WHERE email=$1 AND platform='android'`, email).Scan(&launchUpdates, &launchVersion, &launchConsentedAt); err != nil {
		t.Fatal(err)
	}
	if !launchUpdates || launchVersion == nil || *launchVersion != launchUpdatesConsentVersion || launchConsentedAt == nil {
		t.Fatal("repeat signup did not preserve the separate launch consent")
	}
}
