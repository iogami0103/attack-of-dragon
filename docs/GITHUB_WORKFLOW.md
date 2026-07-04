# GitHub 作業手順

このプロジェクトは Windows PC、Mac、Android スマホ、クラウド環境から同じ GitHub リポジトリを使います。
各端末の Codex/Claude セッションは GitHub を共有状態として扱い、作業状況は `docs/SESSION_HANDOFF.md` で引き継ぎます。

- Repository: `https://github.com/iogami0103/attack-of-dragon`
- Default branch: `main`
- Codex work branch prefix: `codex/`

## Windows 側の準備

このPCでは Codex のシェルコマンドを必ず RTK 経由で実行します。

```powershell
C:\Users\iogam\bin\rtk.exe git status --short --branch
```

このリポジトリではローカル設定として以下を入れています。

```powershell
C:\Users\iogam\bin\rtk.exe git config --local pull.ff only
C:\Users\iogam\bin\rtk.exe git config --local fetch.prune true
```

これにより、履歴がずれている状態で不用意な merge commit を作らず、消えたリモートブランチも整理されます。

## 作業開始前

Windows PC / Mac のローカル作業では、開始時に必ず最新化します。

```powershell
C:\Users\iogam\bin\rtk.exe git fetch --prune origin
C:\Users\iogam\bin\rtk.exe git status --short --branch
C:\Users\iogam\bin\rtk.exe git pull --ff-only
```

`git pull --ff-only` が失敗した場合は、Windows と Mac の変更が分岐しています。無理に解消せず、差分を確認してから作業します。

Android スマホの Claude やブラウザだけで作業する場合は、GitHub 上で以下を確認してから作業します。

- `main` の最新コミット
- 関連する open PR / Issue / Actions
- `docs/SESSION_HANDOFF.md` の最新エントリ

## Codex で作業する場合

通常の変更は `codex/<作業名>` ブランチを作って進めます。

```powershell
C:\Users\iogam\bin\rtk.exe git switch -c codex/short-task
```

小さなリポジトリ整理だけをユーザーが直接依頼している場合は、`main` に直接コミットして push しても構いません。

## 確認

作業前後の GitHub 向けチェックをまとめて実行できます。

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1
```

コード変更を含む場合:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1 -RunFlutterChecks
```

Android のビルド設定に触った場合:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1 -RunFlutterChecks -BuildDebugApk
```

## GitHub CLI

このPCには GitHub CLI (`gh`) を入れています。PR作成や GitHub 側の確認をローカルで行う前に、認証状態を確認します。

```powershell
C:\Users\iogam\bin\rtk.exe gh auth status
```

未ログインの場合、ブラウザ承認が必要です。

```powershell
C:\Users\iogam\bin\rtk.exe gh auth login
```

## セッションの引き継ぎ

Windows PC、Mac、Android スマホ、クラウド環境のどの端末・どの AI で作業したかが後から分かるように、
セッション終了前に `docs/SESSION_HANDOFF.md` に記録を追記します。
書き方のルールとテンプレートはそのファイルの先頭にあります。

各セッションは次の順序で作業します。

1. GitHub の最新状態と `docs/SESSION_HANDOFF.md` の最新エントリを読む。
2. 作業するブランチ、PR、未完了事項を確認する。
3. 作業・検証を行う。
4. 終了前に `docs/SESSION_HANDOFF.md` の先頭へ Device / AI / Branch / PR / 次の申し送りを追記する。
5. 変更を commit / push し、必要なら PR を作成または更新する。

Android スマホではローカルビルドや秘密情報を使う作業は避け、状況確認、Issue/PR コメント、軽い編集、申し送り追記を中心に行います。

## コミットしないもの

以下はローカル設定または秘密情報です。`.gitignore` で除外済みですが、コミット前にも確認します。

- `android/key.properties`
- keystore / certificate / provisioning profile
- `GoogleService-Info.plist`
- `google-services.json`
- `.env` files
- `server/score-submit-worker/wrangler.toml`
- `build/`, `.dart_tool/`, `ios/Pods/`, `.wrangler/`
