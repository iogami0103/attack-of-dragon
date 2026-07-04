INSERT INTO scores (name, score, kills, date, version)
SELECT 'Dragon72993001', 5332, 184, '2026-07-01T19:54:42.097Z', '1.0.0'
WHERE NOT EXISTS (
  SELECT 1 FROM scores
  WHERE name = 'Dragon72993001'
    AND score = 5332
    AND date = '2026-07-01T19:54:42.097Z'
);

INSERT INTO scores (name, score, kills, date, version)
SELECT 'SkyRider', 1840, 23, '2026-07-01T00:00:00.000Z', '1.0.0'
WHERE NOT EXISTS (
  SELECT 1 FROM scores
  WHERE name = 'SkyRider'
    AND score = 1840
    AND date = '2026-07-01T00:00:00.000Z'
);

INSERT INTO scores (name, score, kills, date, version)
SELECT 'Hinoko', 1320, 18, '2026-07-01T00:00:00.000Z', '1.0.0'
WHERE NOT EXISTS (
  SELECT 1 FROM scores
  WHERE name = 'Hinoko'
    AND score = 1320
    AND date = '2026-07-01T00:00:00.000Z'
);

INSERT INTO scores (name, score, kills, date, version)
SELECT 'Player', 960, 11, '2026-07-01T00:00:00.000Z', '1.0.0'
WHERE NOT EXISTS (
  SELECT 1 FROM scores
  WHERE name = 'Player'
    AND score = 960
    AND date = '2026-07-01T00:00:00.000Z'
);
