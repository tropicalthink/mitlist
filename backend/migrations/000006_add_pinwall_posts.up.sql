-- =============================================================================
-- Pinwall
-- =============================================================================

CREATE TABLE pinwall_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pinwall_posts_group_created_at
    ON pinwall_posts (group_id, created_at DESC);

