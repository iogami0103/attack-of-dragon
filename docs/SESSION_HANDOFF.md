# AIセッション引き継ぎログ

Windows PC、Mac、Android スマホ、クラウド環境から Codex/Claude にこのリポジトリの作業をさせています。
どの端末・どの AI セッションで何をしたかが後から追えるように、セッションの終わりにこのファイルへ
記録を追記してください。**新しいエントリは一番上に追加**します（新しい順）。

## 共有運用

- GitHub を唯一の共有状態として扱う。作業開始時は必ず最新の `main`、関連 PR、直近のこのログを確認する。
- Windows PC / Mac のローカル作業では、開始時に `git fetch --prune origin`、`git status --short --branch`、`git pull --ff-only` を実行する。
- Android スマホの Claude やブラウザだけで作業する場合は、GitHub 上の `main`、PR、Actions、このファイルを確認してから編集・コメント・PR 作成を行う。
- 端末やセッションが変わっても、次の AI はこのファイルの最新エントリから作業状況を把握する。
- 同じファイルを複数端末で同時に編集しない。特にこのファイルは全端末が追記するため、作業開始前と終了前に GitHub の最新版を確認する。
- ローカルビルド、Flutter テスト、秘密情報を使う作業は Windows PC または Mac で行う。Android スマホは状況確認、Issue/PR、軽い編集、申し送りの追記に使う。

## 書き方のルール

- 1セッション = 1エントリ。作業が小さくても必ず追記する。
- 端末は `Windows`、`Mac`、`Android`、`Cloud` などで明記する。
- AI は `Codex`、`Claude` などで明記する。
- ブランチ名と、あれば PR の番号/URLを書く。
- 「やったこと」は箇条書きで簡潔に。詳細はコミット/PRの差分を見ればわかるので、
  ここには要点と、次のセッションが知っておくべき前提・未完了・注意点だけ書く。
- 秘密情報（鍵・トークン・パスワードなど)は絶対に書かない。

## テンプレート

```markdown
## YYYY-MM-DD Device: Windows|Mac|Android|Cloud / AI: Codex|Claude — 短いタイトル

- Branch: `branch-name`
- PR: #123 (or "未作成")
- やったこと:
  - ...
- 次のセッションへの申し送り:
  - ...
```

## ログ

## 2026-07-04 Device: Windows / AI: Codex — 複数端末セッション共有の運用を明文化

- Branch: `main`
- PR: 未作成
- やったこと:
  - Windows PC、Mac、Android スマホ、クラウド環境の各 Claude/Codex セッションが GitHub を共有状態として作業できる運用を追記
  - 作業開始時の最新確認、終了時のログ追記、Android スマホで担当しやすい作業範囲を明文化
  - テンプレートを OS だけでなく Device / AI を残す形式に更新
- 次のセッションへの申し送り:
  - 以後の端末・AI は作業開始時にこのファイルの最新エントリを読み、作業終了前に必ず先頭へ追記すること
  - 同じファイルの同時編集を避け、GitHub の最新状態を確認してから作業すること

## 2026-07-04 OS: Windows — GitHub/main へ引き継ぎログを取り込み

- Branch: `main`
- PR: #1 `Add AI session handoff log tracked in GitHub`
- やったこと:
  - Windows PC で作成済みの起動コマンド整理コミットを保持したまま、`origin/main` の最新変更をマージ
  - `origin/claude/current-task-review-kecpaf` を `main` にマージし、`docs/SESSION_HANDOFF.md` を追加
  - `AGENTS.md` と `docs/GITHUB_WORKFLOW.md` のセッション引き継ぎルールを取り込み
- 次のセッションへの申し送り:
  - `main` はローカルでマージ済み。GitHub へ反映するには、このログ追記コミット後に通常の検証と push が必要
  - この Windows PC では iPhone wrapper は不要。Android/PC は GitHub 最新版起動とローカル作業ツリー起動の 2 種類を維持する

## 2026-07-04 OS: (Claude Code on the web / クラウド環境) — 引き継ぎログの仕組みを新規導入

- Branch: `claude/current-task-review-kecpaf`
- PR: 未作成（このコミットで新規作成予定）
- やったこと:
  - このファイル (`docs/SESSION_HANDOFF.md`) を新規作成し、セッション引き継ぎの記録先として運用開始
  - `AGENTS.md` と `docs/GITHUB_WORKFLOW.md` に、セッション終了時にこのログへ追記するルールを追加
- 次のセッションへの申し送り:
  - 今後、Windows PC / Mac のどちらでセッションを実行しても、作業終了前に必ずこのログにエントリを追加すること
  - 過去の作業内容（例: ローカル秘密情報の復元手順追加など）はこのログ導入前のものなので、詳細は `git log` / マージ済みPRを参照
