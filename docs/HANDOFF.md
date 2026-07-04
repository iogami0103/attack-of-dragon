# Session Handoff

次のセッション/別マシンへの引き継ぎ事項。完了した項目は削除するか「完了」に移動する。

## 未完了: Cloudflare Worker の再デプロイ(Windows で実施)

- 日付: 2026-07-04(Mac セッション)
- 症状: iPhone 実機でアプリ設定画面から Apple ログインすると
  「Apple の認証情報をサーバーが拒否しました。bundle ID / OAuth client ID設定を確認してください。」が出る。
- 原因: `server/score-submit-worker/worker.js` の `verifyAppleIdentityToken` が
  identity token を ES256 前提で検証していた。Apple の identity token は RS256 署名
  (`https://appleid.apple.com/auth/keys` の公開鍵は全て RSA/RS256)のため、正規トークンが全て
  401 `invalid_id_token` で拒否されていた。ES256 は開発者側が作る client secret 用。
- 修正: このブランチで alg 判定を RS256 に変更し、署名検証を Google と同じ
  `RSASSA-PKCS1-v1_5` + SHA-256 にした。`APPLE_CLIENT_IDS`(= bundle ID)は一致済みで問題なし。

### Windows での手順

1. このブランチ(`codex/fix-apple-token-verification`)を GitHub で確認してマージし、`main` を pull する。
2. `server/score-submit-worker/` で(ローカルの `wrangler.toml` がある前提。`docs/LOCAL_SECRETS.md` 参照):

   ```powershell
   npx wrangler deploy
   ```

3. デプロイ後の確認:
   - `GET https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/?period=all` が 200 を返す。
   - iPhone 実機のアプリ設定画面から Apple ログインを再試行し、「Appleでログインしました。」が出る。
4. `server/score-submit-worker/DEPLOYMENT_LOG.md` に Version ID・理由・検証結果を追記してコミットする。
