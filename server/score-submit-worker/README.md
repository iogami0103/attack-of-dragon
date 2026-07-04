# Score Submit Worker

Cloudflare Workers + D1 用のスコアAPIです。FlutterクライアントはこのWorkerへPOSTし、WorkerがD1へスコアを保存します。GETではD1から最新ランキングを返します。

## D1の準備

```powershell
C:\Users\iogam\bin\rtk.exe wrangler d1 create attack-of-the-dragon-scores
```

出力された `database_id` を `wrangler.toml` の `[[d1_databases]]` に設定します。

## Workerの準備

```powershell
cd server\score-submit-worker
copy wrangler.toml.example wrangler.toml
C:\Users\iogam\bin\rtk.exe wrangler d1 migrations apply attack-of-the-dragon-scores --remote
C:\Users\iogam\bin\rtk.exe wrangler deploy
```

`wrangler.toml` の `database_id` と `ALLOWED_ORIGIN` は公開先に合わせて変更してください。

## アプリ起動例

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome --dart-define=SCORE_SUBMIT_URL=https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev
```

## Google / Apple sign-in setup

Provider sign-in restores the existing game `playerId` by using the Google or
Apple account identity.
Set these Worker vars before deploying:

```toml
[vars]
GOOGLE_CLIENT_IDS = "472691784297-l323hbj6cm13ulsn8ul8cvvge956vedf.apps.googleusercontent.com,472691784297-hnide0eeomerg906ir2jf0884gu5s0cd.apps.googleusercontent.com"
APPLE_CLIENT_IDS = "io.github.iogami0103.attackofthedragon"
```

`GOOGLE_CLIENT_IDS` and `APPLE_CLIENT_IDS` may contain comma-separated values
when debug/release or Android/iOS use different OAuth client IDs.

For Flutter builds, pass the Google client IDs used by `google_sign_in`:

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d android --dart-define=SCORE_SUBMIT_URL=https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev
```

The app has the Google Web server client ID as a default. Override
`GOOGLE_SERVER_CLIENT_ID` only when using a different Google Cloud project.

iOS Sign in with Apple also requires the Apple Developer App ID capability
`Sign in with Apple` to be enabled for the app bundle ID.

`SCORE_SUBMIT_URL` を指定したクライアントは、スコア投稿だけでなくオンラインランキング取得にもこのWorkerを使います。クライアントにはD1の認証情報を入れません。

## Privacy policy

The same Worker also serves the store privacy policy:

- `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy`
- `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy.txt`
