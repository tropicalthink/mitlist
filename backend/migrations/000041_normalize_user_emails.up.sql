DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM users
        GROUP BY LOWER(BTRIM(email))
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'cannot normalize user emails: case-insensitive duplicates exist';
    END IF;
END $$;

UPDATE users SET email = LOWER(BTRIM(email));
CREATE UNIQUE INDEX users_email_normalized_unique ON users (LOWER(BTRIM(email)));
