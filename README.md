# Attack of the Dragon

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

オンラインランキングは Cloudflare Worker と D1 だけで提供します。クライアントには D1 の認証情報を埋め込まず、公開可能な Worker URL だけを持たせます。リリースビルドでは本番 Worker URL がデフォルトで入るため、`SCORE_SUBMIT_URL` の指定は不要です。

デバッグビルドや検証用 Worker に接続する場合だけ、必要に応じて `SCORE_SUBMIT_URL` を指定します。

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d chrome --dart-define=SCORE_SUBMIT_URL=https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev
```

Worker は `GET` で最新ランキングを返し、`POST` でスコアを D1 に保存して更新後ランキングを即時に返します。

ランキング対象のプレイは、開始時に Worker の `startRun` アクションで発行した一回限りの run token が必要です。オフライン開始などで token を取得できないプレイはローカルスコアのみ保存され、オンライン復帰後に後出し送信されません。

API の実装と D1 migration は `server/score-submit-worker` にあります。

## プライバシーポリシー

ストア提出用のプライバシーポリシーは Cloudflare Worker から公開します。

- HTML: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy`
- Text: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy.txt`

内容の控えは `PRIVACY_POLICY.md` にあります。

## AdMob

`google_mobile_ads` を使って、モバイル版で下部バナーとリトライ時インターステシャルを表示します。AdMob上には未公開アプリとして `Attack of the Dragon` をAndroid/iOSそれぞれ作成済みです。

本番ID:

- Android App ID: `ca-app-pub-9107759780289476~7128186132`
- Android banner: `ca-app-pub-9107759780289476/4502022797`
- Android interstitial: `ca-app-pub-9107759780289476/3188941125`
- iOS App ID: `ca-app-pub-9107759780289476~3856979361`
- iOS banner: `ca-app-pub-9107759780289476/6874024949`
- iOS interstitial: `ca-app-pub-9107759780289476/9562777787`

デバッグビルドでは既定でGoogle公式のテスト広告ユニットIDを使います。リリースビルドでは本番広告ユニットIDを使います。デバッグで本番IDを使う場合は `--dart-define=ADMOB_USE_TEST_IDS=false` を指定します。

```powershell
C:\Users\iogam\bin\rtk.exe flutter run -d android `
  --dart-define=ADMOB_USE_TEST_IDS=false
```

インターステシャルはリトライ回数ではなく、1プレイが3分以上続いた後にリトライを押したときだけ表示します。

## 広告削除のアプリ内課金

広告削除は非消耗型のアプリ内課金として実装しています。

- Product ID: `remove_ads`
- 価格: 300円
- 効果: 購入または復元後、バナー広告とリトライ時インターステシャルを表示しない

価格はアプリ内の参考表示も `¥300` にしていますが、実際の請求価格は Google Play Console と App Store Connect の商品設定で `300 JPY` にします。

## Android リリース署名

Google Play に提出する AAB は本番のアップロード鍵で署名します。`android/key.properties.example` を `android/key.properties` にコピーして、実際の keystore 情報へ置き換えてください。`android/key.properties` と keystore ファイルはコミットしません。

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\generate_android_upload_key.ps1
C:\Users\iogam\bin\rtk.exe flutter build appbundle --release
```

`android/key.properties` がない場合、ローカル検証用に debug signing へフォールバックします。その AAB はストア提出用ではありません。

現在の upload key の SHA-1 / SHA-256 は `android/upload-key-fingerprints.txt` に記録しています。Google OAuth の Android クライアントには SHA-1 を登録します。

本番 `applicationId` / iOS bundle ID は `io.github.iogami0103.attackofthedragon` です。Google OAuth、AdMob、Apple Developer、Cloudflare Worker の許可設定もこの ID と一致させます。

提出直前の確認項目は `RELEASE_CHECKLIST.md` にまとめています。

ローカルの主要ゲートをまとめて確認する場合:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\release_check.ps1
```

ストア提出直前に Android 本番署名設定も必須確認する場合:

```powershell
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\release_check.ps1 -RequireReleaseSigning
```

## アセット

- 背景と音声は `D:\Documents\ActionMaker-Steam` 由来の素材をコピーして使用しています。
- ドラゴン、敵、炎のスプライトは imagegen で生成し、クロマキー背景を透過処理して使用しています。
- アプリ内の設定画面にリリース用クレジットを表示しています。
- 音声クレジット: `Music: YouFulca (https://youfulca.com/)`
- フォントクレジット: `Font: M PLUS Rounded 1c (SIL Open Font License 1.1)`
- 効果音クレジット: `SFX: The Ultimate 2017 16 bit Mini pack (CC0)`
