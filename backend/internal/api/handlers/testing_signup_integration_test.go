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
		if err := repo.Create(context.Background(), email, platform, testingConsentVersion); err != nil {
			t.Fatal(err)
		}
	}
	var count int
	if err := testDB.QueryRow(context.Background(), "SELECT count(*) FROM testing_signups WHERE email=$1", email).Scan(&count); err != nil || count != 2 {
		t.Fatalf("count=%d err=%v", count, err)
	}
}
