const DEFAULT_LEADERBOARD_PATH = 'scores/leaderboard.json';
const MAX_LEADERBOARD_ENTRIES = 10000;
const MAX_PLAYER_NAME_LENGTH = 14;

export default {
  async fetch(request, env) {
    const corsHeaders = buildCorsHeaders(request, env);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return jsonResponse(
        { ok: false, error: 'method_not_allowed' },
        405,
        corsHeaders,
      );
    }

    try {
      const entry = sanitizeScoreEntry(await request.json());
      const result = await submitWithRetry(entry, env);
      return jsonResponse({ ok: true, ...result }, 200, corsHeaders);
    } catch (error) {
      return jsonResponse(
        { ok: false, error: error.message || 'submit_failed' },
        error.status || 500,
        corsHeaders,
      );
    }
  },
};

async function submitWithRetry(entry, env) {
  let lastError;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      return await submitScore(entry, env);
    } catch (error) {
      lastError = error;
      if (error.status !== 409) break;
    }
  }
  throw lastError;
}

async function submitScore(entry, env) {
  const file = await fetchLeaderboardFile(env);
  const leaderboard = parseLeaderboard(file.text);
  const scores = [...leaderboard.scores, entry]
    .sort((a, b) => b.score - a.score)
    .slice(0, MAX_LEADERBOARD_ENTRIES);
  const nextText = `${JSON.stringify({ scores }, null, 2)}\n`;

  await writeLeaderboardFile(nextText, file.sha, env);

  return {
    rank: scores.findIndex((score) => score === entry) + 1,
    score: entry,
    total: scores.length,
  };
}

async function fetchLeaderboardFile(env) {
  const response = await githubFetch(env, 'GET');
  if (!response.ok) {
    throw httpError(
      response.status,
      `github_read_failed_${response.status}`,
    );
  }
  const json = await response.json();
  return {
    sha: json.sha,
    text: decodeBase64(json.content || ''),
  };
}

async function writeLeaderboardFile(text, sha, env) {
  const response = await githubFetch(env, 'PUT', {
    message: `Update leaderboard ${new Date().toISOString()}`,
    content: encodeBase64(text),
    sha,
    branch: env.GITHUB_BRANCH || 'main',
  });

  if (!response.ok) {
    throw httpError(
      response.status,
      `github_write_failed_${response.status}`,
    );
  }
}

async function githubFetch(env, method, body) {
  requireEnv(env, 'GITHUB_OWNER');
  requireEnv(env, 'GITHUB_REPO');
  requireEnv(env, 'GITHUB_TOKEN');

  const path = env.LEADERBOARD_PATH || DEFAULT_LEADERBOARD_PATH;
  const branch = env.GITHUB_BRANCH || 'main';
  const url = new URL(
    `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/contents/${path}`,
  );
  if (method === 'GET') {
    url.searchParams.set('ref', branch);
  }

  return fetch(url, {
    method,
    headers: {
      accept: 'application/vnd.github+json',
      authorization: `Bearer ${env.GITHUB_TOKEN}`,
      'content-type': 'application/json',
      'user-agent': 'attack-of-dragon-score-submit-worker',
      'x-github-api-version': '2022-11-28',
    },
    body: body == null ? undefined : JSON.stringify(body),
  });
}

function parseLeaderboard(text) {
  const value = JSON.parse(text);
  const rawScores = Array.isArray(value) ? value : value.scores;
  if (!Array.isArray(rawScores)) {
    throw httpError(500, 'invalid_leaderboard_json');
  }
  return {
    scores: rawScores
      .map(sanitizeScoreEntry)
      .sort((a, b) => b.score - a.score)
      .slice(0, MAX_LEADERBOARD_ENTRIES),
  };
}

function sanitizeScoreEntry(value) {
  const name = cleanName(`${value?.name || ''}`) || 'Player';
  const score = clampInteger(value?.score, 0, 999999999);
  const kills = clampInteger(value?.kills, 0, 999999);
  const date = cleanDate(value?.date);
  const version = cleanPlainText(`${value?.version || '1.0.0'}`, 32);

  return { name, score, kills, date, version };
}

function cleanName(value) {
  return cleanPlainText(value, MAX_PLAYER_NAME_LENGTH);
}

function cleanPlainText(value, maxLength) {
  return value
    .replace(/<[^>]*>/g, '')
    .replace(/https?:\/\/\S+/g, '')
    .replace(/[\x00-\x1f\x7f]/g, '')
    .trim()
    .slice(0, maxLength);
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
  const allowedOrigin = env.ALLOWED_ORIGIN || requestOrigin;
  return {
    'access-control-allow-origin': allowedOrigin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'content-type',
    vary: 'Origin',
  };
}

function jsonResponse(value, status, headers) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      ...headers,
      'content-type': 'application/json; charset=utf-8',
    },
  });
}

function requireEnv(env, key) {
  if (!env[key]) {
    throw httpError(500, `missing_${key.toLowerCase()}`);
  }
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function encodeBase64(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function decodeBase64(text) {
  const binary = atob(text.replace(/\s/g, ''));
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}
