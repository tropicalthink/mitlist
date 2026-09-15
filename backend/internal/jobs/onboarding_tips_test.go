package jobs

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pashagolub/pgxmock/v4"

	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type concurrentOnboardingRepo struct {
	candidate onboardingCandidate
	mu        sync.Mutex
	claimed   bool
}

func newConcurrentOnboardingRepo(candidate onboardingCandidate) *concurrentOnboardingRepo {
	return &concurrentOnboardingRepo{candidate: candidate}
}

func (r *concurrentOnboardingRepo) ListCandidates(context.Context, time.Time, int) ([]onboardingCandidate, error) {
	return []onboardingCandidate{r.candidate}, nil
}

func (r *concurrentOnboardingRepo) ClaimStep(context.Context, uuid.UUID, string) (bool, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.claimed {
		return false, nil
	}
	r.claimed = true
	return true, nil
}

func (r *concurrentOnboardingRepo) MarkSent(context.Context, uuid.UUID, string) error { return nil }

func (r *concurrentOnboardingRepo) MarkFailed(context.Context, uuid.UUID, string, string) error {
	return nil
}

type fakeOnboardingRepo struct {
	candidates []onboardingCandidate
	ledger     map[uuid.UUID]map[string]onboardingLedgerEntry
	sent       []string
	failed     []string
}

type onboardingLedgerEntry struct {
	Attempted      bool
	Sent           bool
	FailedAttempts int
}

func (f *fakeOnboardingRepo) ListCandidates(_ context.Context, _ time.Time, _ int) ([]onboardingCandidate, error) {
	return f.candidates, nil
}
func (f *fakeOnboardingRepo) ClaimStep(_ context.Context, id uuid.UUID, step string) (bool, error) {
	entry := f.ledger[id][step]
	if entry.Attempted || entry.Sent {
		return false, nil
	}
	if f.ledger[id] == nil {
		f.ledger[id] = map[string]onboardingLedgerEntry{}
	}
	entry.Attempted = true
	f.ledger[id][step] = entry
	f.sent = append(f.sent, step)
	return true, nil
}
func (f *fakeOnboardingRepo) MarkSent(_ context.Context, id uuid.UUID, step string) error {
	entry := f.ledger[id][step]
	entry.Sent = true
	f.ledger[id][step] = entry
	return nil
}
func (f *fakeOnboardingRepo) MarkFailed(_ context.Context, id uuid.UUID, step, _ string) error {
	entry := f.ledger[id][step]
	entry.FailedAttempts++
	f.ledger[id][step] = entry
	f.failed = append(f.failed, step)
	return nil
}

type fakeMailer struct {
	sent    []sentMail
	failFor string
}

type sentMail struct {
	to, subject string
	headers     []mailservice.Header
}

func (f *fakeMailer) SendHTMLWithHeadersOnce(to, subject, html, text string, headers []mailservice.Header) error {
	if to == f.failFor {
		return errors.New("550 mailbox unavailable")
	}
	f.sent = append(f.sent, sentMail{to: to, subject: subject, headers: headers})
	return nil
}

func TestOnboardingTips_SendsDueStepsOnceWithUnsubscribeHeaders(t *testing.T) {
	now := time.Date(2026, 9, 8, 12, 0, 0, 0, time.UTC)
	fresh := onboardingCandidate{ID: uuid.New(), Email: "fresh@example.com", FirstName: "Ada", CreatedAt: now.Add(-24 * time.Hour)}
	done := onboardingCandidate{ID: uuid.New(), Email: "done@example.com", CreatedAt: now.Add(-24 * time.Hour)}
	tooNew := onboardingCandidate{ID: uuid.New(), Email: "new@example.com", CreatedAt: now.Add(-2 * time.Hour)}

	repo := &fakeOnboardingRepo{
		candidates: []onboardingCandidate{fresh, done, tooNew},
		ledger: map[uuid.UUID]map[string]onboardingLedgerEntry{
			done.ID: {"day1-household": {Sent: true}},
		},
	}
	mailer := &fakeMailer{}
	job := newOnboardingTips(repo, mailer, logger.New("test"))
	job.now = func() time.Time { return now }

	sent, failed := job.run(context.Background())
	if sent != 1 || failed != 0 {
		t.Fatalf("sent=%d failed=%d, want 1/0", sent, failed)
	}
	if len(mailer.sent) != 1 || mailer.sent[0].to != fresh.Email {
		t.Fatalf("mail went to %+v, want only %s", mailer.sent, fresh.Email)
	}
	var unsub, oneClick bool
	for _, h := range mailer.sent[0].headers {
		switch h.Name {
		case "List-Unsubscribe":
			unsub = h.Value[0] == '<' && len(h.Value) > 40
		case "List-Unsubscribe-Post":
			oneClick = h.Value == "List-Unsubscribe=One-Click"
		}
	}
	if !unsub || !oneClick {
		t.Errorf("headers = %+v, want List-Unsubscribe and List-Unsubscribe-Post", mailer.sent[0].headers)
	}
	if len(repo.sent) != 1 || repo.sent[0] != "day1-household" {
		t.Errorf("ledger marked %v, want [day1-household]", repo.sent)
	}
}

