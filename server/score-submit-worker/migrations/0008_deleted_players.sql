CREATE TABLE IF NOT EXISTS deleted_players (
  player_id TEXT PRIMARY KEY,
  deleted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_deleted_players_deleted_at
ON deleted_players (deleted_at);

CREATE INDEX IF NOT EXISTS idx_run_tokens_player_id
ON run_tokens (player_id);
