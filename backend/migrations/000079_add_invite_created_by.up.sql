-- Who made an invite, so the signed-out preview of a code can say whose
-- household it is ("Sam invited you to Flat 3B", plans/048 stage 7).
-- Nullable: codes minted before this migration have no recorded inviter.
ALTER TABLE group_invites
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL;
