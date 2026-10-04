package jobs

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"

	"github.com/mitlist-app/mitlist/internal/onboarding"
	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type reengagementClaimKey struct {
	id    uuid.UUID
	since time.Time
}

type fakeReengagementRepo struct {
	candidates []reengagementCandidate
	claimed    map[reengagementClaimKey]bool
	sent       []uuid.UUID
	failed     []uuid.UUID
	listArgs   []time.Time
}

func (f *fakeReengagementRepo) ListCandidates(_ context.Context, idleCutoff, idleFloor, cooldownSince, quietSince time.Time, _ int) ([]reengagementCandidate, error) {
	f.listArgs = []time.Time{idleCutoff, idleFloor, cooldownSince, quietSince}
	return f.candidates, nil
}

func (f *fakeReengagementRepo) Claim(_ context.Context, id uuid.UUID, since time.Time) (bool, error) {
	key := reengagementClaimKey{id, since}
	if f.claimed[key] {
		return false, nil
	}
	f.claimed[key] = true
	return true, nil
}

func (f *fakeReengagementRepo) MarkSent(_ context.Context, id uuid.UUID, _ time.Time) error {
	f.sent = append(f.sent, id)
	return nil
}

func (f *fakeReengagementRepo) MarkFailed(_ context.Context, id uuid.UUID, _ time.Time, _ string) error {
	f.failed = append(f.failed, id)
	return nil
}

type recordingMailer struct {
	msgs    []recordedMail
	failFor string
}

type recordedMail struct {
	to, subject, html, text string
	headers                 []mailservice.Header
}

func (m *recordingMailer) SendHTMLWithHeadersOnce(to, subject, html, text string, headers []mailservice.Header) error {
	if to == m.failFor {
		return errors.New("550 mailbox unavailable")
	}
	m.msgs = append(m.msgs, recordedMail{to, subject, html, text, headers})
	return nil
}

func newTestReengagement(repo reengagementRepo, mail onboardingMailer, now time.Time) *Reengagement {
	return &Reengagement{
		repo:      repo,
		mail:      mail,
		log:       logger.New("test"),
		secret:    []byte("test-secret"),
		appURL:    "https://app.example.test",
		apiURL:    "https://api.example.test",
		apiPrefix: "/api",
		now:       func() time.Time { return now },
	}
}

