# ローカル秘密情報の復元手順

このファイルには秘密情報そのものを書きません。GitHub にはコード、assets、example、手順だけを置き、署名鍵や本番設定は各PCのローカルに復元します。

## GitHub に入っているもの

- Flutter/Dart のコード
- `assets/` 配下の画像、音声、フォント、同梱データ
- Android/iOS/Web/Worker の通常ソース
- `android/key.properties.example`
- `server/score-submit-worker/wrangler.toml.example`

## 別保管が必要なもの

パスワード管理アプリ、暗号化ZIP、外付けバックアップなど、GitHub とは別の安全な場所に保管します。

- `android/key.properties`
- `android/key.properties` の `storeFile` が指す keystore。現在のexampleでは `android/app/upload-keystore.jks`
- `server/score-submit-worker/wrangler.toml`
- 必要になった場合の `server/score-submit-worker/.dev.vars`
- 必要になった場合の `GoogleService-Info.plist`
- 必要になった場合の `google-services.json`
- Apple Developer / App Store Connect / Google Play Console / AdMob / Cloudflare / GitHub のログイン情報
- Apple の証明書、秘密鍵、provisioning profile など、Xcode や Keychain に入る署名情報

## Mac で復元する流れ

1. GitHub からプロジェクトを clone する。

```bash
git clone https://github.com/iogami0103/attack-of-dragon.git
cd attack-of-dragon
```

2. 安全な保管場所からローカル秘密情報を戻す。

```bash
cp /path/to/secure/attack-of-dragon/android/key.properties android/key.properties
cp /path/to/secure/attack-of-dragon/android/app/upload-keystore.jks android/app/upload-keystore.jks
cp /path/to/secure/attack-of-dragon/server/score-submit-worker/wrangler.toml server/score-submit-worker/wrangler.toml
```

3. Xcode で Apple ID / Apple Developer Team / signing certificate を設定する。

4. GitHub CLI を使う場合はログインする。

```bash
gh auth status
gh auth login
```

5. ローカル秘密情報の配置と Git 除外を確認する。

```bash
bash tools/local_secret_inventory.sh
```

## Windows で確認する流れ

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\local_secret_inventory.ps1
```

## Codex に作業させるときの注意

- Codex は秘密ファイルの中身を読み上げたり、コミットしたりしない。
- 必要なときは「存在確認」「Git除外確認」「ビルドに使えるかの確認」だけを行う。
- 秘密ファイルを更新した場合は、GitHub ではなく安全な保管場所のバックアップも更新する。
- GitHub Actions で本番ビルドをする場合は、通常ファイルではなく GitHub Secrets に入れる。

## 確認コマンド

通常のGitHub作業確認:

```bash
bash tools/local_secret_inventory.sh
```

Windows:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\local_secret_inventory.ps1
```

コード変更を含む場合:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1 -RunFlutterChecks
```