func TestOnboardingTips_ConcurrentRunsSendEachStepOnlyOnce(t *testing.T) {
	now := time.Date(2026, 9, 8, 12, 0, 0, 0, time.UTC)
	candidate := onboardingCandidate{
		ID:        uuid.New(),
		Email:     "fresh@example.com",
		FirstName: "Ada",
		CreatedAt: now.Add(-24 * time.Hour),
	}
	repo := newConcurrentOnboardingRepo(candidate)
	mailer := &concurrentMailer{}
	jobs := []*OnboardingTips{
		newOnboardingTips(repo, mailer, logger.New("test")),
		newOnboardingTips(repo, mailer, logger.New("test")),
	}
	for _, job := range jobs {
		job.now = func() time.Time { return now }
	}

	var runs sync.WaitGroup
	runs.Add(len(jobs))
	for _, job := range jobs {
		go func() {
			defer runs.Done()
			job.run(context.Background())
		}()
	}
	runs.Wait()

	if got := mailer.count(); got != 1 {
		t.Fatalf("delivered %d copies of one onboarding step, want 1", got)
	}
}

func TestOnboardingRepo_ClaimStepUsesOneAtomicInsert(t *testing.T) {
	pool, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create pgx mock: %v", err)
	}
	defer pool.Close()

	id := uuid.New()
	repo := &onboardingRepoImpl{db: pool}
	pool.ExpectQuery("INSERT INTO onboarding_email_sends").
		WithArgs(id, "day1-household").
		WillReturnRows(pgxmock.NewRows([]string{"claimed"}).AddRow(true))

	claimed, err := repo.ClaimStep(context.Background(), id, "day1-household")
	if err != nil || !claimed {
		t.Fatalf("ClaimStep = (%v, %v), want (true, nil)", claimed, err)
	}
	if err := pool.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestOnboardingRepo_ClaimStepRejectsExistingAttempt(t *testing.T) {
	pool, err := pgxmock.NewPool()
	if err != nil {
		t.Fatalf("create pgx mock: %v", err)
	}
	defer pool.Close()

	id := uuid.New()
	repo := &onboardingRepoImpl{db: pool}
	pool.ExpectQuery("INSERT INTO onboarding_email_sends").
		WithArgs(id, "day1-household").
		WillReturnRows(pgxmock.NewRows([]string{"claimed"}))

	claimed, err := repo.ClaimStep(context.Background(), id, "day1-household")
	if err != nil || claimed {
		t.Fatalf("ClaimStep = (%v, %v), want (false, nil)", claimed, err)
	}
	if err := pool.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

type concurrentMailer struct {
	mu   sync.Mutex
	sent int
}

func (m *concurrentMailer) SendHTMLWithHeadersOnce(string, string, string, string, []mailservice.Header) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.sent++
	return nil
}

func (m *concurrentMailer) count() int {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.sent
}

func TestOnboardingTips_OneStepPerPersonPerRunAndDoesNotRetryAttempts(t *testing.T) {
	now := time.Date(2026, 9, 8, 12, 0, 0, 0, time.UTC)
	// Created 3 days + 1 hour ago: day1 is out of window, day3 is due.
	// Pretend the job stalled and day1 is also still inside its window by
	// using an account 3d old exactly — day1 window (20h..92h) still open.
	catchUp := onboardingCandidate{ID: uuid.New(), Email: "catchup@example.com", CreatedAt: now.Add(-73 * time.Hour)}
	bouncing := onboardingCandidate{ID: uuid.New(), Email: "bounce@example.com", CreatedAt: now.Add(-24 * time.Hour)}
	givenUp := onboardingCandidate{ID: uuid.New(), Email: "gaveup@example.com", CreatedAt: now.Add(-24 * time.Hour)}

	repo := &fakeOnboardingRepo{
		candidates: []onboardingCandidate{catchUp, bouncing, givenUp},
		ledger: map[uuid.UUID]map[string]onboardingLedgerEntry{
			givenUp.ID: {"day1-household": {Attempted: true, FailedAttempts: 1}},
		},
	}
	mailer := &fakeMailer{failFor: bouncing.Email}
	job := newOnboardingTips(repo, mailer, logger.New("test"))
	job.now = func() time.Time { return now }

	sent, failed := job.run(context.Background())
	if sent != 1 || failed != 1 {
		t.Fatalf("sent=%d failed=%d, want 1/1", sent, failed)
	}
	// catchUp had two steps due but gets exactly one this run.
	if len(mailer.sent) != 1 || mailer.sent[0].to != catchUp.Email {
		t.Errorf("mail = %+v, want one to %s", mailer.sent, catchUp.Email)
	}
	if len(repo.failed) != 1 || repo.failed[0] != "day1-household" {
		t.Errorf("failed ledger = %v", repo.failed)
	}

	// A rejected marketing email is recorded but not submitted again. The
	// campaign is deliberately at-most-once to avoid duplicates when a provider
	// accepted a message but its response was lost.
	job.run(context.Background())
	if len(repo.failed) != 1 {
		t.Errorf("failed delivery retried %d times, want one attempt", len(repo.failed))
	}
}
