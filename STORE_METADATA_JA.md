# Attack of the Dragon ストア掲載メタデータ下書き

このファイルは Google Play Console / App Store Connect へ入力する前の下書きです。最終的な文字数、スクリーンショット寸法、年齢レーティング、プライバシー申告は各ストアの入力画面で確認してください。

## 基本情報

- アプリ名: Attack of the Dragon
- カテゴリ案: ゲーム / アクション
- 対応言語案: 日本語 / 英語
- プライバシーポリシー URL: https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy
- サポート URL 案: プライバシーポリシー URL と同じ、またはストアの開発者連絡先
- App Store カテゴリ案: ゲーム / アクション
- App Store 年齢レーティング案: 4+ または 9+ 相当を入力画面の質問結果に従って確定

## App Store 入力案

- サブタイトル: 空を駆けるドラゴンアクション
- プロモーションテキスト: ドラゴンを操り、炎で敵を撃ち落としてハイスコアを目指す縦画面アクション。短時間で遊べるスコアアタックです。
- キーワード案: ドラゴン,アクション,シューティング,ランキング,スコアアタック,縦画面,カジュアル,dragon,action
- サポート URL: https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev/privacy
- マーケティング URL: 空欄で可
- Copyright: © 2026 Tatsuya Asano
- App Review notes: `Sign in is optional. On iOS, use Sign in with Apple from Settings if account linking needs to be checked. The non-consumable in-app purchase remove_ads is available from Settings and removes ads after purchase. No test account is required for normal gameplay.`

## 短い説明

ドラゴンを操り、空を駆け抜けて敵を撃ち落とす縦画面アクション。

## 説明文

Attack of the Dragon は、ドラゴンを操って空を飛び続ける縦画面エンドレスアクションです。

タップで高度を調整し、迫ってくる敵や弾を避けながら、ドラゴンの炎で敵を撃ち落とします。プレイを続けるほど速度と敵の攻撃が激しくなり、判断力とリズム感が試されます。

特徴:

- 片手で遊べるシンプルなタップ操作
- 自動で放たれる炎による爽快な撃破
- 複数の敵タイプと攻撃パターン
- ローカルスコアとオンラインランキング
- アカウント連携によるランキング復元

短時間で遊べるスコアアタックとして、自己ベストとランキング上位を目指してください。

## スクリーンショット候補

提出候補として生成済みの画像:

- iPhone 6.9インチ: `artifacts/app-store-submission-2026-07-05/screenshots-web/iphone-6-9/`
- iPad 13インチ: `artifacts/app-store-submission-2026-07-05/screenshots-web/ipad-13/`
- IAP/Appleログイン確認用候補: `artifacts/app-store-submission-2026-07-05/screenshots/`

Web実描画から作成した候補は App Store の要求寸法に合わせている。最終提出前に、可能なら iPhone/iPad Simulator または実機の release build から撮り直すとより確実。

## 年齢レーティング入力メモ

- 暴力表現: ファンタジーの敵を炎で倒す表現あり。血液、ゴア、現実的な暴力表現なし。
- 恐怖表現: なし、または軽微。
- ユーザー生成コンテンツ: 自由入力のプレイヤー名のみ。チャット、投稿、画像アップロードなし。
- 位置情報: 使用しない。
- 課金: あり。非消耗型の広告削除 `remove_ads` を 300円で提供。
- 広告: あり。Google Mobile Ads を使用。
- オンライン機能: ランキング表示とスコア投稿あり。
- アカウント連携: iOS では Sign in with Apple は任意。Android では Google Sign-In は任意。

## Google Play Data safety 入力メモ

アプリ実装に基づく入力候補です。最終回答は Play Console の選択肢に合わせて確認してください。

- 収集する可能性があるデータ:
  - ユーザー ID: ゲーム内 player ID、Google / Apple の provider subject ID
  - ユーザー コンテンツ: プレイヤー名
  - アプリ アクティビティ: スコア、撃破数、プレイ日時、ゲームバージョン
  - 購入情報: 広告削除済みかどうかのローカル状態
  - デバイスまたはその他の ID: Google Mobile Ads SDK による広告 ID 等
- 用途:
  - アプリ機能: ランキング、スコア保存、アカウント復元
  - アプリ機能: 広告削除購入の反映と復元
  - 広告またはマーケティング: Google Mobile Ads
- 共有:
  - 広告関連データは Google Mobile Ads / Google とそのパートナーの処理対象になる可能性あり。
  - ランキング情報の一部は公開ランキングとして表示される。

## App Store Privacy 入力メモ

App Store Connect の入力候補です。最終回答は Apple の選択肢に合わせて確認してください。

- Gameplay Content: スコア、撃破数、プレイ日時、ゲームバージョン
- User ID: ゲーム内 player ID、Apple の provider subject ID (Android では Google の provider subject ID)
- Other User Content または Name 相当: プレイヤー名
- Purchases: 広告削除購入の状態
- Identifiers / Usage Data: Google Mobile Ads SDK が広告表示と測定のために扱う可能性あり
- Tracking: Google Mobile Ads の設定と実際の広告配信設定に合わせて確認

## クレジット

- Music: YouFulca (https://youfulca.com/)
- Font: M PLUS Rounded 1c (SIL Open Font License 1.1)
- SFX: The Ultimate 2017 16 bit Mini pack (CC0)
