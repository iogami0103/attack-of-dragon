# AIセッション引き継ぎログ

Windows PC、Mac、Android スマホ、クラウド環境から Codex/Claude にこのリポジトリの作業をさせています。
どの端末・どの AI セッションで何をしたかが後から追えるように、セッションの終わりにこのファイルへ
記録を追記してください。**新しいエントリは一番上に追加**します（新しい順）。

## 共有運用

- GitHub を唯一の共有状態として扱う。作業開始時は必ず最新の `main`、関連 PR、直近のこのログを確認する。
- Windows PC / Mac のローカル作業では、開始時にプラットフォームごとの RTK 経由で `git fetch --prune origin`、`git status --short --branch`、`git pull --ff-only` を実行する。
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

## 2026-07-06 Device: Mac / AI: Codex — Mac RTK 手順を追加

- Branch: `main`
- PR: 未作成
- やったこと:
  - `AGENTS.md` と GitHub 作業ドキュメントを、Mac では `/opt/homebrew/bin/rtk` を使う前提に更新。
  - `tools/github_workflow_check.sh` を追加し、Mac でも RTK 経由で GitHub 作業チェック、Flutter analyze/test、必要時の debug APK build を実行できるようにした。
  - `tools/install_ios_to_iphone.sh` と `tools/local_secret_inventory.sh` の Git 呼び出しも Mac RTK を優先するようにした。
  - `/opt/homebrew/bin/rtk bash tools/github_workflow_check.sh --skip-fetch --run-flutter-checks` は通過。
- 次のセッションへの申し送り:
  - Mac では Windows の `C:\Users\iogam\bin\rtk.exe` ではなく `/opt/homebrew/bin/rtk` を使う。
  - PowerShell がない Mac では `tools/github_workflow_check.ps1` ではなく `tools/github_workflow_check.sh` を使う。

## 2026-07-06 Device: Mac / AI: Codex — iPhoneインストール元選択を追加

- Branch: `main`
- PR: 未作成
- やったこと:
  - `tools/install_ios_to_iphone.sh` に `INSTALL_SOURCE_MODE` を追加し、ローカル作業ツリー、ローカル変更優先、GitHub最新版キャッシュの各モードを選べるようにした。
  - macOS ダブルクリック用に「GitHub最新版」と「ローカル変更」の2種類の `.command` ラッパーを追加した。
  - Mac で `flutter analyze` と `flutter test` は通過。
- 次のセッションへの申し送り:
  - この Mac には `powershell` / `pwsh` がないため、Windows専用RTKに依存する `tools/github_workflow_check.ps1 -RunFlutterChecks` は直接実行不可。Macでは同等の Flutter チェックを個別実行する。
  - 必要なら iPhone 実機で2種類の `.command` をダブルクリックして、GitHub最新版インストールとローカル変更インストールの挙動を確認する。

## 2026-07-05 Device: Windows / AI: Codex — iOS広告提出設定とCI整合性対応

- Branch: `codex/release-prep-fixes`
- PR: 未作成
- やったこと:
  - `ios/Runner/Info.plist` に Google公式ドキュメント (2026-07-01更新) の `SKAdNetworkItems` 50件を追加。
  - `ios/Runner/Info.plist` に `ITSAppUsesNonExemptEncryption` = false を追加し、提出時の輸出暗号申告を簡略化できる状態にした。
  - `origin/codex/release-2026-07-05` の iOS LaunchImage 差し替えコミットを取り込み、1x/2x/3x launch image と storyboard のサイズ指定を更新。
  - `.github/workflows/flutter-ci.yml` を追加し、チェックリスト上の `Flutter CI` 確認項目とリポジトリ実体を揃えた。
  - `tools/github_workflow_check.ps1` が upstream 未設定の新規ブランチで失敗する問題と、RTK の clean status 出力 `ok` を作業ツリー変更として誤判定する問題を修正。
  - `RELEASE_CHECKLIST.md` を更新し、古い `artifacts/release-2026-07-04` 成果物は現在の提出対象として作り直しが必要な扱いに戻した。
  - `test/widget_test.dart` に iOS `Info.plist` の広告アトリビューション設定と輸出暗号設定の検証を追加。
  - `tools\github_workflow_check.ps1 -RunFlutterChecks` は通過。
