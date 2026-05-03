DROP INDEX IF EXISTS idx_pinwall_posts_linked_entity;

ALTER TABLE pinwall_posts
  DROP COLUMN IF EXISTS linked_entity_type,
  DROP COLUMN IF EXISTS linked_entity_id;
