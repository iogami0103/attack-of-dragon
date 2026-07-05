# App Store Review Prep

2026-07-05 Mac / Codex preparation notes for App Store Connect review submission.

## Build

- App: `Attack of the Dragon`
- Apple ID: `6787345039`
- SKU: `attackofthedragon`
- Bundle ID: `io.github.iogami0103.attackofthedragon`
- Version: `1.0.0`
- Build: `1`
- Uploaded build: Xcode Organizer reported `Uploaded to Apple` at 2026-07-05 11:46 JST.
- IPA SHA-256: `35ffac006699fdbf09255714baa352cebe5523acfd783083db75c48bc6c65876`
- Known upload warning: missing dSYM for `objective_c.framework`; binary upload completed.

## URLs

- Privacy Policy: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy`
- Plain text privacy policy: `https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy.txt`
- Support URL candidate: same as the privacy policy URL unless a separate support page is created.

## Metadata

- Name: `Attack of the Dragon`
- Subtitle: `空を駆けるドラゴンアクション`
- Promotional text: `ドラゴンを操り、炎で敵を撃ち落としてハイスコアを目指す縦画面アクション。短時間で遊べるスコアアタックです。`
- Category: Games / Action
- Keywords: `ドラゴン,アクション,シューティング,ランキング,スコアアタック,縦画面,カジュアル,dragon,action`
- Copyright: `© 2026 Tatsuya Asano`

## Description

```text
Attack of the Dragon は、ドラゴンを操って空を飛び続ける縦画面エンドレスアクションです。

タップで高度を調整し、迫ってくる敵や弾を避けながら、ドラゴンの炎で敵を撃ち落とします。プレイを続けるほど速度と敵の攻撃が激しくなり、判断力とリズム感が試されます。

特徴:

- 片手で遊べるシンプルなタップ操作
- 自動で放たれる炎による爽快な撃破
- 複数の敵タイプと攻撃パターン
- ローカルスコアとオンラインランキング
- アカウント連携によるランキング復元

短時間で遊べるスコアアタックとして、自己ベストとランキング上位を目指してください。
```

## Screenshots

Apple's current screenshot reference says iPhone apps can provide 6.9-inch screenshots and iPad apps require 13-inch screenshots:
https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

Generated candidate screenshots:

- Web-rendered candidates:
  - `artifacts/app-store-submission-2026-07-05/screenshots-web/iphone-6-9/`
  - `artifacts/app-store-submission-2026-07-05/screenshots-web/ipad-13/`
- Widget-rendered IAP/Apple login candidates:
  - `artifacts/app-store-submission-2026-07-05/screenshots/iphone-6-9/04-settings-iap.png`
  - `artifacts/app-store-submission-2026-07-05/screenshots/ipad-13/04-settings-iap.png`

Notes:

- Web-rendered iPhone candidates have correct App Store dimensions and good text rendering.
- Web-rendered iPad candidates currently show the title layout only because the headless tap coordinates did not switch screens; use the widget-rendered iPad candidates or recapture in Simulator before final submission.
- The title logo did not appear in the headless web/title capture even though the asset was requested successfully. If time allows, use Simulator or real-device screenshots for final visual polish.
- The widget-rendered IAP candidate shows Apple login and ad removal state, but it should be treated as a review-support screenshot rather than the primary product-page screenshot.

## Age Rating Notes

- Cartoon or fantasy violence: mild/infrequent. The player defeats fantasy enemies with dragon fire.
- Realistic violence, blood, gore, horror, gambling, contests, unrestricted web access: none.
- User-generated content: player name only; no chat, images, posts, or open sharing.
- Purchases: yes, non-consumable ad removal `remove_ads`.
- Advertising: yes, Google Mobile Ads.
- Online features: online leaderboard and score submission.

## App Privacy Notes

Implementation-based App Store Privacy draft:

- Gameplay Content / Gameplay Data: score, defeated enemy count, play date, game version.
- User ID: game player ID and Sign in with Apple provider subject ID when account linking is used.
- Other User Content or Name equivalent: player name displayed in rankings.
- Purchases: ad removal entitlement state.
- Identifiers / Usage Data: Google Mobile Ads may process advertising identifiers, device information, IP address, and ad interaction data.
- Tracking: answer according to the final Google Mobile Ads personalization/ATT configuration in App Store Connect.

## App Review Notes

```text
Sign in is optional. On iOS, use Sign in with Apple from Settings if account linking needs to be checked. Normal gameplay and local score saving do not require a test account.

The non-consumable in-app purchase remove_ads is available from Settings and removes ads after purchase.

Online rankings are served by the Cloudflare Worker listed in the privacy policy. The app does not require location, camera, microphone, or user-generated posts.
```

## Remaining External Items

- Wait for App Store Connect build processing and select build `1`.
- Confirm agreements, tax, and banking status with the Account Holder.
- Fill App Privacy and age rating in App Store Connect using the notes above.
- Upload screenshots and IAP review screenshot.
- Attach the existing non-consumable IAP `remove_ads` to the app version if App Store Connect requires it.