- 次のセッションへの申し送り:
  - ローカルコミット済み。push / PR は未実施なので、push後に GitHub Actions の `Flutter CI` 成功を確認する。
  - `gh` はこのWindows環境で未ログイン。PR作成まで行う場合は `gh auth login` が必要。
  - 提出用 AAB / Web zip / Windows zip / SHA-256 と、Mac/Xcode の iOS archive / IPA / TestFlight は、このブランチまたは取り込み後の最新コミットから作り直す。
  - App Store Connect の契約同意、AdMob iOS/Android アプリ設定確認、iOS ATT ダイアログの実機 fresh install 確認は引き続き外部作業として残る。

## 2026-07-05 Device: Mac / AI: Codex — Flutter CI と Mac リリース確認

- Branch: `codex/release-2026-07-05`
- PR: #3 https://github.com/iogami0103/attack-of-dragon/pull/3
- やったこと:
  - `origin/main` からクリーンな release worktree `/Users/user/Documents/Attack_of_the_Dragon_release_worktree` を作成し、元の作業ツリーの未コミット差分には触れずに作業。
  - `.github/workflows/flutter-ci.yml` を追加し、`Flutter CI` で `flutter pub get` / `flutter analyze` / `flutter test` / `flutter build web --release` / `flutter build apk --debug` / `node --check server/score-submit-worker/worker.js` を実行するようにした。
  - `app_tracking_transparency` 追加後の `ios/Podfile.lock` を `pod install` で更新し、Linux CI の Android build 用に `android/gradlew` の実行権限を付与。
  - Mac ローカルで `flutter pub get`、`flutter analyze`、`flutter test`、`flutter build web --release`、`flutter build apk --debug`、`node --check server/score-submit-worker/worker.js`、`git diff --check` は通過。
  - GitHub CLI token に `workflow` scope を追加し、`codex/release-2026-07-05` を push。GitHub Actions `Flutter CI` は PR #3 pull_request run `28724958105` まで成功。
  - `Documents` 配下の worktree での iOS build は `Flutter.framework` ディレクトリの `com.apple.FinderInfo` / `com.apple.fileprovider.fpfs#P` 拡張属性が codesign に拒否されることを確認。
  - iOS LaunchImage の 1x1 transparent placeholder を `assets/images/title_logo.png` 由来の 300x133pt 1x/2x/3x 画像に差し替え、`flutter build ipa --release` の Launch image placeholder warning が出ないことを確認。
  - `~/Library/Caches/AttackOfTheDragon/iOSReleaseCheck` にクリーンコピーして `flutter build ios --release` と `flutter build ipa --release` を実行し、archive と App Store IPA export に成功。IPA は `build/ios/ipa/Attack of the Dragon.ipa`、SHA-256 は `2c710e80e656ddafdc71a6c434311e5b07ff9794329676eac67fbb3809a7a990`。
- 次のセッションへの申し送り:
  - PR #3 は draft のまま。内容確認後、ready にして main へ取り込む。
  - TestFlight upload は未実施。Transporter で IPA をアップロードするか、App Store Connect API key を用意して `xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey ... --apiIssuer ...` を実行する。
  - iOS release build / IPA export は `Documents` 直下ではなく `~/Library/Caches/AttackOfTheDragon/iOSReleaseCheck` のような cache copy で行う。

## 2026-07-05 Device: Windows / AI: Claude — リリース前の全体チェック

- Branch: `main`
- PR: 未作成
- やったこと:
  - リリース前確認として全体をレビュー。`flutter analyze` 指摘ゼロ、`flutter test` 28件全通過。
  - 問題なしを確認: シークレット類の gitignore 追跡なし、Worker のトークン検証 (RS256 + iss/aud)、ATT→AdMob 初期化の順序、広告IDのリリース/デバッグ切替、IAP の購入復元ボタン実装。
- 次のセッションへの申し送り:
  - 【要対応】iOS `Info.plist` に `SKAdNetworkItems` がない。AdMob 必須設定で、ないと iOS 14+ の広告アトリビューションが働かず収益に影響。Google 公式の SKAdNetwork ID リストを提出前に追加する。
  - 【要対応】`RELEASE_CHECKLIST.md` の `artifacts/release-2026-07-04` はチェック済みだが、その後に英語ローカライズと ATT 対応が main に入っており、`artifacts/` ディレクトリ自体もローカルに存在しない。提出用ビルドは現在の main から作り直す。
  - 【軽微】`Info.plist` に `ITSAppUsesNonExemptEncryption` = false を追加すると提出ごとの輸出コンプライアンス質問を省略できる (通信は HTTPS のみ)。
  - 【整合性】チェックリストに「GitHub Actions の Flutter CI 確認」項目があるが、`.github/workflows/` が存在しない。CI を作るか項目を削除するか判断が必要。
  - 【低優先】`restore()` が `restorePurchases()` 復帰直後に `_busy` を見るため、復元成功時でも「復元できる購入はありません」が一瞬出る可能性 (直後のストリーム処理で自己修復)。
  - 【既知】英語ストアメタデータは未作成 (`STORE_METADATA_JA.md` のみ)。日本語プライマリの初回提出なら現状で可。

