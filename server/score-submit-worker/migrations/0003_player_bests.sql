ALTER TABLE scores ADD COLUMN player_id TEXT NOT NULL DEFAULT '';

UPDATE scores
SET player_id = 'legacy:' || lower(hex(lower(name)))
WHERE player_id = '';

CREATE TABLE IF NOT EXISTS player_bests (
  player_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  kills INTEGER NOT NULL,
  date TEXT NOT NULL,
  version TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

INSERT OR REPLACE INTO player_bests (
  player_id,
  name,
  score,
  kills,
  date,
  version,
  updated_at
)
SELECT
  player_id,
  name,
  score,
  kills,
  date,
  version,
  strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
FROM (
  SELECT
    player_id,
    name,
    score,
    kills,
    date,
    version,
    ROW_NUMBER() OVER (
      PARTITION BY player_id
      ORDER BY score DESC, date ASC, id ASC
    ) AS rank_for_player
  FROM scores
)
WHERE rank_for_player = 1;

CREATE INDEX IF NOT EXISTS idx_scores_period_user_best
ON scores (date DESC, player_id, score DESC, id ASC);

CREATE INDEX IF NOT EXISTS idx_scores_player_best
ON scores (player_id, score DESC, date ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_player_bests_rank
ON player_bests (score DESC, date ASC, player_id ASC);
