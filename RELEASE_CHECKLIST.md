# Release Checklist

このチェックリストは、ストア提出または公開ビルドを作る直前に確認する。

## ローカル品質ゲート

- [x] `C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\release_check.ps1`
- [x] `C:\Users\iogam\bin\rtk.exe flutter analyze`
- [x] `C:\Users\iogam\bin\rtk.exe flutter test`
- [x] `C:\Users\iogam\bin\rtk.exe flutter build web --release`
- [x] `C:\Users\iogam\bin\rtk.exe flutter build appbundle --release`
- [x] `C:\Users\iogam\bin\rtk.exe flutter build windows --release`
- [x] `C:\Users\iogam\bin\rtk.exe node --check server/score-submit-worker/worker.js`
- [x] `artifacts/release-2026-07-04` に AAB / Web zip / Windows zip / SHA-256 を作成する。
- [ ] GitHub Actions の `Flutter CI` が通っていることを確認する。

## Android

- [x] 本番 `applicationId` を `io.github.iogami0103.attackofthedragon` に確定する。
- [ ] Google Play App Signing を使うか、リリース keystore を使うかを確定する。
- [ ] Google Play Console で非消耗型のアプリ内商品 `remove_ads` を作成し、価格を `300 JPY` に設定する。
- [x] `android/key.properties.example` を `android/key.properties` にコピーし、実際の keystore 情報を入れる。
- [x] `android/key.properties` と keystore が `git status` に出ていないことを確認する。
- [x] `android/upload-key-fingerprints.txt` の SHA-1 を Google OAuth Android クライアントへ登録する。(2026-07-04 登録済み: クライアント名 `Attack of the Dragon Android Upload`)
- [x] `C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\release_check.ps1 -RequireReleaseSigning`
- [x] Google OAuth の Android クライアントに本番 `applicationId` と SHA-1 を登録する。(2026-07-04 完了: upload 鍵 SHA-1 / `io.github.iogami0103.attackofthedragon`)
- [ ] AdMob の Android アプリ設定が本番 `applicationId` と一致していることを確認する。

## iOS

- [x] 本番 bundle ID を `io.github.iogami0103.attackofthedragon` に確定する。(2026-07-04: 同名の Xcode 自動生成 App ID が既にチーム内に存在し、それをそのまま使用)
- [x] App Store Connect で非消耗型のアプリ内課金 `remove_ads` を作成し、価格を 300円相当に設定する。(2026-07-04 完了: ASC アプリ「Attack of the Dragon」(Apple ID 6787345039, SKU `attackofthedragon`) を作成し、非消耗型 `remove_ads` を基準価格 日本 ¥300 で作成。日本語ローカリゼーション「広告削除」設定済み。審査用スクリーンショットは初回提出時に追加が必要)
- [x] Apple Developer で `Sign in with Apple` capability を有効化する。(2026-07-04 確認: 既存 App ID `io.github.iogami0103.attackofthedragon` (XC 自動生成) に Sign In with Apple (primary) が有効化済みだった。チーム 95RP2F687Q)
- [ ] provisioning profile を更新する。
- [ ] AdMob の iOS アプリ設定が本番 bundle ID と一致していることを確認する。
- [ ] Mac/Xcode 環境で archive / TestFlight 提出を確認する。

## Cloudflare Worker / D1

- [x] 本番 D1 database に migrations を適用する。
- [x] Worker vars の `ALLOWED_ORIGIN` / `GOOGLE_CLIENT_IDS` / `APPLE_CLIENT_IDS` を本番設定にする。ランキングは Cloudflare Worker + D1 だけで完結させる。
- [x] `C:\Users\iogam\bin\rtk.exe wrangler deploy` で本番 Worker を deploy する。
- [x] 実機からランキング取得、run token 発行、スコア投稿、ログイン復元を確認する。(2026-07-04 Google ログイン・復元を実機確認。2026-07-05 iPhone 実機で Apple ログイン復旧を確認)

## 公開情報と権利表記

- [x] アプリ側に広告削除の非消耗型 IAP `remove_ads` を実装する。
- [x] Cloudflare Worker の `/privacy` でプライバシーポリシーを公開し、ストア提出用 URL として使えることを確認する。
- [x] `STORE_METADATA_JA.md` にストア掲載文面と申告メモの下書きを作成する。
- [ ] ストア説明文、スクリーンショット、アイコン、年齢レーティングを確定する。
- [x] 配布ページまたはアプリ内に必要なクレジットを載せる。
- [x] 音声クレジット: `Music: YouFulca (https://youfulca.com/)`
- [x] フォントクレジット: `M PLUS Rounded 1c (SIL Open Font License 1.1)`
- [x] 効果音クレジットが必要な配布先では `SFX: The Ultimate 2017 16 bit Mini pack (CC0)` を記載する。