## 2026-07-05 Device: Windows / AI: Codex — Apple先行リリース方針確認

- Branch: `main`
- PR: 未作成
- やったこと:
  - Google側の審査待ち中はApple先行で進める方針を確認。
  - `main` は `origin/main` と同期済みで、iOSのBundle ID、Team、自動署名、Sign in with Apple entitlement、AdMob iOS App IDは設定済みと確認。
  - iOS版ではGoogleログイン導線は出ず、Appleログインだけが表示されるため、Google審査待ちはApple版の主要ブロッカーではない見込み。
- 次のセッションへの申し送り:
  - App Store ConnectのBusiness/AgreementsでAccount Holderが最新のPaid Apps Agreementに同意することを最優先にする。IAP `remove_ads` を出すため、契約・税務・銀行情報の未完了があると提出で詰まる。
  - Mac/Xcodeで自動署名のprovisioning更新、archive/TestFlightアップロード、内部TestFlight確認、ASCメタデータ・スクリーンショット・年齢レーティング・App Privacy入力を進める。
  - App Store向け説明文ではiOS実装に合わせて「Google / Appleアカウント連携」ではなく「Appleアカウント連携」中心にする。

## 2026-07-05 Device: Windows / AI: Codex — main push 準備

- Branch: `main`
- PR: 未作成
- やったこと:
  - ユーザーから `main` の push 承認を受けた。
  - `origin/main` との差分は、起動スクリプト差分、英語ローカライズ対応、英語ローカライズ merge 記録。
- 次のセッションへの申し送り:
  - push 前に `tools\github_workflow_check.ps1 -RunFlutterChecks` を実行する。

## 2026-07-05 Device: Windows / AI: Codex — 英語ローカライズを main に取り込み

- Branch: `main`
- PR: 未作成
- やったこと:
  - ユーザーが実機で英語ローカライズ表示を確認済み。
  - `codex/english-localization` を `main` に fast-forward merge。
- 次のセッションへの申し送り:
  - ローカル `main` は `origin/main` より進んでいる。GitHub へ反映する場合は、通常の pre-push workflow check を通してから push する。

## 2026-07-05 Device: Windows / AI: Codex — 英語ローカライズ対応

- Branch: `codex/english-localization`
- PR: 未作成
- やったこと:
  - 既存の未コミット起動スクリプト差分を `main` に直接コミットした後、`codex/english-localization` ブランチで作業を開始。
  - `DragonApp` の日本語固定 locale を解除し、端末 locale に応じて英語/日本語を切り替える `DragonStrings` を追加。
  - タイトル、設定、広告削除、ログイン/ログアウト、スコアボード、ポーズ/リザルト、撃破数表示、ランキング取得メッセージを英語対応。
  - widget test に英語タイトル表示確認を追加し、既存の日本語期待値は `Locale('ja')` 明示に更新。
  - ユーザー確認済みの iPhone 実機 Apple ログイン復旧を `RELEASE_CHECKLIST.md` に反映。
  - `flutter analyze` と `flutter test` は通過。
- 次のセッションへの申し送り:
  - まだ PR は未作成。必要なら `tools\github_workflow_check.ps1 -RunFlutterChecks` を実行してから push / PR 作成する。
  - 英語 locale では端末設定が英語のときに UI が英語になる想定。ストア用の英語メタデータはまだ未作成。

## 2026-07-04 Device: Windows / AI: Codex — 起動コマンドのローカル差分停止を回避

- Branch: `main`
- PR: 未作成
- やったこと:
  - `進撃のドラゴン PC 起動.cmd` と `進撃のドラゴン Android 起動.cmd` を、ローカル差分がある場合に停止せず GitHub 更新だけスキップしてローカル作業ツリーをビルド/インストールするよう変更。
  - PC 通常版は `NO_LAUNCH=1` でビルドまで成功、Android 通常版は `192.168.1.6:5555` にリリース APK をインストールして起動成功。
  - `flutter analyze` と `flutter test` は成功。
- 次のセッションへの申し送り:
  - 通常版 `.cmd` はローカル差分なしなら GitHub 更新後に起動、差分ありならローカル版として起動する挙動になっている。

## 2026-07-04 Device: Windows / AI: Codex — Google アカウント変更ボタンも削除

