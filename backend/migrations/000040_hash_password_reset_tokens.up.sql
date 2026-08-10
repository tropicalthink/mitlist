DELETE FROM password_reset_tokens;
ALTER TABLE password_reset_tokens RENAME COLUMN token TO token_hash;
