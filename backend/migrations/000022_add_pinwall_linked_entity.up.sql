ALTER TABLE pinwall_posts
  ADD COLUMN linked_entity_type VARCHAR(50),
  ADD COLUMN linked_entity_id UUID;

CREATE INDEX idx_pinwall_posts_linked_entity ON pinwall_posts(linked_entity_type, linked_entity_id);