- Branch: `main`
- PR: 未作成
- やったこと:
  - 設定画面のログイン済み状態から「Googleアカウントを変更」ボタンも削除し、アカウント切り替え導線を出さないように統一
  - Google ログイン済み状態の widget test を更新し、変更ボタンが表示されないことを確認
  - `flutter analyze` と `flutter test` は通過
- 次のセッションへの申し送り:
  - 設定画面ではログイン済み表示とログアウトのみが出る想定。実機で表示確認するとよい

## 2026-07-04 Device: Windows / AI: Codex — 設定画面の Apple ボタンと SafeArea を調整

- Branch: `main`
- PR: 未作成
- やったこと:
  - 設定画面で Apple ログイン済みの場合に「Appleアカウントを変更」ボタンを表示しないように変更
  - 設定画面の背景も `SafeArea` 内へ移し、通知/ステータス領域にゲーム背景が表示されないようにタイトル/ゲーム画面と揃えた
  - Apple ログイン済み時に切り替えボタンが出ないことを widget test で追加確認
  - `flutter analyze` と `flutter test` は通過
- 次のセッションへの申し送り:
  - iPhone 実機で設定画面の通知領域と Apple ログイン済み表示を目視確認するとよい

## 2026-07-04 Device: Windows / AI: Codex — Apple identity token 検証修正を Worker にデプロイ

- Branch: `main` (origin/codex/fix-apple-token-verification を fast-forward 取り込み)
- PR: 未作成
- やったこと:
  - `server/score-submit-worker/worker.js` の Sign in with Apple identity token 検証を RS256 / `RSASSA-PKCS1-v1_5` + SHA-256 に修正したブランチを取り込み
  - Cloudflare Worker `attack-of-the-dragon-score-submit` を再デプロイ。Version ID: `b77edb2a-8e0e-4177-96f7-aa627bb93148`
  - `GET /?period=all` が `200` でランキング JSON を返すこと、`GET /privacy` が `200` を返すことを確認
  - 完了済みの一時引き継ぎ `docs/HANDOFF.md` は削除し、`server/score-submit-worker/DEPLOYMENT_LOG.md` に今回のデプロイを記録
- 次のセッションへの申し送り:
  - iPhone 実機のアプリ設定画面から Apple ログインを再試行し、「Appleでログインしました。」が出ることを確認する
  - 実機確認後、必要なら RELEASE_CHECKLIST に Apple ログイン復旧確認を反映する

## 2026-07-04 Device: Windows / AI: Claude — Googleログイン修復と Apple 提出準備 (App ID/ASC/IAP)

- Branch: `main` (ユーザー指示で直接コミット)
- PR: 未作成 (コミット `484f229` + このログ追記)
- やったこと:
  - 実機で Google ログイン不可の原因を特定: リリースAPKの署名が upload 鍵 (2026-07-04 作成) に変わったが、Google OAuth にはデバッグ鍵 SHA-1 しか未登録だった。Google Cloud (Gemini Project) に Android クライアント「Attack of the Dragon Android Upload」を作成し解消。実機でログインとランキング (playerId) 復元を確認済み
  - Apple Developer (チーム TATSUYA ASANO / 95RP2F687Q): bundle ID `io.github.iogami0103.attackofthedragon` は Xcode 自動生成 App ID として既存で、Sign In with Apple (primary) も有効化済みだったことを確認。新規登録時の「not available」エラーはこの重複が原因 (別チーム所有ではない)
  - App Store Connect にアプリ「Attack of the Dragon」(Apple ID 6787345039, SKU `attackofthedragon`, 日本語) を作成し、非消耗型 IAP `remove_ads` を基準価格 日本 ¥300 + 日本語ローカリゼーション「広告削除」で作成
  - 誤認で一時作成した `com.tatsuya.attackofthedragon` App ID は削除し、リポジトリ/Worker の一時変更も全て `io.github...` に巻き戻し済み (Worker 現行 Version `fb85b23d`)
- 次のセッションへの申し送り (特に Mac/iPhone 検証):
  - Xcode の署名チームは TATSUYA ASANO (95RP2F687Q)。bundle ID は変更なし。provisioning は自動署名に任せれば OK
  - iPhone で Apple ログイン → playerId 復元を確認したら RELEASE_CHECKLIST に反映すること
  - TestFlight 提出前に Account Holder が ASC で更新された使用許諾契約に同意する必要あり (2026-07-04 時点で未同意バナーあり)
  - IAP の審査用スクリーンショットは初回バージョン提出時に添付が必要
  - Google Auth Platform の公開ステータスは「テスト中」のまま (公開前に要変更、GAME_SPEC 16章)。Play App Signing 導入時は Play 署名鍵 SHA-1 の追加登録も必要

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

