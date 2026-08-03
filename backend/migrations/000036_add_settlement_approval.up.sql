-- Settlement approval flow: settlements start pending and only count toward
-- balances once the counterparty confirms.
ALTER TABLE settlements
    ADD COLUMN status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmed', 'declined')),
    ADD COLUMN created_by UUID REFERENCES users(id),
    ADD COLUMN responded_at TIMESTAMPTZ;

-- Pre-approval rows were live immediately; keep them counting.
UPDATE settlements SET status = 'confirmed', created_by = from_user_id;

ALTER TABLE settlements ALTER COLUMN created_by SET NOT NULL;

CREATE INDEX idx_settlements_group_status ON settlements (group_id, status);
