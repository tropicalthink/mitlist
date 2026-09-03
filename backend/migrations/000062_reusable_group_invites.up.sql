-- Invite codes are no longer one-shot: a code admits anyone who presents it
-- until expires_at, so the single-use bookkeeping goes away. Existing codes
-- keep their deadline and become reusable for whatever is left of it.
ALTER TABLE group_invites
    DROP COLUMN IF EXISTS used_by,
    DROP COLUMN IF EXISTS used_at;
