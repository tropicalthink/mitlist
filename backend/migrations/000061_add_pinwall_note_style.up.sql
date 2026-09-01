-- Per-note presentation on the pinwall: a chosen sticky-note color and a
-- card size. NULL means "no explicit choice" — the client falls back to its
-- id-hash palette color and the default size, so existing notes are unchanged.
ALTER TABLE pinwall_posts
    ADD COLUMN color TEXT,
    ADD COLUMN size TEXT;
