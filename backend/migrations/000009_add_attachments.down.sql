DROP INDEX IF EXISTS idx_pinwall_post_attachments_attachment_id;
DROP INDEX IF EXISTS idx_pinwall_post_attachments_post_id;
DROP TABLE IF EXISTS pinwall_post_attachments;

DROP INDEX IF EXISTS idx_expense_attachments_attachment_id;
DROP INDEX IF EXISTS idx_expense_attachments_expense_id;
DROP TABLE IF EXISTS expense_attachments;

DROP INDEX IF EXISTS idx_attachments_group_object_key;
DROP INDEX IF EXISTS idx_attachments_group_purpose;
DROP INDEX IF EXISTS idx_attachments_group_created_at;
DROP TABLE IF EXISTS attachments;

