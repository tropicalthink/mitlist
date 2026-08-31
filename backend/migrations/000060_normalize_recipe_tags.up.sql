-- Hand-entered tags were stored verbatim while the scraper and the tag filter
-- both use trimmed lowercase, so a stored "Dessert" could be listed in the
-- filter bar but never matched by it (`tags @> '["dessert"]'`). Fold every
-- existing row into the shape the filter queries with.

UPDATE recipes
SET tags = COALESCE(
    (
        SELECT jsonb_agg(DISTINCT lower(btrim(t)))
        FROM jsonb_array_elements_text(COALESCE(tags, '[]'::jsonb)) AS t
        WHERE btrim(t) <> ''
    ),
    '[]'::jsonb
)
WHERE COALESCE(tags, '[]'::jsonb) <> '[]'::jsonb;
