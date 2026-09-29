-- Re-engagement check-in: one email asking for feedback after a person has
-- not opened the app for a week. It needs to know when someone last used the
-- app, which nothing recorded for full accounts until now (guests have their
-- own guest_last_seen_at).
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

-- The language the app shows this person, reported by the app itself (their
-- explicit choice, or the device language the app resolved to). Server-sent
-- email is written in it; NULL means the app has not reported one yet, and
-- mail falls back to English. Validated in the API, not here, so adding a
-- language needs no migration.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS language TEXT;

-- Backfill from the best evidence there is. A refresh session is minted every
-- time the app refreshes its 15-minute access token, so the newest one is
-- close to the last app open; sessions live 7 days, so anyone without one has
-- been away at least that long. Activity-log writes and the sign-up date are
-- the fallbacks, in that order, and only ever understate how recent the last
-- visit was.
UPDATE users u
SET last_active_at = COALESCE(
    (SELECT MAX(s.created_at) FROM auth_sessions s WHERE s.user_id = u.id),
    (SELECT MAX(a.created_at) FROM activity_logs a WHERE a.user_id = u.id),
    u.created_at
)
WHERE u.last_active_at IS NULL AND NOT u.is_guest AND u.deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_users_last_active_at
    ON users (last_active_at)
    WHERE deleted_at IS NULL AND NOT is_guest;

-- One row per (user, inactivity episode) is the idempotency ledger, reserved
-- before the mail provider is contacted, like onboarding_email_sends. The
-- episode is identified by the last_active_at the email was about, so coming
-- back and drifting away again is a new episode; the job additionally keeps a
-- cool-down between any two sends.
CREATE TABLE reengagement_email_sends (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    inactive_since TIMESTAMPTZ NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ,
    last_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, inactive_since)
);

CREATE INDEX idx_reengagement_email_sends_user_attempted
    ON reengagement_email_sends (user_id, attempted_at DESC);
