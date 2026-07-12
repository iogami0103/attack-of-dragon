const LEADERBOARD_TITLE = 'Attack of the Dragon';
const MAX_LEADERBOARD_ENTRIES = 10000;
const MAX_SCORE_HISTORY_ENTRIES = 50000;
const SCORE_HISTORY_RETENTION_DAYS = 35;
const MAX_PLAYER_ID_LENGTH = 64;
const MAX_PLAYER_NAME_LENGTH = 14;
const RUN_TOKEN_TTL_SECONDS = 30 * 60;
const GOOGLE_JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
const APPLE_ISSUER = 'https://appleid.apple.com';
const PRIVACY_POLICY_TEXT = `Attack of the Dragon Privacy Policy

Last updated: 2026-07-06

Attack of the Dragon stores gameplay data only for running the game, showing rankings, restoring an account link, serving ads, and remembering whether the ad removal purchase is active.

Data stored on this device:
- Settings such as player name, player identifier, and volume.
- Local score history.
- Whether the non-consumable ad removal purchase has been enabled.

Data sent to the online ranking service:
- Player identifier, player name, score, defeated enemy count, play date, and game version.
- The public leaderboard may show player name, score, defeated enemy count, play date, and game version.

Account linking:
- If you use Google Sign-In or Sign in with Apple, the app sends the provider identity token to the Cloudflare Worker only to verify the account and restore the same player identifier.
- The ranking service stores the provider name, provider account subject identifier, player identifier, and player name.
- The service does not store your email address from the provider token.

Ads:
- The mobile app uses Google Mobile Ads. Google and its partners may process advertising identifiers, device information, IP address, and ad interaction data to provide and measure ads.
- You can manage ad personalization in your device or Google account settings where available.

In-app purchases:
- The app offers a non-consumable ad removal purchase.
- Payments are processed by Google Play or Apple App Store. The app does not collect or store payment card information.
- The app stores only whether ad removal has been enabled on the device.

Infrastructure:
- Online ranking and account-link data are processed by Cloudflare Workers and stored in Cloudflare D1.
- The app does not sell personal data.

Data deletion:
- To request deletion of your Attack of the Dragon account-link data, online ranking data, or both, contact the developer through the contact information shown on the app's store listing. Include your player name and, if available, your player identifier.
- Deleted online ranking data includes player identifier, player name, score, defeated enemy count, play date, and game version. Deleted account-link data includes provider name, provider account subject identifier, player identifier, and player name.
- Deletion requests are normally completed within 30 days. Data that must be kept for security, fraud prevention, or legal reasons may be retained for up to 90 days before being deleted or anonymized. Online score history entries are automatically pruned after 35 days; leaderboard best scores and account-link data are kept until you request deletion or the service is no longer needed.
- Local data stored on your device can be removed by clearing the app's data or uninstalling the app. Purchase records are managed by Google Play or Apple App Store, and advertising data is managed by Google and its partners according to their privacy controls.

Third-party services:
- Google Sign-In: https://policies.google.com/privacy
- Sign in with Apple: https://www.apple.com/legal/privacy/
- Google Mobile Ads: https://policies.google.com/privacy
- Google Play: https://policies.google.com/privacy
- Apple App Store: https://www.apple.com/legal/privacy/
- Cloudflare: https://www.cloudflare.com/privacypolicy/
`;

const jwksCache = new Map();

