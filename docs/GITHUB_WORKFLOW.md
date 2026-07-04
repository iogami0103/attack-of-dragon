# GitHub 作業手順

このプロジェクトは Windows と Mac の両方から同じ GitHub リポジトリを使います。

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

```powershell
C:\Users\iogam\bin\rtk.exe git fetch --prune origin
C:\Users\iogam\bin\rtk.exe git status --short --branch
C:\Users\iogam\bin\rtk.exe git pull --ff-only
```

`git pull --ff-only` が失敗した場合は、Windows と Mac の変更が分岐しています。無理に解消せず、差分を確認してから作業します。

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

Windows と Mac のどちらで作業したセッションかが後から分かるように、
セッション終了前に `docs/SESSION_HANDOFF.md` に記録を追記します。
書き方のルールとテンプレートはそのファイルの先頭にあります。

## コミットしないもの

以下はローカル設定または秘密情報です。`.gitignore` で除外済みですが、コミット前にも確認します。

- `android/key.properties`
- keystore / certificate / provisioning profile
- `GoogleService-Info.plist`
- `google-services.json`
- `.env` files
- `server/score-submit-worker/wrangler.toml`
- `build/`, `.dart_tool/`, `ios/Pods/`, `.wrangler/`
