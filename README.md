# Attack of Dragon

Flutter で実装した縦画面向けエンドレス飛行アクションです。

## 実行

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome
```

ビルド済みWeb版を確認する場合:

```powershell
C:\Users\iogam\bin\rtk.exe flutter build web
C:\Users\iogam\bin\rtk.exe python -m http.server 8080 --bind 127.0.0.1 -d build\web
```

## オンラインスコア

オンラインランキングを読む場合は、GitHub Pagesなどで公開したJSONのURLを渡してビルドします。このリポジトリでは公開用の初期データを `scores/leaderboard.json` に置いています。

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome --dart-define=LEADERBOARD_URL=https://iogami0103.github.io/attack-of-dragon/scores/leaderboard.json
```

スコア投稿用の安全なエンドポイントを用意した場合は、`SCORE_SUBMIT_URL` も指定できます。GitHub の書き込みトークンをクライアントへ埋め込まない方針です。

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome --dart-define=LEADERBOARD_URL=https://iogami0103.github.io/attack-of-dragon/scores/leaderboard.json --dart-define=SCORE_SUBMIT_URL=https://attack-of-dragon-score-submit.i-ogami-0103.workers.dev
```

投稿エンドポイントの雛形は `server/score-submit-worker` にあります。Cloudflare Workersにデプロイし、Worker側の `GITHUB_TOKEN` シークレットでGitHub上の `scores/leaderboard.json` を更新します。

## アセット

- 背景と音声は `D:\Documents\ActionMaker-Steam` 由来の素材をコピーして使用しています。
- ドラゴン、敵、炎のスプライトは imagegen で生成し、クロマキー背景を透過処理して使用しています。