func TestReengagement_SendsOncePerEpisodeWithFeedbackLink(t *testing.T) {
	now := time.Date(2026, 9, 29, 16, 40, 0, 0, time.UTC)
	android := reengagementCandidate{ID: uuid.New(), Email: "droid@example.com", FirstName: "Ada", LastActiveAt: now.Add(-8 * 24 * time.Hour), HasAndroid: true}
	web := reengagementCandidate{ID: uuid.New(), Email: "web@example.com", LastActiveAt: now.Add(-10 * 24 * time.Hour), Language: "de"}
	repo := &fakeReengagementRepo{
		candidates: []reengagementCandidate{android, web},
		claimed:    map[reengagementClaimKey]bool{},
	}
	mailer := &recordingMailer{}
	job := newTestReengagement(repo, mailer, now)

	sent, failed := job.run(context.Background())
	if sent != 2 || failed != 0 {
		t.Fatalf("sent=%d failed=%d, want 2/0", sent, failed)
	}
	for _, m := range mailer.msgs {
		if !strings.Contains(m.html, `href="https://app.example.test/you/feature-board"`) {
			t.Errorf("%s: html lacks the feedback board link", m.to)
		}
		var unsub, oneClick bool
		for _, h := range m.headers {
			switch h.Name {
			case "List-Unsubscribe":
				unsub = strings.HasPrefix(h.Value, "<https://api.example.test/api/v1/email/unsubscribe?token=")
			case "List-Unsubscribe-Post":
				oneClick = h.Value == "List-Unsubscribe=One-Click"
			}
		}
		if !unsub || !oneClick {
			t.Errorf("%s: headers = %+v, want List-Unsubscribe and one-click", m.to, m.headers)
		}
	}
	if got := mailer.msgs[0]; !strings.Contains(got.html, onboarding.PlayStoreURL) || !strings.Contains(got.text, "Hi Ada.") {
		t.Errorf("android recipient should get the Play rating link and a greeting")
	}
	if got := mailer.msgs[1]; strings.Contains(got.html, "play.google.com") || strings.Contains(got.text, "play.google.com") {
		t.Errorf("non-android recipient got a Play Store link")
	}
	if want := onboarding.RenderReengagement("de", "", onboarding.ReengagementLinks{}).Subject; mailer.msgs[1].subject != want {
		t.Errorf("stored language ignored: subject %q, want %q", mailer.msgs[1].subject, want)
	}
	if want := onboarding.RenderReengagement("en", "", onboarding.ReengagementLinks{}).Subject; mailer.msgs[0].subject != want {
		t.Errorf("no stored language should fall back to English: subject %q, want %q", mailer.msgs[0].subject, want)
	}

	// A second run over the same episode (another instance, or tomorrow's
	// run before the cooldown query sees the ledger) sends nothing.
	sent, _ = job.run(context.Background())
	if sent != 0 || len(mailer.msgs) != 2 {
		t.Fatalf("second run sent %d more, want 0", sent)
	}

	wantArgs := []time.Time{
		now.Add(-onboarding.ReengagementAfter),
		now.Add(-onboarding.ReengagementMaxIdle),
		now.Add(-onboarding.ReengagementCooldown),
		now.Add(-reengagementQuietAfterTip),
	}
	for i, want := range wantArgs {
		if !repo.listArgs[i].Equal(want) {
			t.Errorf("ListCandidates arg %d = %v, want %v", i, repo.listArgs[i], want)
		}
	}
}

func TestReengagement_FailureIsRecordedAndDoesNotStopTheRun(t *testing.T) {
	now := time.Date(2026, 9, 29, 16, 40, 0, 0, time.UTC)
	bad := reengagementCandidate{ID: uuid.New(), Email: "bounce@example.com", LastActiveAt: now.Add(-9 * 24 * time.Hour)}
	good := reengagementCandidate{ID: uuid.New(), Email: "ok@example.com", LastActiveAt: now.Add(-9 * 24 * time.Hour)}
	repo := &fakeReengagementRepo{candidates: []reengagementCandidate{bad, good}, claimed: map[reengagementClaimKey]bool{}}
	mailer := &recordingMailer{failFor: bad.Email}

	sent, failed := newTestReengagement(repo, mailer, now).run(context.Background())
	if sent != 1 || failed != 1 {
		t.Fatalf("sent=%d failed=%d, want 1/1", sent, failed)
	}
	if len(repo.failed) != 1 || repo.failed[0] != bad.ID {
		t.Errorf("failed ledger = %v, want [%v]", repo.failed, bad.ID)
	}
	if len(repo.sent) != 1 || repo.sent[0] != good.ID {
		t.Errorf("sent ledger = %v, want [%v]", repo.sent, good.ID)
	}
}

func TestReengagementRepo_ClaimUsesOneAtomicInsert(t *testing.T) {
	pool, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create pgx mock: %v", err)
	}
	defer pool.Close()

	id := uuid.New()
	since := time.Date(2026, 9, 20, 8, 0, 0, 0, time.UTC)
	repo := &reengagementRepoImpl{db: pool}
	pool.ExpectQuery("INSERT INTO reengagement_email_sends .* ON CONFLICT \\(user_id, inactive_since\\) DO NOTHING").
		WithArgs(id, since).
		WillReturnRows(pgxmock.NewRows([]string{"claimed"}))

	claimed, err := repo.Claim(context.Background(), id, since)
	if err != nil || claimed {
		t.Fatalf("Claim on a taken episode = (%v, %v), want (false, nil)", claimed, err)
	}
	if err := pool.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
