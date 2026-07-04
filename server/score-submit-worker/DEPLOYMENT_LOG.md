# Deployment Log

## 2026-07-04

### `fb85b23d-948e-456a-b016-84f9145db2f5`

- Reason: Revert `APPLE_CLIENT_IDS` to `io.github.iogami0103.attackofthedragon`. The bundle ID turned out to already exist in the same Apple team as an Xcode-generated App ID (with Sign In with Apple enabled), so the temporary rename to `com.tatsuya.attackofthedragon` (version `465be8e3`) was unnecessary and has been rolled back.
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Verification: `GET /?period=all` returned `200` with leaderboard JSON.

### `465be8e3-ad15-45c5-b14b-27f3cd3fa819`

- Reason: Update `APPLE_CLIENT_IDS` to `com.tatsuya.attackofthedragon` (superseded by `fb85b23d`; see above).
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Verification: `GET /?period=all` returned `200` with leaderboard JSON.

### `1990c5e2-8c23-491d-9984-7afadff8dfb0`

- Reason: Update privacy policy for the non-consumable ad removal purchase.
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Verification:
  - `GET /privacy` returned `200` and included the in-app purchase section.
  - `GET /privacy.txt` returned `200` and included the in-app purchase section.
  - `GET /?period=all` returned `200` with leaderboard JSON.

### `4632b65f-5418-4e12-8440-941fcda76dea`

- Reason: Publish the store privacy policy from the Cloudflare Worker and keep the ranking API on the same Worker.
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Privacy policy:
  - `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy`
  - `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy.txt`
- Verification:
  - `GET /privacy` returned `200` with `text/html; charset=utf-8`.
  - `GET /privacy.txt` returned `200` with `text/plain; charset=utf-8`.
  - `GET /?period=all` returned `200` with leaderboard JSON.

### `8f97bfc1-5834-4472-9cca-dc6fcd197e0e`

- Reason: Remove the static JSON ranking path; keep rankings on Cloudflare Worker + D1 only.
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- CORS origin: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Verification:
  - `GET /` returned `200` with leaderboard JSON.
  - `OPTIONS /` returned `204` with `GET, POST, OPTIONS`.

### `beb58dec-56d4-46d4-954d-c27e906fc313`

- Reason: Update `APPLE_CLIENT_IDS` to `io.github.iogami0103.attackofthedragon`.
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Verification: `GET /` returned `200` with leaderboard JSON.

### `08632e2a-6f90-4230-b13e-522e98fd642c`

- Wrangler: `npx wrangler`
- D1 remote migrations: no pending migrations
- Worker: `attack-of-the-dragon-score-submit`
- URL: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev`
- Version ID: `08632e2a-6f90-4230-b13e-522e98fd642c`
- Verification: `GET /` returned `200` with leaderboard JSON.