## 2026-07-04 Device: Windows / AI: Codex - Keep game screen out of notification/status area

- Branch: `codex/keep-game-out-of-status-area`
- PR: not created
- Done:
  - Wrapped the `GameScreen` loading state and main playfield in `SafeArea`.
  - Wrapped the `TitleScreen` playfield in `SafeArea` with the same top notification/status area avoidance.
  - Set the game/title `SafeArea` bottom edge to `false`; the banner keeps its own bottom safe area, avoiding an extra blank strip above ads.
  - The game world size now comes from the safe-area-constrained layout, so background, dragon, enemies, bullets, prompts, and result overlays stay below the device notification/status area.
  - Ran `flutter analyze` and `flutter test`; both passed.
- Notes for next session:
  - No Android debug APK build was run because this was a normal Flutter UI layout change, not packaging-sensitive.
  - If pushing this branch, run the repository pre-push workflow check first.

## 2026-07-05 Device: Windows / AI: Codex - Add iOS ATT request and Android ad ID permission

- Branch: `codex/tracking-permission`
- PR: not created
- Done:
  - Added `app_tracking_transparency` and request ATT authorization on iOS before `MobileAds.instance.initialize()` when ads are enabled and tracking status is still undetermined.
  - Added `NSUserTrackingUsageDescription` to `ios/Runner/Info.plist`.
  - Added explicit Android `com.google.android.gms.permission.AD_ID` to the main manifest and updated the manifest unit test.
  - Verified generated debug APK permissions include `android.permission.INTERNET` and `com.google.android.gms.permission.AD_ID`.
  - Ran `flutter analyze`, `flutter test`, and `flutter build apk --debug`; all passed.
- Notes for next session:
  - iOS ATT dialog still needs confirmation on a real iPhone/TestFlight fresh install because this Windows session cannot build or run iOS.
  - Android does not show an iOS-style ATT runtime prompt; Play Console advertising ID declaration should match the app's Google Mobile Ads usage.

## 2026-07-11 Device: Windows / AI: Codex - Apply volume slider changes immediately

- Branch: `main`
- PR: not created
- Done:
  - Updated settings saving so `_DragonShellState._saveSettings` applies `_settings`, `GameAudio.applySettings`, and ad-removal state before waiting on `SharedPreferences`.
  - Updated `SettingsScreen._commit` and back navigation to call `widget.audio.applySettings(...)` directly, so slider changes reach the active `GameAudio` instance immediately.
  - Updated loop SFX handling to remember each loop's `volumeScale` and reapply volume to currently wanted loop players when settings change.
  - Removed the attempted widget test because this environment/user confirmed that path hangs.
  - Ran `git diff --check`; it passed.
- Notes for next session:
  - Rebased the change onto the current `origin/main` (five remote commits) without conflicts before pushing.
  - Flutter formatting and tests were intentionally not run: this environment's test path repeatedly hangs. `git diff --check` passed; use a known-good local Flutter shell for full format/analyze/test verification.

## 2026-07-12 Device: Windows / AI: Codex - Add account deletion and support page

- Branch: `main`
- PR: not created
- Done:
  - Added an in-app Settings > Delete Account flow that asks for confirmation, reauthenticates with the current provider, deletes server-side account data, clears local scores, and resets the device to a new guest ID.
  - Added the Worker `deleteAccount` action, which verifies the Google/Apple identity token and deletes linked provider records, scores, player bests, and active run tokens for the authenticated player.
  - Added `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/support` with the approved support email and account-deletion guidance; deployed Worker version `c1a3b170-3043-41ca-95f8-4e22a74f418b`.
  - Updated privacy-policy and store metadata references. Increased the Android/iOS package version to `1.0.1+2`.
  - Ran `node --check server/score-submit-worker/worker.js`, `git diff --check`, verified `/support` and `/privacy` return HTTP 200, and built the release AAB at `build/app/outputs/bundle/release/app-release.aab`.
- Notes for next session:
  - Flutter test/analyze/format remains intentionally skipped in this Windows environment because the test path repeatedly hangs.
  - Update App Store Connect's Support URL to the `/support` URL above and submit a new iOS build from a Mac, including a physical-device screen recording of the complete sign-in and account-deletion flow in App Review Notes.
  - Android App Bundle `2 (1.0.1)` was uploaded to the Play Console `alpha` closed-test release and passed its preview checks. The final Play Console `Save` action is pending user confirmation.
