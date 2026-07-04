CREATE TABLE IF NOT EXISTS run_tokens (
  token TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  issued_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  expires_at TEXT NOT NULL,
  used_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_run_tokens_cleanup
ON run_tokens (expires_at, used_at);
