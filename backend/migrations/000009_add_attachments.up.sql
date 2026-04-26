-- =============================================================================
-- Attachments
-- =============================================================================

CREATE TABLE attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose TEXT NOT NULL,
    object_key TEXT NOT NULL,
    content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    byte_size BIGINT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_attachments_group_created_at ON attachments (group_id, created_at DESC);
CREATE INDEX idx_attachments_group_purpose ON attachments (group_id, purpose);
CREATE UNIQUE INDEX idx_attachments_group_object_key ON attachments (group_id, object_key);

-- =============================================================================
-- Attachment joins
-- =============================================================================

CREATE TABLE expense_attachments (
    expense_id UUID NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
    attachment_id UUID NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (expense_id, attachment_id)
);

CREATE INDEX idx_expense_attachments_expense_id ON expense_attachments (expense_id);
CREATE INDEX idx_expense_attachments_attachment_id ON expense_attachments (attachment_id);

CREATE TABLE pinwall_post_attachments (
    pinwall_post_id UUID NOT NULL REFERENCES pinwall_posts(id) ON DELETE CASCADE,
    attachment_id UUID NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (pinwall_post_id, attachment_id)
);

CREATE INDEX idx_pinwall_post_attachments_post_id ON pinwall_post_attachments (pinwall_post_id);
CREATE INDEX idx_pinwall_post_attachments_attachment_id ON pinwall_post_attachments (attachment_id);