export default {
  async fetch(request, env) {
    const corsHeaders = buildCorsHeaders(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    try {
      if (request.method === 'GET') {
        const url = new URL(request.url);
        if (url.pathname === '/privacy' || url.pathname === '/privacy/') {
          return textResponse(
            privacyPolicyHtml(),
            200,
            'text/html; charset=utf-8',
            corsHeaders,
          );
        }
        if (url.pathname === '/privacy.txt') {
          return textResponse(
            PRIVACY_POLICY_TEXT,
            200,
            'text/plain; charset=utf-8',
            corsHeaders,
          );
        }

        const leaderboard = await loadLeaderboard(env, request);
        return jsonResponse(leaderboardToJson(leaderboard), 200, corsHeaders);
      }

      if (request.method !== 'POST') {
        return jsonResponse(
          { ok: false, error: 'method_not_allowed' },
          405,
          corsHeaders,
        );
      }

      const body = await request.json().catch(() => {
        throw httpError(400, 'invalid_json');
      });
      const action = cleanPlainText(`${body?.action || ''}`, 32);
      if (action === 'authenticateProvider') {
        const player = await authenticateProvider(body, env);
        return jsonResponse({ ok: true, player }, 200, corsHeaders);
      }
      if (action === 'startRun') {
        const run = await startRun(body, env);
        return jsonResponse({ ok: true, ...run }, 200, corsHeaders);
      }
      if (action) {
        return jsonResponse(
          { ok: false, error: 'unknown_action' },
          400,
          corsHeaders,
        );
      }

      const entry = sanitizeScoreEntry(body);
      const result = await submitScore(entry, env);
      return jsonResponse({ ok: true, ...result }, 200, corsHeaders);
    } catch (error) {
      const isHttpError = error?.isHttpError === true;
      return jsonResponse(
        { ok: false, error: isHttpError ? error.message : 'internal_error' },
        isHttpError ? error.status : 500,
        corsHeaders,
      );
    }
  },
};

function privacyPolicyHtml() {
  return `<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Attack of the Dragon Privacy Policy</title>
<style>
  :root { color-scheme: light; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  body { margin: 0; background: #fff8ed; color: #2f1f18; line-height: 1.6; }
  main { max-width: 820px; margin: 0 auto; padding: 40px 20px 56px; }
  h1 { font-size: clamp(1.8rem, 5vw, 3rem); line-height: 1.1; margin: 0 0 8px; }
  h2 { margin: 28px 0 8px; font-size: 1.15rem; }
  p, li { font-size: 1rem; }
  ul { padding-left: 1.35rem; }
  a { color: #9b3d1a; }
</style>
<main>
  <h1>Attack of the Dragon Privacy Policy</h1>
  <p><strong>Last updated:</strong> 2026-07-06</p>
  <p>Attack of the Dragon stores gameplay data only for running the game, showing rankings, restoring an account link, serving ads, and remembering whether the ad removal purchase is active.</p>

  <h2>Data stored on this device</h2>
  <ul>
    <li>Settings such as player name, player identifier, and volume.</li>
    <li>Local score history.</li>
    <li>Whether the non-consumable ad removal purchase has been enabled.</li>
  </ul>

  <h2>Data sent to the online ranking service</h2>
  <ul>
    <li>Player identifier, player name, score, defeated enemy count, play date, and game version.</li>
    <li>The public leaderboard may show player name, score, defeated enemy count, play date, and game version.</li>
  </ul>

  <h2>Account linking</h2>
  <ul>
    <li>If you use Google Sign-In or Sign in with Apple, the app sends the provider identity token to the Cloudflare Worker only to verify the account and restore the same player identifier.</li>
    <li>The ranking service stores the provider name, provider account subject identifier, player identifier, and player name.</li>
    <li>The service does not store your email address from the provider token.</li>
  </ul>

  <h2>Ads</h2>
  <ul>
    <li>The mobile app uses Google Mobile Ads. Google and its partners may process advertising identifiers, device information, IP address, and ad interaction data to provide and measure ads.</li>
    <li>You can manage ad personalization in your device or Google account settings where available.</li>
  </ul>

  <h2>In-app purchases</h2>
  <ul>
    <li>The app offers a non-consumable ad removal purchase.</li>
    <li>Payments are processed by Google Play or Apple App Store. The app does not collect or store payment card information.</li>
    <li>The app stores only whether ad removal has been enabled on the device.</li>
  </ul>

  <h2>Infrastructure</h2>
  <ul>
    <li>Online ranking and account-link data are processed by Cloudflare Workers and stored in Cloudflare D1.</li>
    <li>The app does not sell personal data.</li>
  </ul>

  <h2>Data deletion</h2>
  <p>To request deletion of your Attack of the Dragon account-link data, online ranking data, or both, contact the developer through the contact information shown on the app's store listing. Include your player name and, if available, your player identifier.</p>
  <p>Deleted online ranking data includes player identifier, player name, score, defeated enemy count, play date, and game version. Deleted account-link data includes provider name, provider account subject identifier, player identifier, and player name.</p>
  <p>Deletion requests are normally completed within 30 days. Data that must be kept for security, fraud prevention, or legal reasons may be retained for up to 90 days before being deleted or anonymized. Online score history entries are automatically pruned after 35 days; leaderboard best scores and account-link data are kept until you request deletion or the service is no longer needed.</p>
  <p>Local data stored on your device can be removed by clearing the app's data or uninstalling the app. Purchase records are managed by Google Play or Apple App Store, and advertising data is managed by Google and its partners according to their privacy controls.</p>

  <h2>Third-party services</h2>
  <ul>
    <li><a href="https://policies.google.com/privacy">Google Sign-In and Google Mobile Ads</a></li>
    <li><a href="https://www.apple.com/legal/privacy/">Sign in with Apple</a></li>
    <li><a href="https://policies.google.com/privacy">Google Play</a></li>
    <li><a href="https://www.apple.com/legal/privacy/">Apple App Store</a></li>
    <li><a href="https://www.cloudflare.com/privacypolicy/">Cloudflare</a></li>
  </ul>
</main>
</html>`;
}

async function submitScore(entry, env) {
  const db = requireDb(env);
  await consumeRunToken(entry, env);
  await db
    .prepare(
      `INSERT INTO scores (player_id, name, score, kills, date, version)
       VALUES (?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      entry.playerId,
      entry.name,
      entry.score,
      entry.kills,
      entry.date,
      entry.version,
    )
    .run();
  await upsertPlayerBest(entry, env);
  const rank = await rankForPlayerBest(entry.playerId, env);

  await pruneScoreHistory(env);
  await pruneRunTokens(env);

  const leaderboard = await loadLeaderboard(env);
  return {
    ...leaderboard.meta,
    rank,
    score: publicScoreEntry(entry),
    total: leaderboard.total,
    scores: leaderboard.scores,
  };
}

async function startRun(value, env) {
  const db = requireDb(env);
  const playerId = cleanPlayerId(`${value?.playerId || value?.player_id || ''}`);
  if (!playerId) throw httpError(400, 'invalid_player_id');

  const runToken = randomRunToken();
  const expiresAt = new Date(Date.now() + RUN_TOKEN_TTL_SECONDS * 1000)
    .toISOString();
  await db
    .prepare(
      `INSERT INTO run_tokens (token, player_id, expires_at)
       VALUES (?, ?, ?)`,
    )
    .bind(runToken, playerId, expiresAt)
    .run();
  return { runToken, expiresAt };
}

async function consumeRunToken(entry, env) {
  const token = cleanRunToken(entry.runToken || '');
  if (!token) throw httpError(403, 'missing_run_token');

  const db = requireDb(env);
  const result = await db
    .prepare(
      `UPDATE run_tokens
       SET used_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
       WHERE token = ?
         AND player_id = ?
         AND used_at IS NULL
         AND expires_at > strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    )
    .bind(token, entry.playerId)
    .run();
  if ((result?.meta?.changes ?? 0) !== 1) {
    throw httpError(403, 'invalid_run_token');
  }
}

async function authenticateProvider(value, env) {
  const db = requireDb(env);
  const provider = normalizeProvider(`${value?.provider || ''}`);
  if (!provider) throw httpError(400, 'invalid_provider');

  const idToken = `${value?.idToken || value?.identityToken || ''}`.trim();
  if (!idToken) throw httpError(400, 'missing_id_token');

  const identity =
    provider === 'google'
      ? await verifyGoogleIdToken(idToken, env)
      : await verifyAppleIdentityToken(idToken, env);
  const requestedPlayerId = cleanPlayerId(
    `${value?.playerId || value?.player_id || ''}`,
  );
  const fallbackPlayerId = requestedPlayerId || serverGeneratedPlayerId();
  const requestedName = cleanName(`${value?.name || ''}`) || 'Dragon';

  const existing = await providerAccountForIdentity(
    db,
    provider,
    identity.subject,
  );

  if (existing) {
    const name = await nameForPlayerId(
      existing.player_id,
      existing.name || requestedName,
      env,
    );
    return {
      provider,
      playerId: existing.player_id,
      name,
    };
  }

  await db
    .prepare(
      `INSERT INTO provider_accounts (
         provider, subject, player_id, name, updated_at
       )
       VALUES (?, ?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
       ON CONFLICT(provider, subject) DO NOTHING`,
    )
    .bind(provider, identity.subject, fallbackPlayerId, requestedName)
    .run();

  const account = await providerAccountForIdentity(
    db,
    provider,
    identity.subject,
  );
  if (account) {
    const name = await nameForPlayerId(
      account.player_id,
      account.name || requestedName,
      env,
    );
    return {
      provider,
      playerId: account.player_id,
      name,
    };
  }

  throw httpError(500, 'account_link_failed');
}

async function providerAccountForIdentity(db, provider, subject) {
  return db
    .prepare(
      `SELECT player_id, name
       FROM provider_accounts
       WHERE provider = ? AND subject = ?`,
    )
    .bind(provider, subject)
    .first();
}

async function nameForPlayerId(playerId, fallbackName, env) {
  const db = requireDb(env);
  const bestName = await db
    .prepare(
      `SELECT name
       FROM player_bests
       WHERE player_id = ?`,
    )
    .bind(playerId)
    .first('name');
  return cleanName(`${bestName || fallbackName || ''}`) || 'Dragon';
}

async function upsertPlayerBest(entry, env) {
  const db = requireDb(env);
  await db
    .prepare(
      `INSERT INTO player_bests (
         player_id, name, score, kills, date, version, updated_at
       )
       VALUES (?, ?, ?, ?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
       ON CONFLICT(player_id) DO UPDATE SET
         name = excluded.name,
         score = CASE
           WHEN excluded.score > player_bests.score
             OR (excluded.score = player_bests.score
                 AND excluded.date < player_bests.date)
           THEN excluded.score
           ELSE player_bests.score
         END,
         kills = CASE
           WHEN excluded.score > player_bests.score
             OR (excluded.score = player_bests.score
                 AND excluded.date < player_bests.date)
           THEN excluded.kills
           ELSE player_bests.kills
         END,
         date = CASE
           WHEN excluded.score > player_bests.score
             OR (excluded.score = player_bests.score
                 AND excluded.date < player_bests.date)
           THEN excluded.date
           ELSE player_bests.date
         END,
         version = CASE
           WHEN excluded.score > player_bests.score
             OR (excluded.score = player_bests.score
                 AND excluded.date < player_bests.date)
           THEN excluded.version
           ELSE player_bests.version
         END,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    )
    .bind(
      entry.playerId,
      entry.name,
      entry.score,
      entry.kills,
      entry.date,
      entry.version,
    )
    .run();
}

async function loadLeaderboard(env, request = null) {
  const query = leaderboardQueryFromRequest(request);
  if (query.period === 'all') {
    return loadAllTimeLeaderboard(env, query.period);
  }
  return loadPeriodLeaderboard(env, query);
}

async function loadAllTimeLeaderboard(env, period) {
  const db = requireDb(env);
  const { results = [] } = await db
    .prepare(
      `SELECT player_id, name, score, kills, date, version
       FROM player_bests
       ORDER BY score DESC, date ASC, player_id ASC
       LIMIT ?`,
    )
    .bind(MAX_LEADERBOARD_ENTRIES)
    .all();
  const total =
    (await db
      .prepare('SELECT COUNT(*) AS total FROM player_bests')
      .first('total')) ??
    results.length;

  return {
    meta: { title: LEADERBOARD_TITLE, period },
    scores: results.map(scoreFromRow),
    total,
  };
}

async function loadPeriodLeaderboard(env, query) {
  const db = requireDb(env);
  const { results = [] } = await db
    .prepare(
      `SELECT player_id, name, score, kills, date, version
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
           ) AS rank_in_period
         FROM scores
         WHERE date >= ? AND date < ?
       )
       WHERE rank_in_period = 1
       ORDER BY score DESC, date ASC, player_id ASC
       LIMIT ?`,
    )
    .bind(query.from, query.to, MAX_LEADERBOARD_ENTRIES)
    .all();
  const total =
    (await db
      .prepare(
        `SELECT COUNT(DISTINCT player_id) AS total
         FROM scores
         WHERE date >= ? AND date < ?`,
      )
      .bind(query.from, query.to)
      .first('total')) ?? results.length;

  return {
    meta: {
      title: LEADERBOARD_TITLE,
      period: query.period,
      from: query.from,
      to: query.to,
    },
    scores: results.map(scoreFromRow),
    total,
  };
}

async function rankForPlayerBest(playerId, env) {
  const db = requireDb(env);
  const best = await db
    .prepare(
      `SELECT player_id, score, date
       FROM player_bests
       WHERE player_id = ?`,
    )
    .bind(playerId)
    .first();
  if (!best) return 1;
  const rank =
    (await db
      .prepare(
        `SELECT COUNT(*) + 1 AS rank
         FROM player_bests
         WHERE score > ?
            OR (
              score = ?
              AND (
                date < ?
                OR (date = ? AND player_id < ?)
              )
            )`,
      )
      .bind(best.score, best.score, best.date, best.date, best.player_id)
      .first('rank')) ?? 1;
  return Number(rank);
}

async function pruneScoreHistory(env) {
  const db = requireDb(env);
  await db
    .prepare(
      `DELETE FROM scores
       WHERE date < strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?)`,
    )
    .bind(`-${SCORE_HISTORY_RETENTION_DAYS} days`)
    .run();
  await db
    .prepare(
      `DELETE FROM scores
       WHERE id NOT IN (
         SELECT id
         FROM scores
         ORDER BY date DESC, id DESC
         LIMIT ?
       )`,
    )
    .bind(MAX_SCORE_HISTORY_ENTRIES)
    .run();
}

async function pruneRunTokens(env) {
  const db = requireDb(env);
  await db
    .prepare(
      `DELETE FROM run_tokens
       WHERE expires_at < strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-1 day')
          OR used_at IS NOT NULL`,
    )
    .run();
}

function leaderboardQueryFromRequest(request) {
  if (!request) return { period: 'all' };

  const url = new URL(request.url);
  const rawPeriod = cleanPlainText(
    `${url.searchParams.get('period') || 'all'}`,
    16,
  );
  const period = normalizePeriod(rawPeriod);
  if (period === 'all') return { period };

  return {
    period,
    ...dateRangeFromQuery(url.searchParams, period),
  };
}

function normalizePeriod(value) {
  if (value === 'today' || value === 'week' || value === 'month') {
    return value;
  }
  return 'all';
}

function dateRangeFromQuery(searchParams, period) {
  const from = parseDateParam(searchParams.get('from'));
  const to = parseDateParam(searchParams.get('to'));
  if (from && to && from.getTime() < to.getTime()) {
    return {
      from: from.toISOString(),
      to: to.toISOString(),
    };
  }

  const days = period === 'today' ? 1 : period === 'week' ? 7 : 30;
  const now = new Date();
  const toUtcDay = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1),
  );
  const fromUtcDay = new Date(toUtcDay);
  fromUtcDay.setUTCDate(toUtcDay.getUTCDate() - days);
  return {
    from: fromUtcDay.toISOString(),
    to: toUtcDay.toISOString(),
  };
}

function parseDateParam(value) {
  if (!value) return null;
  const parsed = new Date(`${value}`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function verifyGoogleIdToken(idToken, env) {
  const token = parseJwt(idToken);
  if (token.header.alg !== 'RS256') throw httpError(401, 'invalid_id_token');

  await verifyJwtSignature({
    token,
    jwksUrl: GOOGLE_JWKS_URL,
    algorithm: { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
  });

  validateJwtClaims(token.payload, {
    issuers: GOOGLE_ISSUERS,
    audiences: acceptedAudiences(env, [
      'GOOGLE_CLIENT_IDS',
      'GOOGLE_CLIENT_ID',
      'GOOGLE_SERVER_CLIENT_ID',
    ]),
  });

  return { subject: `${token.payload.sub}` };
}

async function verifyAppleIdentityToken(idToken, env) {
  const token = parseJwt(idToken);
  // Appleのidentity tokenはRS256署名(ES256は開発者側client secret用)。
  if (token.header.alg !== 'RS256') throw httpError(401, 'invalid_id_token');

  await verifyJwtSignature({
    token,
    jwksUrl: APPLE_JWKS_URL,
    algorithm: { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
  });

  validateJwtClaims(token.payload, {
    issuers: [APPLE_ISSUER],
    audiences: acceptedAudiences(env, [
      'APPLE_CLIENT_IDS',
      'APPLE_CLIENT_ID',
      'APPLE_BUNDLE_ID',
    ]),
  });

  return { subject: `${token.payload.sub}` };
}

function parseJwt(value) {
  const parts = `${value}`.split('.');
  if (parts.length !== 3) throw httpError(401, 'invalid_id_token');
  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  return {
    signingInput: `${encodedHeader}.${encodedPayload}`,
    signature: base64UrlToBytes(encodedSignature),
    header: parseJwtJson(encodedHeader),
    payload: parseJwtJson(encodedPayload),
  };
}

function parseJwtJson(value) {
  try {
    const text = new TextDecoder().decode(base64UrlToBytes(value));
    return JSON.parse(text);
  } catch (_) {
    throw httpError(401, 'invalid_id_token');
  }
}

async function verifyJwtSignature({ token, jwksUrl, algorithm }) {
  const kid = `${token.header.kid || ''}`;
  if (!kid) throw httpError(401, 'invalid_id_token');

  const jwk = await jwkForKeyId(jwksUrl, kid);
  const key = await crypto.subtle.importKey(
    'jwk',
    jwk,
    algorithm,
    false,
    ['verify'],
  );
  const verified = await crypto.subtle.verify(
    algorithm.name === 'ECDSA' ? { name: 'ECDSA', hash: 'SHA-256' } : algorithm,
    key,
    token.signature,
    new TextEncoder().encode(token.signingInput),
  );
  if (!verified) throw httpError(401, 'invalid_id_token');
}

async function jwkForKeyId(jwksUrl, kid) {
  const now = Date.now();
  const cached = jwksCache.get(jwksUrl);
  if (cached && cached.expiresAt > now) {
    const jwk = cached.keys.find((key) => key.kid === kid);
    if (jwk) return jwk;
  }

  const response = await fetch(jwksUrl);
  if (!response.ok) throw httpError(503, 'jwks_unavailable');
  const jwks = await response.json();
  const keys = Array.isArray(jwks?.keys) ? jwks.keys : [];
  jwksCache.set(jwksUrl, {
    keys,
    expiresAt: now + 60 * 60 * 1000,
  });
  const jwk = keys.find((key) => key.kid === kid);
  if (!jwk) throw httpError(401, 'invalid_id_token');
  return jwk;
}

function validateJwtClaims(payload, { issuers, audiences }) {
  if (!payload || typeof payload !== 'object') {
    throw httpError(401, 'invalid_id_token');
  }
  if (!issuers.includes(`${payload.iss || ''}`)) {
    throw httpError(401, 'invalid_token_issuer');
  }
  const subject = `${payload.sub || ''}`;
  if (!subject) throw httpError(401, 'invalid_token_subject');

  const tokenAudiences = Array.isArray(payload.aud)
    ? payload.aud.map((value) => `${value}`)
    : [`${payload.aud || ''}`];
  if (
    audiences.length === 0 ||
    !tokenAudiences.some((audience) => audiences.includes(audience))
  ) {
    throw httpError(401, 'invalid_token_audience');
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (Number(payload.exp || 0) <= nowSeconds) {
    throw httpError(401, 'id_token_expired');
  }
  if (payload.nbf != null && Number(payload.nbf) > nowSeconds + 60) {
    throw httpError(401, 'id_token_not_yet_valid');
  }
}

function acceptedAudiences(env, keys) {
  const values = [];
  for (const key of keys) {
    const raw = `${env[key] || ''}`;
    for (const value of raw.split(',')) {
      const clean = value.trim();
      if (clean) values.push(clean);
    }
  }
  return values;
}

function base64UrlToBytes(value) {
  const base64 = `${value}`.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function leaderboardToJson(leaderboard) {
  return {
    ...leaderboard.meta,
    total: leaderboard.total,
    scores: leaderboard.scores,
  };
}

function scoreFromRow(row) {
  return publicScoreEntry(
    sanitizeScoreEntry({
      playerId: row.player_id,
      name: row.name,
      score: row.score,
      kills: row.kills,
      date: row.date,
      version: row.version,
    }),
  );
}

function publicScoreEntry(entry) {
  return {
    name: entry.name,
    score: entry.score,
    kills: entry.kills,
    date: entry.date,
    version: entry.version,
  };
}

function sanitizeScoreEntry(value) {
  const name = cleanName(`${value?.name || ''}`) || 'Dragon';
  const playerId =
    cleanPlayerId(`${value?.playerId || value?.player_id || ''}`) ||
    legacyPlayerIdForName(name);
  const score = clampInteger(value?.score, 0, 999999999);
  const kills = clampInteger(value?.kills, 0, 999999);
  const date = cleanDate(value?.date);
  const version = cleanPlainText(`${value?.version || '1.0.0'}`, 32);
  const runToken = cleanRunToken(`${value?.runToken || value?.run_token || ''}`);

  return { playerId, name, score, kills, date, version, runToken };
}

function cleanName(value) {
  return cleanPlainText(value, MAX_PLAYER_NAME_LENGTH);
}

function cleanPlayerId(value) {
  return value
    .replace(/[^a-zA-Z0-9._:-]/g, '')
    .trim()
    .slice(0, MAX_PLAYER_ID_LENGTH);
}

function cleanRunToken(value) {
  return value.replace(/[^a-fA-F0-9]/g, '').trim().slice(0, 64);
}

function normalizeProvider(value) {
  const clean = cleanPlainText(value, 16).toLowerCase();
  return clean === 'google' || clean === 'apple' ? clean : '';
}

function serverGeneratedPlayerId() {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  const hex = Array.from(bytes, (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('');
  return `p${hex}`;
}

function randomRunToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function legacyPlayerIdForName(name) {
  const bytes = new TextEncoder().encode(name.toLowerCase());
  const hex = Array.from(bytes, (byte) =>
    byte.toString(16).padStart(2, '0'),
  ).join('');
  return `legacy:${hex.slice(0, MAX_PLAYER_ID_LENGTH - 7) || 'dragon'}`;
}

function cleanPlainText(value, maxLength) {
  const clean = value
    .replace(/<[^>]*>/g, '')
    .replace(/https?:\/\/\S+/g, '')
    .replace(/[\x00-\x1f\x7f]/g, '')
    .trim();
  return Array.from(clean).slice(0, maxLength).join('');
}

function cleanDate(value) {
  const parsed = new Date(`${value || ''}`);
  if (Number.isNaN(parsed.getTime())) {
    return new Date().toISOString();
  }
  return parsed.toISOString();
}

function clampInteger(value, min, max) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw httpError(400, 'invalid_score_payload');
  }
  return Math.max(min, Math.min(max, Math.round(number)));
}

function buildCorsHeaders(request, env) {
  const requestOrigin = request.headers.get('origin') || '*';
  const allowedOrigins = `${env.ALLOWED_ORIGIN || ''}`
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const allowedOrigin = allowedOrigins.length === 0
    ? requestOrigin
    : allowedOrigins.includes(requestOrigin)
      ? requestOrigin
      : allowedOrigins[0];
  return {
    'access-control-allow-origin': allowedOrigin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    vary: 'Origin',
  };
}

function jsonResponse(value, status, headers) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      ...headers,
      'cache-control': 'no-store',
      'content-type': 'application/json; charset=utf-8',
    },
  });
}

function textResponse(value, status, contentType, headers) {
  return new Response(value, {
    status,
    headers: {
      ...headers,
      'cache-control': 'public, max-age=3600',
      'content-type': contentType,
    },
  });
}

function requireDb(env) {
  if (!env.DB || typeof env.DB.prepare !== 'function') {
    throw httpError(500, 'missing_d1_binding');
  }
  return env.DB;
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  error.isHttpError = true;
  return error;
}
