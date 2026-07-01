# Score Submit Worker

Cloudflare Workers 用のスコア投稿APIです。FlutterクライアントはこのWorkerへPOSTし、WorkerがGitHubの `scores/leaderboard.json` を更新します。

## GitHub側の準備

1. リポジトリ直下に `scores/leaderboard.json` を置きます。
2. GitHub Pagesを有効化し、`https://<owner>.github.io/<repo>/scores/leaderboard.json` で読める状態にします。
3. Fine-grained personal access tokenを作り、対象リポジトリのContentsをRead and writeにします。

## Workerの準備

```powershell
cd server\score-submit-worker
copy wrangler.toml.example wrangler.toml
wrangler secret put GITHUB_TOKEN
wrangler deploy
```

`wrangler.toml` の `GITHUB_OWNER`、`GITHUB_REPO`、`GITHUB_BRANCH`、`ALLOWED_ORIGIN` は公開先に合わせて変更してください。

## アプリ起動例

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome --dart-define=LEADERBOARD_URL=https://<owner>.github.io/<repo>/scores/leaderboard.json --dart-define=SCORE_SUBMIT_URL=https://<worker-name>.<account>.workers.dev
```

クライアントにはGitHubトークンを入れません。
