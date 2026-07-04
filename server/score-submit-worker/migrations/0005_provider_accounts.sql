CREATE TABLE IF NOT EXISTS provider_accounts (
  provider TEXT NOT NULL,
  subject TEXT NOT NULL,
  player_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  PRIMARY KEY (provider, subject)
);

CREATE INDEX IF NOT EXISTS idx_provider_accounts_player_id
ON provider_accounts (player_id);
