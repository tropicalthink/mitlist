package jobs

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	mailservice "github.com/mitlist-app/mitlist/internal/services/mail"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

type fakeOnboardingRepo struct {
	candidates []onboardingCandidate
	ledger     map[uuid.UUID]map[string]onboardingLedgerEntry
	sent       []string
	failed     []string
}

func (f *fakeOnboardingRepo) ListCandidates(_ context.Context, _ time.Time, _ int) ([]onboardingCandidate, error) {
	return f.candidates, nil
}
func (f *fakeOnboardingRepo) LedgerFor(_ context.Context, id uuid.UUID) (map[string]onboardingLedgerEntry, error) {
	return f.ledger[id], nil
}
func (f *fakeOnboardingRepo) MarkSent(_ context.Context, id uuid.UUID, step string) error {
	f.sent = append(f.sent, step)
	return nil
}
func (f *fakeOnboardingRepo) MarkFailed(_ context.Context, id uuid.UUID, step, _ string) error {
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

func (f *fakeMailer) SendHTMLWithHeaders(to, subject, html, text string, headers []mailservice.Header) error {
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

func TestOnboardingTips_OneStepPerPersonPerRunAndGivesUpAfterFailures(t *testing.T) {
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
			givenUp.ID: {"day1-household": {FailedAttempts: onboardingMaxAttempts}},
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
}
