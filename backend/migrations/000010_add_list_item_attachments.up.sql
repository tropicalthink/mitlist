-- =============================================================================
-- List item attachments (photos)
-- =============================================================================

CREATE TABLE list_item_attachments (
    list_item_id UUID NOT NULL REFERENCES list_items(id) ON DELETE CASCADE,
    attachment_id UUID NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (list_item_id, attachment_id)
);

CREATE INDEX idx_list_item_attachments_item_id ON list_item_attachments (list_item_id);
CREATE INDEX idx_list_item_attachments_attachment_id ON list_item_attachments (attachment_id);

