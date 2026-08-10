CREATE TABLE auth_login_limits (
    identifier TEXT PRIMARY KEY,
    attempt_count INTEGER NOT NULL,
    window_started_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_auth_login_limits_window
    ON auth_login_limits (window_started_at);
