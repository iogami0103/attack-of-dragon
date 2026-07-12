import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import worker from './worker.js';

const baseUrl = 'https://worker.example';

test('privacy endpoints describe the current permanent deletion flow', async () => {
  for (const path of ['/privacy', '/privacy.txt']) {
    const response = await worker.fetch(new Request(`${baseUrl}${path}`), {});
    const body = await response.text();

    assert.equal(response.status, 200);
    assert.match(body, /2026-07-12/);
    assert.match(body, /permanently deletes the account link/i);
  }
});

test('rejects malformed and oversized request bodies before database access', async () => {
  const malformed = await worker.fetch(
    new Request(baseUrl, { method: 'POST', body: '{' }),
    {},
  );
  assert.equal(malformed.status, 400);
  assert.deepEqual(await malformed.json(), { ok: false, error: 'invalid_json' });

  const oversized = await worker.fetch(
    new Request(baseUrl, { method: 'POST', body: 'x'.repeat(16 * 1024 + 1) }),
    {},
  );
  assert.equal(oversized.status, 413);
  assert.deepEqual(await oversized.json(), {
    ok: false,
    error: 'request_too_large',
  });
});

test('deletion tombstones guard every score write', async () => {
  const workerSource = await readFile(new URL('./worker.js', import.meta.url), 'utf8');
  const migration = await readFile(
    new URL('./migrations/0008_deleted_players.sql', import.meta.url),
    'utf8',
  );

  assert.match(migration, /CREATE TABLE IF NOT EXISTS deleted_players/);
  assert.match(workerSource, /INSERT INTO deleted_players/);
  assert.equal(
    workerSource.match(/SELECT 1 FROM deleted_players WHERE player_id = \?/g)
      ?.length,
    4,
  );
  assert.match(workerSource, /playerId\.startsWith\('legacy:'\)/);
});
