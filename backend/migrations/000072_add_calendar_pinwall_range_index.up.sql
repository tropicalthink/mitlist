-- The existing delivery index excludes reminders that were already sent.
-- Calendar history includes both sent and unsent reminders, scoped by group.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_pinwall_posts_group_remind_at
    ON pinwall_posts (group_id, remind_at)
    WHERE remind_at IS NOT NULL;
