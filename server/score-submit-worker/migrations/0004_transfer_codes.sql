CREATE TABLE IF NOT EXISTS transfer_codes (
  code TEXT PRIMARY KEY,
  player_id TEXT NOT NULL,
  name TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  last_used_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_transfer_codes_expires_at
ON transfer_codes (expires_at);

CREATE INDEX IF NOT EXISTS idx_transfer_codes_player_created
ON transfer_codes (player_id, created_at DESC);
