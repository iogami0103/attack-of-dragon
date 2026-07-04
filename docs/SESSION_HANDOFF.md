# AIセッション引き継ぎログ

Windows PC と Mac の両方から Codex/Claude にこのリポジトリの作業をさせています。
どちらの端末で何をしたかが後から追えるように、セッションの終わりにこのファイルへ
記録を追記してください。**新しいエントリは一番上に追加**します（新しい順）。

## 書き方のルール

- 1セッション = 1エントリ。作業が小さくても必ず追記する。
- OS は `Windows` か `Mac` を明記する（どちらの端末で実行したセッションか）。
- ブランチ名と、あれば PR の番号/URLを書く。
- 「やったこと」は箇条書きで簡潔に。詳細はコミット/PRの差分を見ればわかるので、
  ここには要点と、次のセッションが知っておくべき前提・未完了・注意点だけ書く。
- 秘密情報（鍵・トークン・パスワードなど)は絶対に書かない。

## テンプレート

```markdown
## YYYY-MM-DD OS: Windows|Mac — 短いタイトル

- Branch: `branch-name`
- PR: #123 (or "未作成")
- やったこと:
  - ...
- 次のセッションへの申し送り:
  - ...
```

## ログ

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
