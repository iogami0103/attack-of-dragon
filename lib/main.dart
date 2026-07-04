import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'audio_cache.dart';
import 'audio_source.dart';

const _productionScoreSubmitUrl =
    'https://attack-of-the-dragon-score-submit.i-ogami-0103.workers.dev';
const _scoreSubmitUrl = String.fromEnvironment(
  'SCORE_SUBMIT_URL',
  defaultValue: kReleaseMode ? _productionScoreSubmitUrl : '',
);
const _adMobEnabled = bool.fromEnvironment('ADMOB_ENABLED', defaultValue: true);
const _adMobUseTestIds = bool.fromEnvironment(
  'ADMOB_USE_TEST_IDS',
  defaultValue: !kReleaseMode,
);
const _adMobAndroidBannerUnitId = String.fromEnvironment(
  'ADMOB_ANDROID_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-9107759780289476/4502022797',
);
const _adMobAndroidInterstitialUnitId = String.fromEnvironment(
  'ADMOB_ANDROID_INTERSTITIAL_UNIT_ID',
  defaultValue: 'ca-app-pub-9107759780289476/3188941125',
);
const _adMobIosBannerUnitId = String.fromEnvironment(
  'ADMOB_IOS_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-9107759780289476/6874024949',
);
const _adMobIosInterstitialUnitId = String.fromEnvironment(
  'ADMOB_IOS_INTERSTITIAL_UNIT_ID',
  defaultValue: 'ca-app-pub-9107759780289476/9562777787',
);
const _adMobAndroidTestBannerUnitId = String.fromEnvironment(
  'ADMOB_ANDROID_TEST_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/6300978111',
);
const _adMobAndroidTestInterstitialUnitId = String.fromEnvironment(
  'ADMOB_ANDROID_TEST_INTERSTITIAL_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/1033173712',
);
const _adMobIosTestBannerUnitId = String.fromEnvironment(
  'ADMOB_IOS_TEST_BANNER_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/2934735716',
);
const _adMobIosTestInterstitialUnitId = String.fromEnvironment(
  'ADMOB_IOS_TEST_INTERSTITIAL_UNIT_ID',
  defaultValue: 'ca-app-pub-3940256099942544/4411468910',
);
const _removeAdsProductId = String.fromEnvironment(
  'REMOVE_ADS_PRODUCT_ID',
  defaultValue: 'remove_ads',
);
const _removeAdsReferencePriceLabel = '¥300';
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '472691784297-l323hbj6cm13ulsn8ul8cvvge956vedf.apps.googleusercontent.com',
);
const _gameVersion = '1.0.0';
const _gameBgmIntroFile = 'game_bgm_intro.ogg';
const _gameBgmLoopFile = 'game_bgm_loop.ogg';
// 炎SFXは単発音(82ms)を発射間隔0.14sで敷き詰めた2.24sのループ音源。
// iOS(AVPlayer)は seek→play の再始動レイテンシが大きく、単発音を発射ごとに
// 鳴らし直すと連続音が途切れるため、連射中はループ再生で鳴らし続ける。
const _dragonFireLoopSfxFile = 'dragon_fire_flame_loop.wav';
const _enemyBurstSfxFile = 'enemy_explosion_ultimate_snap_boom_007.ogg';
const _dragonFireSfxVolumeScale = 0.18;
const _enemyBurstSfxVolumeScale = 0.14;
const _interstitialRetryPlayTime = Duration(minutes: 3);
const _preloadedSfxFiles = <String>[_enemyBurstSfxFile];
const _preloadedLoopSfxFiles = <String>[_dragonFireLoopSfxFile];

class DragonStrings {
  const DragonStrings._(this.languageCode);

  final String languageCode;

  static const supportedLocales = [Locale('en'), Locale('ja')];

  static Locale resolveLocale(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale?.languageCode == 'ja') return const Locale('ja');
    return const Locale('en');
  }

  static DragonStrings of(BuildContext context) {
    return forLocale(Localizations.localeOf(context));
  }

  static DragonStrings forLocale(Locale locale) {
    return DragonStrings._(locale.languageCode == 'ja' ? 'ja' : 'en');
  }

  bool get isJapanese => languageCode == 'ja';

  String get start => isJapanese ? 'スタート' : 'Start';
  String get settings => isJapanese ? '設定' : 'Settings';
  String get scoreboard => isJapanese ? 'スコアボード' : 'Scoreboard';
  String get backToTitle => isJapanese ? 'タイトルへ戻る' : 'Back to Title';
  String get backToResult => isJapanese ? 'リザルトへ戻る' : 'Back to Result';
  String get playerName => isJapanese ? 'プレイヤー名' : 'Player Name';
  String get volume => isJapanese ? '音量' : 'Volume';
  String get logout => isJapanese ? 'ログアウト' : 'Log Out';
  String get loggedOut => isJapanese ? 'ログアウトしました。' : 'Logged out.';
  String signedInWith(String provider) =>
      isJapanese ? '$providerでログイン済み' : 'Signed in with $provider';
  String signInWith(String provider) =>
      isJapanese ? '$providerでログイン' : 'Sign in with $provider';
  String signedInMessage(String provider) =>
      isJapanese ? '$providerでログインしました。' : 'Signed in with $provider.';

  String get signInCanceled =>
      isJapanese ? 'ログインをキャンセルしました。' : 'Sign-in was canceled.';
  String get googleSignInFailed => isJapanese
      ? 'Googleでログインできませんでした。Google OAuth の署名設定を確認してください。'
      : 'Could not sign in with Google. Check the Google OAuth signing settings.';
  String get missingGoogleIdToken => isJapanese
      ? 'Googleの認証情報を取得できませんでした。Google OAuth の設定を確認してください。'
      : 'Could not get Google credentials. Check the Google OAuth settings.';
  String get missingAppleIdentityToken => isJapanese
      ? 'Appleの認証情報を取得できませんでした。Apple DeveloperのSign in with Apple設定を確認してください。'
      : 'Could not get Apple credentials. Check the Sign in with Apple settings in Apple Developer.';
  String get appleSignInNotInteractive => isJapanese
      ? 'Appleログイン画面を表示できませんでした。もう一度ボタンから操作してください。'
      : 'Could not show the Apple sign-in sheet. Try again from the button.';
  String get appleSignInFailed => isJapanese
      ? 'Appleでログインできませんでした。Sign in with Apple capability とプロビジョニングプロファイルを確認してください。'
      : 'Could not sign in with Apple. Check the Sign in with Apple capability and provisioning profile.';
  String get appleSignInUnavailable => isJapanese
      ? 'Appleログインを利用できません。iOS 13以上、Apple ID、Sign in with Apple capabilityを確認してください。'
      : 'Apple sign-in is unavailable. Check iOS 13 or later, Apple ID, and Sign in with Apple capability.';
  String get rankingServerNotConfigured => isJapanese
      ? 'ランキングサーバー未設定のためログインできません。'
      : 'Sign-in is unavailable because the ranking server is not configured.';
  String providerRejected(String provider) => isJapanese
      ? '$providerの認証情報をサーバーが拒否しました。bundle ID / OAuth client ID設定を確認してください。'
      : '$provider credentials were rejected by the server. Check the bundle ID / OAuth client ID settings.';
  String providerSignInFailed(String provider) => isJapanese
      ? '$providerでログインできませんでした。'
      : 'Could not sign in with $provider.';

  String get adRemovalOwned => isJapanese ? '広告削除済み' : 'Ads removed';
  String get adRemovalCheckingProduct =>
      isJapanese ? '商品情報を確認中' : 'Checking product info';
  String get adRemovalPurchaseProcessing =>
      isJapanese ? '購入処理中' : 'Processing purchase';
  String get adRemovalTitle => isJapanese ? '広告削除' : 'Remove Ads';
  String adRemovalBuy(String price) =>
      isJapanese ? '広告削除 $price' : 'Remove Ads $price';
  String get adRemovalRestore => isJapanese ? '購入を復元' : 'Restore Purchase';
  String _adRemovalMessage(_AdRemovalMessage message) {
    return switch (message) {
      _AdRemovalMessage.purchaseStateUnavailable =>
        isJapanese ? '購入状態を確認できません' : 'Could not check purchase status',
      _AdRemovalMessage.storeUnavailable =>
        isJapanese ? 'ストアに接続できません' : 'Could not connect to the store',
      _AdRemovalMessage.productUnavailable =>
        isJapanese
            ? '広告削除の商品情報を取得できません'
            : 'Could not get Remove Ads product info',
      _AdRemovalMessage.purchaseStartUnavailable =>
        isJapanese ? '購入を開始できません' : 'Could not start purchase',
      _AdRemovalMessage.noRestorablePurchases =>
        isJapanese ? '復元できる購入はありません' : 'No purchases available to restore',
      _AdRemovalMessage.restoreUnavailable =>
        isJapanese ? '購入を復元できません' : 'Could not restore purchase',
      _AdRemovalMessage.purchaseCompleteUnavailable =>
        isJapanese ? '購入を完了できません' : 'Could not complete purchase',
      _AdRemovalMessage.purchaseCanceled =>
        isJapanese ? '購入をキャンセルしました' : 'Purchase canceled',
      _AdRemovalMessage.purchaseStateSaveUnavailable =>
        isJapanese ? '購入状態を保存できません' : 'Could not save purchase status',
      _AdRemovalMessage.purchaseCompletionUnavailable =>
        isJapanese ? '購入完了処理を確認できません' : 'Could not confirm purchase completion',
    };
  }

  String get scoreboardOnline => isJapanese ? 'オンライン' : 'Online';
  String get scoreboardLocal => isJapanese ? 'ローカル' : 'Local';
  String get scoreboardBundled => isJapanese ? '同梱ランキング' : 'Bundled Rankings';
  String get scoreboardToday => isJapanese ? '今日' : 'Today';
  String get scoreboardWeek => isJapanese ? '週間' : 'Week';
  String get scoreboardMonth => isJapanese ? '月間' : 'Month';
  String get scoreboardAllTime => isJapanese ? '全期間' : 'All Time';
  String get scoreboardSubmittedResultsShown => isJapanese
      ? '投稿結果を即時反映しています。'
      : 'Submitted results are shown immediately.';
  String get noOnlineRankings => isJapanese ? 'ランキングがありません' : 'No rankings yet';
  String get noLocalRecords =>
      isJapanese ? 'ローカル記録がありません' : 'No local records yet';
  String countEntries(int count) {
    if (isJapanese) return '$count件';
    return count == 1 ? '1 entry' : '$count entries';
  }

  String get bestScore => isJapanese ? '自己ベスト' : 'Best Score';
  String get pause => isJapanese ? '一時停止' : 'Pause';
  String get resume => isJapanese ? '再開' : 'Resume';
  String get tapToStart => isJapanese ? 'タップしてスタート' : 'Tap to Start';
  String get newRecord => isJapanese ? '新記録!' : 'New Record!';
  String get best => isJapanese ? 'ベスト' : 'Best';
  String get defeated => isJapanese ? '撃破' : 'Defeated';
  String get retry => isJapanese ? 'リトライ' : 'Retry';
  String killsCount(int kills) => isJapanese ? '撃破 $kills' : 'Defeated $kills';

  String get scoreboardMissingApiMessage => isJapanese
      ? 'SCORE_SUBMIT_URL 未設定のため、同梱ランキングを表示しています。'
      : 'SCORE_SUBMIT_URL is not configured, so bundled rankings are shown.';
  String get scoreboardCachedOnlineMessage => isJapanese
      ? '最新取得に失敗したため、直近の投稿結果を表示しています。'
      : 'Could not fetch latest rankings, so recent submitted results are shown.';
  String get scoreboardLocalFallbackMessage => isJapanese
      ? 'オンライン取得に失敗したため、ローカル記録を表示しています。'
      : 'Could not fetch online rankings, so local records are shown.';

  String scoreboardSourceLabel(ScoreboardSource source) {
    return switch (source) {
      ScoreboardSource.online => scoreboardOnline,
      ScoreboardSource.local => scoreboardLocal,
    };
  }

  String scoreboardPeriodLabel(ScoreboardPeriod period) {
    return switch (period) {
      ScoreboardPeriod.today => scoreboardToday,
      ScoreboardPeriod.week => scoreboardWeek,
      ScoreboardPeriod.month => scoreboardMonth,
      ScoreboardPeriod.allTime => scoreboardAllTime,
    };
  }

  String formatScoreDateTime(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    if (isJapanese) {
      return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
          '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
    }
    return '${twoDigits(local.month)}/${twoDigits(local.day)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

String get _scoreApiUrl {
  if (_scoreSubmitUrl.isNotEmpty) return _scoreSubmitUrl;
  if (kIsWeb) return '';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => _productionScoreSubmitUrl,
    _ => '',
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DragonApp());
}

class DragonApp extends StatelessWidget {
  const DragonApp({super.key, this.locale});

  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xffe6652a),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Attack of the Dragon',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: DragonStrings.supportedLocales,
      localeResolutionCallback: DragonStrings.resolveLocale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xfffff3df),
        fontFamily: 'MPLUSRounded1c',
        fontFamilyFallback: const [
          'Noto Sans CJK JP',
          'Noto Sans JP',
          'Yu Gothic UI',
          'Yu Gothic',
          'Meiryo',
          'Hiragino Sans',
          'BIZ UDGothic',
          'sans-serif',
        ],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.72),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xff7c4a2d),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xff8f3b19).withValues(alpha: 0.22),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xff8f3b19).withValues(alpha: 0.22),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xffdc6327), width: 2),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xffe6682b),
          inactiveTrackColor: const Color(0xff7b381c).withValues(alpha: 0.18),
          thumbColor: const Color(0xffffb643),
          overlayColor: const Color(0xffffb643).withValues(alpha: 0.18),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xff7b381c);
              }
              return Colors.white.withValues(alpha: 0.58);
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return const Color(0xff5a2815);
            }),
            side: WidgetStateProperty.all(
              BorderSide(
                color: const Color(0xff7b381c).withValues(alpha: 0.22),
              ),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size.fromHeight(50)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            elevation: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) return 0;
              return 4;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return _UiColors.ember.withValues(alpha: 0.28);
              }
              return _UiColors.flame;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            side: WidgetStateProperty.resolveWith((states) {
              final alpha = states.contains(WidgetState.disabled) ? 0.12 : 0.34;
              return BorderSide(
                color: _UiColors.ember.withValues(alpha: alpha),
              );
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return _UiColors.ink.withValues(alpha: 0.38);
              }
              return _UiColors.ink;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.white.withValues(alpha: 0.28);
              }
              return Colors.white.withValues(alpha: 0.48);
            }),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff3f2116),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _UiColors.gold.withValues(alpha: 0.4)),
          ),
          contentTextStyle: const TextStyle(
            fontFamily: 'MPLUSRounded1c',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        useMaterial3: true,
      ),
      home: const DragonShell(),
    );
  }
}

class _UiColors {
  const _UiColors._();

  static const ink = Color(0xff2f1a13);
  static const ember = Color(0xffa8421d);
  static const flame = Color(0xffe7682b);
  static const gold = Color(0xffffb13b);
  static const deepGold = Color(0xffb9711b);
  static const paper = Color(0xfffff6e8);
  static const paperWarm = Color(0xffffe4c4);
  static const teal = Color(0xff1b8f8a);
}

class AdMobService {
  AdMobService();

  static Future<InitializationStatus>? _mobileAdsInitialization;
  static Future<void>? _trackingAuthorizationRequest;

  InterstitialAd? _interstitialAd;
  bool _interstitialLoading = false;
  bool _interstitialShowing = false;
  bool _adsRemoved = false;

  static bool get supported {
    if (!_adMobEnabled || kIsWeb) return false;
    if (WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    )) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  bool get adsRemoved => _adsRemoved;

  bool get canShowAds => supported && !_adsRemoved;

  double get bannerHeight => canShowAds ? AdSize.banner.height.toDouble() : 0;

  bool get isInterstitialReady => canShowAds && _interstitialAd != null;

  String get _bannerAdUnitId {
    if (_adMobUseTestIds) {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => _adMobAndroidTestBannerUnitId,
        TargetPlatform.iOS => _adMobIosTestBannerUnitId,
        _ => '',
      };
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _adMobAndroidBannerUnitId,
      TargetPlatform.iOS => _adMobIosBannerUnitId,
      _ => '',
    };
  }

  String get _interstitialAdUnitId {
    if (_adMobUseTestIds) {
      return switch (defaultTargetPlatform) {
        TargetPlatform.android => _adMobAndroidTestInterstitialUnitId,
        TargetPlatform.iOS => _adMobIosTestInterstitialUnitId,
        _ => '',
      };
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _adMobAndroidInterstitialUnitId,
      TargetPlatform.iOS => _adMobIosInterstitialUnitId,
      _ => '',
    };
  }

  void setAdsRemoved(bool value) {
    if (_adsRemoved == value) {
      if (!_adsRemoved) warmUp();
      return;
    }
    _adsRemoved = value;
    if (_adsRemoved) {
      dispose();
      return;
    }
    warmUp();
  }

  void warmUp() {
    if (!canShowAds) return;
    _loadInterstitial();
  }

  Future<BannerAd> createBannerAd({
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    final adUnitId = _bannerAdUnitId;
    if (!canShowAds || adUnitId.isEmpty) {
      throw StateError('admob_banner_unavailable');
    }
    await _ensureInitialized();
    return BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          onFailed();
        },
      ),
    );
  }

  Future<void> showInterstitialBefore(VoidCallback action) async {
    if (!canShowAds || _interstitialShowing) {
      action();
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      action();
      return;
    }

    _interstitialAd = null;
    _interstitialShowing = true;
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      _interstitialShowing = false;
      ad.dispose();
      _loadInterstitial();
      action();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, _) => finish(),
    );

    try {
      await ad.show();
    } catch (_) {
      finish();
    }
  }

  void _loadInterstitial() {
    if (!canShowAds || _interstitialLoading || _interstitialAd != null) return;
    final adUnitId = _interstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    _interstitialLoading = true;
    unawaited(_loadInterstitialAfterInitialization(adUnitId));
  }

  Future<void> _loadInterstitialAfterInitialization(String adUnitId) async {
    try {
      await _ensureInitialized();
      if (!canShowAds) {
        _interstitialLoading = false;
        return;
      }
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialLoading = false;
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (_) {
            _interstitialLoading = false;
          },
        ),
      );
    } catch (_) {
      _interstitialLoading = false;
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _interstitialLoading = false;
  }

  static Future<void> _ensureInitialized() async {
    if (!supported) return;
    await _ensureTrackingAuthorization();
    var initialization = _mobileAdsInitialization;
    if (initialization == null) {
      initialization = MobileAds.instance.initialize().catchError((
        Object error,
      ) {
        _mobileAdsInitialization = null;
        throw error;
      });
      _mobileAdsInitialization = initialization;
    }
    await initialization;
  }

  static Future<void> _ensureTrackingAuthorization() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _trackingAuthorizationRequest ??= _requestTrackingAuthorization();
    await _trackingAuthorizationRequest;
  }

  static Future<void> _requestTrackingAuthorization() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {
      // Ads should still load if ATT cannot be shown on this device/session.
    }
  }
}

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({required this.adMob, super.key});

  final AdMobService adMob;

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  static const _retryDelay = Duration(seconds: 45);

  BannerAd? _bannerAd;
  bool _loaded = false;
  Timer? _retryTimer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  @override
  void didUpdateWidget(covariant AdMobBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.adMob.canShowAds) {
      _disposeBanner();
      return;
    }
    if (_bannerAd == null) _loadBanner();
  }

  void _loadBanner() {
    if (!widget.adMob.canShowAds) return;
    final generation = ++_loadGeneration;
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;
    unawaited(_loadBannerAfterInitialization(generation));
  }

  Future<void> _loadBannerAfterInitialization(int generation) async {
    try {
      final ad = await widget.adMob.createBannerAd(
        onLoaded: () {
          if (mounted && generation == _loadGeneration) {
            setState(() => _loaded = true);
          }
        },
        onFailed: () {
          // 初回ロードだけでなく自動更新の失敗でも呼ばれる (広告は破棄済み)。
          // そのままでは消えたきりになるので、時間をおいて作り直す。
          if (!mounted || generation != _loadGeneration) return;
          _bannerAd = null;
          setState(() => _loaded = false);
          _retryTimer = Timer(_retryDelay, () {
            if (mounted) _loadBanner();
          });
        },
      );
      if (!mounted ||
          generation != _loadGeneration ||
          !widget.adMob.canShowAds) {
        ad.dispose();
        return;
      }
      _bannerAd = ad;
      await ad.load();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loaded = false);
      _retryTimer = Timer(_retryDelay, () {
        if (mounted) _loadBanner();
      });
    }
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  void _disposeBanner() {
    _loadGeneration++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    _loaded = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.adMob.canShowAds) return const SizedBox.shrink();
    final bannerAd = _bannerAd;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: widget.adMob.bannerHeight,
        child: Center(
          child: _loaded && bannerAd != null
              ? SizedBox(
                  width: bannerAd.size.width.toDouble(),
                  height: bannerAd.size.height.toDouble(),
                  child: AdWidget(ad: bannerAd),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

enum _AdRemovalMessage {
  purchaseStateUnavailable,
  storeUnavailable,
  productUnavailable,
  purchaseStartUnavailable,
  noRestorablePurchases,
  restoreUnavailable,
  purchaseCompleteUnavailable,
  purchaseCanceled,
  purchaseStateSaveUnavailable,
  purchaseCompletionUnavailable,
}

class AdRemovalPurchaseService extends ChangeNotifier {
  AdRemovalPurchaseService({InAppPurchase? store}) : _store = store;

  final InAppPurchase? _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _storeAvailable = false;
  bool _loading = false;
  bool _busy = false;
  bool _owned = false;
  _AdRemovalMessage? _message;

  Future<void> Function()? onEntitlementUnlocked;

  InAppPurchase get _inAppPurchase => _store ?? InAppPurchase.instance;

  static bool get supported {
    if (kIsWeb) return false;
    if (WidgetsBinding.instance.runtimeType.toString().contains(
      'TestWidgetsFlutterBinding',
    )) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  bool get owned => _owned;
  bool get loading => _loading;
  bool get busy => _busy;
  bool get storeAvailable => _storeAvailable;
  String get productId => _removeAdsProductId;
  String get priceLabel => _product?.price ?? _removeAdsReferencePriceLabel;

  bool get canBuy {
    return supported &&
        !_owned &&
        !_loading &&
        !_busy &&
        _storeAvailable &&
        _product != null;
  }

  bool get canRestore => supported && !_owned && !_loading && !_busy;

  String? message(DragonStrings strings) {
    if (_owned) return strings.adRemovalOwned;
    if (!supported) return null;
    if (_loading) return strings.adRemovalCheckingProduct;
    if (_busy) return strings.adRemovalPurchaseProcessing;
    final message = _message;
    return message == null ? null : strings._adRemovalMessage(message);
  }

  Future<void> load({required bool owned}) async {
    _owned = owned;
    if (!supported) {
      _storeAvailable = false;
      _loading = false;
      _busy = false;
      _notify();
      return;
    }

    _subscription ??= _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (_) {
        _busy = false;
        _message = _AdRemovalMessage.purchaseStateUnavailable;
        _notify();
      },
    );

    _loading = true;
    _message = null;
    _notify();

    try {
      _storeAvailable = await _inAppPurchase.isAvailable();
      if (!_storeAvailable) {
        _product = null;
        _message = _AdRemovalMessage.storeUnavailable;
        return;
      }

      final response = await _inAppPurchase.queryProductDetails({
        _removeAdsProductId,
      });
      _product = _productById(response.productDetails, _removeAdsProductId);
      if (_product == null) {
        _message = _AdRemovalMessage.productUnavailable;
      }
    } catch (_) {
      _storeAvailable = false;
      _product = null;
      _message = _AdRemovalMessage.productUnavailable;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> buy() async {
    if (_owned || _busy) return;
    final product = _product;
    if (!canBuy || product == null) {
      _message = _AdRemovalMessage.productUnavailable;
      _notify();
      return;
    }

    _busy = true;
    _message = null;
    _notify();

    try {
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _busy = false;
        _message = _AdRemovalMessage.purchaseStartUnavailable;
        _notify();
      }
    } catch (_) {
      _busy = false;
      _message = _AdRemovalMessage.purchaseStartUnavailable;
      _notify();
    }
  }

  Future<void> restore() async {
    if (_owned || _busy || !supported) return;
    _busy = true;
    _message = null;
    _notify();

    try {
      await _inAppPurchase.restorePurchases();
      if (_busy) {
        _busy = false;
        _message = _owned ? null : _AdRemovalMessage.noRestorablePurchases;
        _notify();
      }
    } catch (_) {
      _busy = false;
      _message = _AdRemovalMessage.restoreUnavailable;
      _notify();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    if (purchases.isEmpty) {
      if (_busy) {
        _busy = false;
        _message = _AdRemovalMessage.noRestorablePurchases;
        _notify();
      }
      return;
    }

    for (final purchase in purchases) {
      if (purchase.productID != _removeAdsProductId) continue;
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    var shouldCompletePurchase = purchase.pendingCompletePurchase;
    try {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _busy = true;
          _message = null;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _unlockEntitlement();
          _busy = false;
          _message = null;
          break;
        case PurchaseStatus.error:
          _busy = false;
          _message = _AdRemovalMessage.purchaseCompleteUnavailable;
          break;
        case PurchaseStatus.canceled:
          _busy = false;
          _message = _AdRemovalMessage.purchaseCanceled;
          break;
      }
    } catch (_) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        shouldCompletePurchase = false;
      }
      _busy = false;
      _message = _AdRemovalMessage.purchaseStateSaveUnavailable;
    } finally {
      if (shouldCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchase);
        } catch (_) {
          _message = _AdRemovalMessage.purchaseCompletionUnavailable;
        }
      }
      _notify();
    }
  }

  Future<void> _unlockEntitlement() async {
    if (_owned) return;
    _owned = true;
    await onEntitlementUnlocked?.call();
  }

  ProductDetails? _productById(List<ProductDetails> products, String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _notify() {
    if (hasListeners) notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

enum _FantasyButtonTone { primary, secondary, quiet }

class _GamePanel extends StatelessWidget {
  const _GamePanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.maxWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.96),
            _UiColors.paper.withValues(alpha: 0.95),
            _UiColors.paperWarm.withValues(alpha: 0.94),
          ],
          stops: const [0.0, 0.48, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _UiColors.deepGold.withValues(alpha: 0.55),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: _UiColors.ink.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _UiColors.gold.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (maxWidth == null) return panel;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: panel,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color = _UiColors.flame});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 38.0;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_UiColors.gold, color, _UiColors.ember],
            stops: const [0.0, 0.58, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.54),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    this.color = _UiColors.flame,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _UiColors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _UiColors.deepGold.withValues(alpha: 0.65),
                  _UiColors.gold.withValues(alpha: 0.35),
                  _UiColors.deepGold.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class _FantasyButton extends StatefulWidget {
  const _FantasyButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = _FantasyButtonTone.primary,
    this.height = 54,
    this.busy = false,
    this.showIconBadge = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _FantasyButtonTone tone;
  final double height;
  final bool busy;
  final bool showIconBadge;

  @override
  State<_FantasyButton> createState() => _FantasyButtonState();
}

class _FantasyButtonState extends State<_FantasyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final enabled = widget.onPressed != null;
    final foreground = tone == _FantasyButtonTone.primary
        ? Colors.white
        : _UiColors.ink;
    final borderColor = switch (tone) {
      _FantasyButtonTone.primary => _UiColors.gold.withValues(alpha: 0.88),
      _FantasyButtonTone.secondary => _UiColors.deepGold.withValues(
        alpha: 0.62,
      ),
      _FantasyButtonTone.quiet => _UiColors.ink.withValues(alpha: 0.12),
    };
    final gradient = switch (tone) {
      _FantasyButtonTone.primary => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_UiColors.gold, _UiColors.flame, Color(0xff8f3218)],
        stops: [0.0, 0.42, 1.0],
      ),
      _FantasyButtonTone.secondary => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.96),
          _UiColors.paperWarm.withValues(alpha: 0.92),
          _UiColors.gold.withValues(alpha: 0.26),
        ],
        stops: const [0.0, 0.62, 1.0],
      ),
      _FantasyButtonTone.quiet => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.44),
          Colors.white.withValues(alpha: 0.24),
        ],
      ),
    };

    return AnimatedScale(
      scale: _pressed && enabled ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: _UiColors.ink.withValues(
                          alpha: _pressed ? 0.10 : 0.18,
                        ),
                        blurRadius: _pressed ? 6 : 14,
                        offset: Offset(0, _pressed ? 3 : 8),
                      ),
                      BoxShadow(
                        color: _UiColors.gold.withValues(alpha: 0.14),
                        blurRadius: 16,
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ButtonTrimPainter(
                      primary: tone == _FantasyButtonTone.primary,
                    ),
                  ),
                ),
                // Top gloss to give the button a subtle 3D sheen.
                Positioned(
                  left: 3,
                  right: 3,
                  top: 3,
                  height: widget.height * 0.42,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: tone == _FantasyButtonTone.primary
                                  ? 0.30
                                  : 0.45,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.onPressed,
                      onHighlightChanged: (value) {
                        setState(() => _pressed = value);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 34,
                              child: _leadingIcon(tone, foreground),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  shadows: tone == _FantasyButtonTone.primary
                                      ? const [
                                          Shadow(
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                            color: Colors.black38,
                                          ),
                                        ]
                                      : const [],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const SizedBox.square(dimension: 34),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(_FantasyButtonTone tone, Color foreground) {
    final progressColor = tone == _FantasyButtonTone.primary
        ? _UiColors.ink
        : Colors.white;
    final icon = widget.busy
        ? Padding(
            padding: const EdgeInsets.all(8),
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: progressColor,
            ),
          )
        : Icon(
            widget.icon,
            color: widget.showIconBadge ? progressColor : foreground,
            size: widget.showIconBadge ? 20 : 24,
          );

    if (!widget.showIconBadge) {
      return Center(child: icon);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tone == _FantasyButtonTone.primary
              ? const [Color(0xfffff2bc), _UiColors.gold, _UiColors.deepGold]
              : const [_UiColors.ember, _UiColors.flame],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: _UiColors.ink.withValues(alpha: 0.20),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: icon,
    );
  }
}

class _ButtonTrimPainter extends CustomPainter {
  const _ButtonTrimPainter({required this.primary});

  final bool primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 80 || size.height < 32) return;
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: primary ? 0.34 : 0.58)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final dark = Paint()
      ..color = _UiColors.ink.withValues(alpha: primary ? 0.26 : 0.10)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final top = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(9),
    );
    canvas.drawRRect(top, highlight);
    canvas.drawLine(
      Offset(12, size.height - 5),
      Offset(size.width - 12, size.height - 5),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant _ButtonTrimPainter oldDelegate) {
    return oldDelegate.primary != primary;
  }
}

enum ShellScreen { title, game, settings, scoreboard }

class DragonShell extends StatefulWidget {
  const DragonShell({super.key});

  @override
  State<DragonShell> createState() => _DragonShellState();
}

class _DragonShellState extends State<DragonShell> with WidgetsBindingObserver {
  static const MethodChannel _audioLifecycleChannel = MethodChannel(
    'attack_of_the_dragon/audio_lifecycle',
  );

  final GameAudio _audio = GameAudio();
  final AdMobService _adMob = AdMobService();
  final AdRemovalPurchaseService _adRemoval = AdRemovalPurchaseService();
  late final AppLifecycleListener _appLifecycleListener;
  ShellScreen _screen = ShellScreen.title;
  AppSettings _settings = AppSettings.defaults();
  List<ScoreEntry> _localScores = const [];
  List<ScoreEntry>? _onlineScores;
  bool _scoreboardOverGame = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleListener = AppLifecycleListener(
      onResume: () => _setAudioActive(true),
      onHide: () => _setAudioActive(false),
      onPause: () => _setAudioActive(false),
      onDetach: () => _setAudioActive(false),
    );
    _audioLifecycleChannel.setMethodCallHandler(_handleAudioLifecycleCall);
    _adRemoval
      ..onEntitlementUnlocked = _unlockAdRemoval
      ..addListener(_handleAdRemovalChanged);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioLifecycleChannel.setMethodCallHandler(null);
    _appLifecycleListener.dispose();
    _adRemoval
      ..removeListener(_handleAdRemovalChanged)
      ..dispose();
    _adMob.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setAudioActive(true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _setAudioActive(false);
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _setAudioActive(bool active) {
    if (!active && _keepsAudioActiveForDesktop) return;
    unawaited(_audio.setAppActive(active));
  }

  bool get _keepsAudioActiveForDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  Future<void> _handleAudioLifecycleCall(MethodCall call) async {
    switch (call.method) {
      case 'resumed':
        await _audio.setAppActive(true);
        return;
      case 'inactive':
        // Window focus can be lost while the Flutter view is still visible.
        // The app lifecycle callbacks above handle real backgrounding.
        return;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPlayerName = prefs.getString('playerName');
    final storedPlayerId = prefs.getString('playerId');
    final settings = AppSettings.fromPrefs(prefs);
    final scores = ScoreStore.loadLocalScores(prefs);
    if (storedPlayerName != settings.playerName ||
        storedPlayerId != settings.playerId) {
      await settings.save(prefs);
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _localScores = scores;
      _loaded = true;
    });
    _audio.applySettings(settings);
    _adMob.setAdsRemoved(settings.adsRemoved);
    unawaited(_adRemoval.load(owned: settings.adsRemoved));
    await repairJustAudioAssetCache();
    if (!mounted) return;
    unawaited(_audio.preloadSfx(_preloadedSfxFiles));
    unawaited(_audio.preloadLoopSfx(_preloadedLoopSfxFiles));
    unawaited(
      _audio.playMusicIntroThenLoop(
        introFile: _gameBgmIntroFile,
        loopFile: _gameBgmLoopFile,
      ),
    );
  }

  Future<void> _saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await settings.save(prefs);
    if (!mounted) return;
    setState(() => _settings = settings);
    _audio.applySettings(settings);
    _adMob.setAdsRemoved(settings.adsRemoved);
  }

  Future<void> _unlockAdRemoval() async {
    if (_settings.adsRemoved) {
      _adMob.setAdsRemoved(true);
      return;
    }
    final nextSettings = _settings.copyWith(adsRemoved: true);
    final prefs = await SharedPreferences.getInstance();
    await nextSettings.save(prefs);
    if (!mounted) return;
    setState(() => _settings = nextSettings);
    _adMob.setAdsRemoved(true);
  }

  void _handleAdRemovalChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _recordScore(ScoreEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = await ScoreStore.addLocalScore(prefs, entry);
    if (mounted) setState(() => _localScores = scores);
    if (_scoreApiUrl.isNotEmpty) {
      unawaited(_submitScore(entry));
    }
  }

  Future<void> _submitScore(ScoreEntry entry) async {
    final onlineScores = await ScoreStore.submitScore(entry);
    if (!mounted || onlineScores == null) return;
    setState(() => _onlineScores = onlineScores);
  }

  void _show(ShellScreen screen) {
    setState(() {
      _screen = screen;
      _scoreboardOverGame = false;
    });
  }

  void _showResultScoreboard() {
    setState(() {
      _screen = ShellScreen.game;
      _scoreboardOverGame = true;
    });
  }

  void _hideResultScoreboard() {
    setState(() => _scoreboardOverGame = false);
  }

  int get _bestScore {
    if (_localScores.isEmpty) return 0;
    return _localScores.map((score) => score.score).reduce(math.max);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final strings = DragonStrings.of(context);
    final screen = switch (_screen) {
      ShellScreen.title => TitleScreen(
        audio: _audio,
        onStart: () => _show(ShellScreen.game),
        onSettings: () => _show(ShellScreen.settings),
        onScoreboard: () => _show(ShellScreen.scoreboard),
      ),
      ShellScreen.game => Stack(
        fit: StackFit.expand,
        children: [
          _buildGameScreen(),
          if (_scoreboardOverGame)
            _buildScoreboardScreen(
              backLabel: strings.backToResult,
              onBack: _hideResultScoreboard,
            ),
        ],
      ),
      ShellScreen.settings => SettingsScreen(
        settings: _settings,
        audio: _audio,
        adRemoval: _adRemoval,
        onChanged: _saveSettings,
        onBack: () => _show(ShellScreen.title),
      ),
      ShellScreen.scoreboard => _buildScoreboardScreen(
        onBack: () => _show(ShellScreen.title),
      ),
    };
    return Column(
      children: [
        Expanded(child: screen),
        AdMobBanner(adMob: _adMob),
      ],
    );
  }

  Widget _buildGameScreen() {
    return GameScreen(
      settings: _settings,
      bestScore: _bestScore,
      audio: _audio,
      adMob: _adMob,
      onRankedRunStart: () => ScoreStore.startRankedRun(_settings),
      onScore: _recordScore,
      onTitle: () => _show(ShellScreen.title),
      onScoreboard: _showResultScoreboard,
    );
  }

  Widget _buildScoreboardScreen({
    required VoidCallback onBack,
    String? backLabel,
  }) {
    final strings = DragonStrings.of(context);
    return ScoreboardScreen(
      localScores: _localScores,
      onlineScores: _onlineScores,
      audio: _audio,
      backLabel: backLabel ?? strings.backToTitle,
      onBack: onBack,
    );
  }
}

class TitleScreen extends StatelessWidget {
  const TitleScreen({
    required this.audio,
    required this.onStart,
    required this.onSettings,
    required this.onScoreboard,
    super.key,
  });

  final GameAudio audio;
  final VoidCallback onStart;
  final VoidCallback onSettings;
  final VoidCallback onScoreboard;

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SkyBackdrop(),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/title_logo.png',
                      width: math.min(
                        MediaQuery.sizeOf(context).width - 48,
                        560,
                      ),
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 28),
                    _GamePanel(
                      maxWidth: 352,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MenuButton(
                            icon: Icons.play_arrow_rounded,
                            label: strings.start,
                            onPressed: () {
                              onStart();
                            },
                          ),
                          const SizedBox(height: 14),
                          _MenuButton(
                            icon: Icons.tune_rounded,
                            label: strings.settings,
                            onPressed: () {
                              onSettings();
                            },
                          ),
                          const SizedBox(height: 14),
                          _MenuButton(
                            icon: Icons.leaderboard_rounded,
                            label: strings.scoreboard,
                            onPressed: () {
                              onScoreboard();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isStart = icon == Icons.play_arrow_rounded;
    return _FantasyButton(
      icon: icon,
      label: label,
      onPressed: onPressed,
      tone: isStart ? _FantasyButtonTone.primary : _FantasyButtonTone.secondary,
      height: 60,
      showIconBadge: false,
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.audio,
    required this.adRemoval,
    required this.onChanged,
    required this.onBack,
    super.key,
  });

  final AppSettings settings;
  final GameAudio audio;
  final AdRemovalPurchaseService adRemoval;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final String _emptyNameFallback;
  late AppSettings _draft;
  AccountProvider? _authenticatingProvider;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
    _emptyNameFallback = AppSettings.emptyNameFallback(_draft.playerName);
    _nameController = TextEditingController(text: _draft.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.adsRemoved != widget.settings.adsRemoved) {
      _draft = _draft.copyWith(adsRemoved: widget.settings.adsRemoved);
    }
  }

  void _commit(AppSettings settings) {
    setState(() => _draft = settings);
    widget.onChanged(_settingsForSave(settings));
  }

  AppSettings _settingsForSave(AppSettings settings) {
    final settingsWithEntitlements = settings.copyWith(
      adsRemoved: settings.adsRemoved || widget.settings.adsRemoved,
    );
    if (settingsWithEntitlements.playerName.isNotEmpty) {
      return settingsWithEntitlements;
    }
    return settingsWithEntitlements.copyWith(playerName: _emptyNameFallback);
  }

  void _backToTitle() {
    widget.onChanged(_settingsForSave(_draft));
    widget.onBack();
  }

  bool get _accountBusy => _authenticatingProvider != null;

  AccountProvider? get _accountProviderForPlatform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AccountProvider.google,
      TargetPlatform.iOS => AccountProvider.apple,
      _ => null,
    };
  }

  bool _accountAuthAvailable(AccountProvider provider) {
    return _scoreApiUrl.isNotEmpty && provider == _accountProviderForPlatform;
  }

  IconData _accountProviderIcon(AccountProvider provider) {
    return switch (provider) {
      AccountProvider.google => Icons.g_mobiledata_rounded,
      AccountProvider.apple => Icons.apple_rounded,
    };
  }

  bool _loggedInWith(AccountProvider provider) {
    return _draft.accountProvider == provider;
  }

  Future<void> _authenticateProvider(AccountProvider provider) async {
    final strings = DragonStrings.of(context);
    final settings = _settingsForSave(_draft);
    _commit(settings);
    setState(() => _authenticatingProvider = provider);
    try {
      final credential = switch (provider) {
        AccountProvider.google => await AccountSignIn.signInWithGoogle(),
        AccountProvider.apple => await AccountSignIn.signInWithApple(),
      };
      final player = await ScoreStore.authenticateProvider(
        settings: settings,
        credential: credential,
      );
      if (!mounted) return;
      final nextSettings = settings.copyWith(
        playerId: player.playerId,
        playerName: player.name,
        accountProvider: player.provider,
      );
      _nameController
        ..text = nextSettings.playerName
        ..selection = TextSelection.collapsed(
          offset: nextSettings.playerName.length,
        );
      _commit(nextSettings);
      _showAccountMessage(strings.signedInMessage(provider.label));
    } catch (error, stackTrace) {
      _logAccountAuthError(provider, error, stackTrace);
      _showAccountMessage(_accountAuthErrorMessage(strings, provider, error));
    } finally {
      if (mounted) setState(() => _authenticatingProvider = null);
    }
  }

  static String _accountAuthErrorMessage(
    DragonStrings strings,
    AccountProvider provider,
    Object error,
  ) {
    if (_isSignInCancellation(error)) {
      return strings.signInCanceled;
    }
    if (error is GoogleSignInException) {
      return strings.googleSignInFailed;
    }
    if (error is SignInWithAppleAuthorizationException) {
      return switch (error.code) {
        AuthorizationErrorCode.invalidResponse =>
          strings.missingAppleIdentityToken,
        AuthorizationErrorCode.notInteractive =>
          strings.appleSignInNotInteractive,
        _ => strings.appleSignInFailed,
      };
    }
    final stateError = _stateErrorMessage(error);
    if (stateError == 'missing_google_id_token') {
      return strings.missingGoogleIdToken;
    }
    if (stateError == 'missing_apple_identity_token') {
      return strings.missingAppleIdentityToken;
    }
    if (stateError == 'apple_sign_in_unavailable' ||
        '$error'.contains('apple_sign_in_unavailable')) {
      return strings.appleSignInUnavailable;
    }
    if (stateError == 'score_submit_url_not_configured') {
      return strings.rankingServerNotConfigured;
    }
    if (stateError == 'invalid_token_audience' ||
        stateError == 'invalid_token_issuer' ||
        stateError == 'invalid_id_token') {
      return strings.providerRejected(provider.label);
    }
    return strings.providerSignInFailed(provider.label);
  }

  static String? _stateErrorMessage(Object error) {
    if (error is! StateError) return null;
    return error.message;
  }

  static void _logAccountAuthError(
    AccountProvider provider,
    Object error,
    StackTrace stackTrace,
  ) {
    if (kReleaseMode) return;
    debugPrint('${provider.label} sign-in failed: $error');
    debugPrint('$stackTrace');
  }

  static bool _isSignInCancellation(Object error) {
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled;
    }
    if (error is SignInWithAppleAuthorizationException) {
      return error.code == AuthorizationErrorCode.canceled;
    }
    return false;
  }

  Future<void> _logout(AccountProvider provider) async {
    setState(() => _authenticatingProvider = provider);
    try {
      await AccountSignIn.signOut(provider);
    } catch (_) {
      // 端末側のサインアウトに失敗してもローカルの連携解除は続行する。
    }
    if (!mounted) return;
    // 連携を外したゲストが元アカウントの playerId でスコアを送らないよう、
    // 新しいゲストIDを発行する。再ログインすれば元の playerId に戻る。
    _commit(
      _draft.copyWith(
        playerId: AppSettings.randomPlayerId(),
        clearAccountProvider: true,
      ),
    );
    _showAccountMessage(DragonStrings.of(context).loggedOut);
    setState(() => _authenticatingProvider = null);
  }

  void _showAccountMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    final accountProvider = _accountProviderForPlatform;
    final loggedIn = accountProvider != null && _loggedInWith(accountProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SkyBackdrop(),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(0, constraints.maxHeight - 40),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _GamePanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PanelHeader(
                                icon: Icons.tune_rounded,
                                title: strings.settings,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _nameController,
                                maxLength: AppSettings.maxPlayerNameLength,
                                decoration: InputDecoration(
                                  labelText: strings.playerName,
                                  counterText: '',
                                  hintText: _emptyNameFallback,
                                  hintStyle: const TextStyle(
                                    color: Colors.black38,
                                  ),
                                ),
                                onChanged: (value) {
                                  final clean = AppSettings.cleanName(value);
                                  if (clean != value) {
                                    _nameController
                                      ..text = clean
                                      ..selection = TextSelection.collapsed(
                                        offset: clean.length,
                                      );
                                  }
                                  _commit(_draft.copyWith(playerName: clean));
                                },
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.volume_up_rounded,
                                    size: 20,
                                    color: _UiColors.ember,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      strings.volume,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _UiColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(100 * _draft.volume).round()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: _UiColors.ember,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _draft.volume,
                                onChanged: (value) {
                                  _commit(_draft.copyWith(volume: value));
                                },
                              ),
                              const Divider(height: 26),
                              if (accountProvider != null) ...[
                                if (loggedIn) ...[
                                  _FantasyButton(
                                    icon: Icons.verified_user_rounded,
                                    label: strings.signedInWith(
                                      accountProvider.label,
                                    ),
                                    tone: _FantasyButtonTone.quiet,
                                    height: 50,
                                    onPressed: null,
                                  ),
                                  const SizedBox(height: 10),
                                  _FantasyButton(
                                    icon: Icons.logout_rounded,
                                    label: strings.logout,
                                    tone: _FantasyButtonTone.quiet,
                                    height: 46,
                                    onPressed: _accountBusy
                                        ? null
                                        : () => _logout(accountProvider),
                                  ),
                                ] else
                                  _FantasyButton(
                                    icon: _accountProviderIcon(accountProvider),
                                    label: strings.signInWith(
                                      accountProvider.label,
                                    ),
                                    tone: _FantasyButtonTone.quiet,
                                    height: 50,
                                    busy:
                                        _authenticatingProvider ==
                                        accountProvider,
                                    onPressed:
                                        !_accountAuthAvailable(
                                              accountProvider,
                                            ) ||
                                            _accountBusy
                                        ? null
                                        : () => _authenticateProvider(
                                            accountProvider,
                                          ),
                                  ),
                                const SizedBox(height: 14),
                              ],
                              _AdRemovalSection(
                                adsRemoved: widget.settings.adsRemoved,
                                adRemoval: widget.adRemoval,
                              ),
                              const _ReleaseCredits(),
                              const SizedBox(height: 14),
                              _FantasyButton(
                                icon: Icons.arrow_back_rounded,
                                label: strings.backToTitle,
                                tone: _FantasyButtonTone.secondary,
                                onPressed: _backToTitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdRemovalSection extends StatelessWidget {
  const _AdRemovalSection({required this.adsRemoved, required this.adRemoval});

  final bool adsRemoved;
  final AdRemovalPurchaseService adRemoval;

  @override
  Widget build(BuildContext context) {
    if (!AdRemovalPurchaseService.supported && !adsRemoved) {
      return const SizedBox.shrink();
    }

    final strings = DragonStrings.of(context);
    return AnimatedBuilder(
      animation: adRemoval,
      builder: (context, _) {
        final owned = adsRemoved || adRemoval.owned;
        final message = owned
            ? strings.adRemovalOwned
            : adRemoval.message(strings);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 26),
            Row(
              children: [
                const Icon(
                  Icons.block_rounded,
                  size: 20,
                  color: _UiColors.ember,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.adRemovalTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _UiColors.ink,
                    ),
                  ),
                ),
                Text(
                  adRemoval.priceLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _UiColors.ember,
                  ),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: _UiColors.ink.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
            const SizedBox(height: 10),
            _FantasyButton(
              icon: owned ? Icons.check_circle_rounded : Icons.block_rounded,
              label: owned
                  ? strings.adRemovalOwned
                  : strings.adRemovalBuy(adRemoval.priceLabel),
              tone: _FantasyButtonTone.quiet,
              height: 46,
              busy: !owned && (adRemoval.loading || adRemoval.busy),
              onPressed: owned || !adRemoval.canBuy ? null : adRemoval.buy,
            ),
            if (!owned && AdRemovalPurchaseService.supported) ...[
              const SizedBox(height: 10),
              _FantasyButton(
                icon: Icons.restore_rounded,
                label: strings.adRemovalRestore,
                tone: _FantasyButtonTone.quiet,
                height: 46,
                busy: adRemoval.busy,
                onPressed: adRemoval.canRestore ? adRemoval.restore : null,
              ),
            ],
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

class _ReleaseCredits extends StatelessWidget {
  const _ReleaseCredits();

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: _UiColors.ink.withValues(alpha: 0.72),
      fontWeight: FontWeight.w700,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: _UiColors.ember.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 6),
            const Text(
              'Credits',
              style: TextStyle(
                color: _UiColors.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Music: YouFulca (https://youfulca.com/)', style: bodyStyle),
        const SizedBox(height: 3),
        Text(
          'Font: M PLUS Rounded 1c (SIL Open Font License 1.1)',
          style: bodyStyle,
        ),
        const SizedBox(height: 3),
        Text('SFX: The Ultimate 2017 16 bit Mini pack (CC0)', style: bodyStyle),
      ],
    );
  }
}

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({
    required this.localScores,
    required this.onlineScores,
    required this.audio,
    required this.onBack,
    this.backLabel,
    super.key,
  });

  final List<ScoreEntry> localScores;
  final List<ScoreEntry>? onlineScores;
  final GameAudio audio;
  final VoidCallback onBack;
  final String? backLabel;

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

enum ScoreboardSource {
  online(Icons.public_rounded),
  local(Icons.phone_android_rounded);

  const ScoreboardSource(this.icon);

  final IconData icon;
}

enum ScoreboardPeriod {
  today,
  week,
  month,
  allTime;

  String get queryValue {
    return switch (this) {
      ScoreboardPeriod.today => 'today',
      ScoreboardPeriod.week => 'week',
      ScoreboardPeriod.month => 'month',
      ScoreboardPeriod.allTime => 'all',
    };
  }
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late Future<ScoreboardData> _scores;
  late DragonStrings _strings;
  bool _scoresInitialized = false;
  ScoreboardSource _source = ScoreboardSource.online;
  ScoreboardPeriod _period = ScoreboardPeriod.allTime;

  int get _bestScore {
    if (widget.localScores.isEmpty) return 0;
    return widget.localScores.map((score) => score.score).reduce(math.max);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final strings = DragonStrings.of(context);
    if (_scoresInitialized && _strings.languageCode == strings.languageCode) {
      return;
    }
    _strings = strings;
    _scores = ScoreStore.loadScoreboard(
      widget.localScores,
      period: _period,
      cachedOnlineScores: widget.onlineScores,
      strings: strings,
    );
    _scoresInitialized = true;
  }

  @override
  void didUpdateWidget(covariant ScoreboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localScores != oldWidget.localScores ||
        widget.onlineScores != oldWidget.onlineScores) {
      _scores = ScoreStore.loadScoreboard(
        widget.localScores,
        period: _period,
        cachedOnlineScores: widget.onlineScores,
        strings: _strings,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SkyBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FutureBuilder<ScoreboardData>(
                future: _scores,
                initialData: widget.onlineScores == null
                    ? null
                    : ScoreboardData(
                        onlineScores: widget.onlineScores!,
                        sourceLabel: strings.scoreboardOnline,
                        message: strings.scoreboardSubmittedResultsShown,
                      ),
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final sourceScores = _source == ScoreboardSource.online
                      ? data?.onlineScores ?? const <ScoreEntry>[]
                      : widget.localScores;
                  final scores = ScoreStore.filterByPeriod(
                    sourceScores,
                    _period,
                  );
                  final itemCount = math.min(
                    scores.length,
                    ScoreStore.maxLeaderboardEntries,
                  );
                  final isLoading =
                      data == null &&
                      snapshot.connectionState != ConnectionState.done;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _GamePanel(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PanelHeader(
                                icon: Icons.leaderboard_rounded,
                                title: strings.scoreboard,
                                color: _UiColors.teal,
                                trailing: isLoading
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _BestScoreBlock(score: _bestScore),
                              const SizedBox(height: 10),
                              _ScoreboardControls(
                                source: _source,
                                period: _period,
                                strings: strings,
                                onSourceChanged: (value) {
                                  setState(() {
                                    _source = value;
                                    if (value == ScoreboardSource.online) {
                                      _scores = ScoreStore.loadScoreboard(
                                        widget.localScores,
                                        period: _period,
                                        cachedOnlineScores: widget.onlineScores,
                                        strings: strings,
                                      );
                                    }
                                  });
                                },
                                onPeriodChanged: (value) {
                                  setState(() {
                                    _period = value;
                                    if (_source == ScoreboardSource.online) {
                                      _scores = ScoreStore.loadScoreboard(
                                        widget.localScores,
                                        period: value,
                                        cachedOnlineScores: widget.onlineScores,
                                        strings: strings,
                                      );
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 10),
                              _ScoreboardListHeader(
                                sourceLabel: _source == ScoreboardSource.online
                                    ? data?.sourceLabel ??
                                          strings.scoreboardOnline
                                    : strings.scoreboardLocal,
                                periodLabel: strings.scoreboardPeriodLabel(
                                  _period,
                                ),
                                count: itemCount,
                                strings: strings,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child:
                                    isLoading &&
                                        _source == ScoreboardSource.online
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : itemCount == 0
                                    ? Center(
                                        child: Text(
                                          _source == ScoreboardSource.online
                                              ? strings.noOnlineRankings
                                              : strings.noLocalRecords,
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: itemCount,
                                        itemBuilder: (context, index) {
                                          return _ScoreRow(
                                            rank: index + 1,
                                            score: scores[index],
                                            showDateTime:
                                                _source ==
                                                    ScoreboardSource.local ||
                                                data?.sourceLabel ==
                                                    strings.scoreboardLocal,
                                          );
                                        },
                                      ),
                              ),
                              if (_source == ScoreboardSource.online &&
                                  (data?.message ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    data!.message,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FantasyButton(
                        icon: Icons.arrow_back_rounded,
                        label: widget.backLabel ?? strings.backToTitle,
                        tone: _FantasyButtonTone.secondary,
                        onPressed: () {
                          widget.onBack();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreboardControls extends StatelessWidget {
  const _ScoreboardControls({
    required this.source,
    required this.period,
    required this.strings,
    required this.onSourceChanged,
    required this.onPeriodChanged,
  });

  final ScoreboardSource source;
  final ScoreboardPeriod period;
  final DragonStrings strings;
  final ValueChanged<ScoreboardSource> onSourceChanged;
  final ValueChanged<ScoreboardPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0);
    final sourceStyle = _controlStyle(
      minimumSize: const Size(128, 40),
      horizontalPadding: 14,
    );
    final periodStyle = _controlStyle(
      minimumSize: const Size(74, 36),
      horizontalPadding: 12,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _UiColors.gold.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _UiColors.gold.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ScoreboardSource>(
              showSelectedIcon: false,
              selected: {source},
              style: sourceStyle,
              segments: ScoreboardSource.values
                  .map(
                    (value) => ButtonSegment<ScoreboardSource>(
                      value: value,
                      icon: Icon(value.icon),
                      label: Text(
                        strings.scoreboardSourceLabel(value),
                        style: textStyle,
                      ),
                    ),
                  )
                  .toList(),
              onSelectionChanged: (values) => onSourceChanged(values.first),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ScoreboardPeriod>(
                showSelectedIcon: false,
                selected: {period},
                style: periodStyle,
                segments: ScoreboardPeriod.values
                    .map(
                      (value) => ButtonSegment<ScoreboardPeriod>(
                        value: value,
                        label: Text(
                          strings.scoreboardPeriodLabel(value),
                          style: textStyle,
                        ),
                      ),
                    )
                    .toList(),
                onSelectionChanged: (values) => onPeriodChanged(values.first),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _controlStyle({
    required Size minimumSize,
    required double horizontalPadding,
  }) {
    const selectedBackground = _UiColors.ember;
    final unselectedBackground = Colors.white.withValues(alpha: 0.76);
    final selectedBorder = _UiColors.gold.withValues(alpha: 0.58);
    final unselectedBorder = _UiColors.ink.withValues(alpha: 0.20);

    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(minimumSize),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return selectedBackground;
        return unselectedBackground;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return _UiColors.ink;
      }),
      iconColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return _UiColors.ink.withValues(alpha: 0.82);
      }),
      overlayColor: WidgetStateProperty.all(
        _UiColors.gold.withValues(alpha: 0.14),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.selected)
              ? selectedBorder
              : unselectedBorder,
          width: states.contains(WidgetState.selected) ? 1.4 : 1,
        );
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
      ),
    );
  }
}

class _ScoreboardListHeader extends StatelessWidget {
  const _ScoreboardListHeader({
    required this.sourceLabel,
    required this.periodLabel,
    required this.count,
    required this.strings,
  });

  final String sourceLabel;
  final String periodLabel;
  final int count;
  final DragonStrings strings;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: Colors.black54,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            '$sourceLabel / $periodLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 10),
        Text(strings.countEntries(count), style: style),
      ],
    );
  }
}

class _BestScoreBlock extends StatelessWidget {
  const _BestScoreBlock({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    final scoreText = score == 0 ? '--' : '$score m';
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _UiColors.gold.withValues(alpha: 0.30),
            _UiColors.paperWarm.withValues(alpha: 0.55),
            _UiColors.gold.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _UiColors.deepGold.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const _IconBadge(
              icon: Icons.workspace_premium_rounded,
              color: _UiColors.deepGold,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.bestScore,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff8a5a23),
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    scoreText,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: const Color(0xff662b15),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.score,
    this.showDateTime = false,
  });

  final int rank;
  final ScoreEntry score;
  final bool showDateTime;

  Color get _accentColor {
    return switch (rank) {
      1 => const Color(0xffc58b12),
      2 => const Color(0xff78838f),
      3 => const Color(0xffad642c),
      _ => Colors.black54,
    };
  }

  IconData get _rankIcon {
    return rank == 1 ? Icons.emoji_events_rounded : Icons.military_tech_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    final topRank = rank <= 3;
    final accent = _accentColor;
    final nameStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontWeight: topRank ? FontWeight.w800 : FontWeight.w600,
      color: const Color(0xff1f1d1a),
    );
    final scoreStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: topRank ? accent : const Color(0xff1f1d1a),
    );
    final primaryText = showDateTime
        ? strings.formatScoreDateTime(score.date)
        : score.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: topRank
                ? [
                    accent.withValues(alpha: 0.22),
                    _UiColors.paperWarm.withValues(alpha: 0.46),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.62),
                    _UiColors.paper.withValues(alpha: 0.38),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: topRank
                ? accent.withValues(alpha: 0.30)
                : _UiColors.ember.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: _UiColors.ink.withValues(alpha: topRank ? 0.10 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Center(
                  child: topRank
                      ? SizedBox.square(
                          dimension: 34,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(accent, Colors.white, 0.45)!,
                                  accent,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              _rankIcon,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      : Text(
                          '$rank',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black45,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ScorePrimaryText(
                      text: primaryText,
                      style: nameStyle,
                      preserveFullText: showDateTime,
                    ),
                    Text(
                      strings.killsCount(score.kills),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 72, maxWidth: 104),
                child: Text(
                  '${score.score} m',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: scoreStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorePrimaryText extends StatelessWidget {
  const _ScorePrimaryText({
    required this.text,
    required this.style,
    required this.preserveFullText,
  });

  final String text;
  final TextStyle? style;
  final bool preserveFullText;

  @override
  Widget build(BuildContext context) {
    if (!preserveFullText) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.settings,
    required this.bestScore,
    required this.audio,
    required this.adMob,
    required this.onRankedRunStart,
    required this.onScore,
    required this.onTitle,
    required this.onScoreboard,
    this.images,
    super.key,
  });

  final AppSettings settings;
  final int bestScore;
  final GameAudio audio;
  final AdMobService adMob;
  final Future<String?> Function() onRankedRunStart;
  final Future<void> Function(ScoreEntry score) onScore;
  final VoidCallback onTitle;
  final VoidCallback onScoreboard;
  final Future<GameImages>? images;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum RunState { ready, playing, paused, gameOver }

enum EnemyKind { bat, bird, slime, mage, gargoyle }

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const _dragonFrameSize = Size(256, 192);
  static const _enemyCellSize = Size(256, 256);
  static const double _fireSpreadAngle = 0.20;
  // 最後の発射からこの時間だけ炎ループ音を鳴らし続ける(発射間隔0.14sより長く)。
  static const double _fireSfxLingerSeconds = 0.25;
  static const double _tapLiftSpeedFactor = 0.36;
  static const double _rhythmTapInterval = 0.75;
  static const double _gravityFactor =
      2 * _tapLiftSpeedFactor / _rhythmTapInterval;

  final math.Random _rng = math.Random();
  late final Ticker _ticker;
  late final Future<GameImages> _images;
  Duration? _lastTick;
  Size _worldSize = Size.zero;
  RunState _state = RunState.ready;
  double _time = 0;
  // 直近のインタースティシャル表示からの累計プレイ時間 (ラン間で持ち越す)。
  double _playSecondsSinceInterstitial = 0;
  double _dragonY = 0;
  double _velocityY = 0;
  double _backgroundOffset = 0;
  double _score = 0;
  int _kills = 0;
  double _spawnTimer = 0.8;
  double _fireTimer = 0;
  double _fireSfxStopTimer = 0;
  bool _scoreRecorded = false;
  bool _isNewRecord = false;
  int _runId = 0;
  String? _runToken;
  int _lastDangerPattern = -1;
  final List<EnemyModel> _enemies = [];
  final List<ProjectileModel> _fireballs = [];
  final List<ProjectileModel> _enemyBullets = [];
  final List<EffectModel> _effects = [];

  @override
  void initState() {
    super.initState();
    _images = widget.images ?? GameImages.load();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _stopFireSfx();
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    final dt = math.min(
      (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
      1 / 30,
    );
    if (_state == RunState.playing && _worldSize != Size.zero) {
      _updateGame(dt);
      if (mounted) setState(() {});
    }
  }

  void _reset() {
    _stopFireSfx();
    setState(() {
      _state = RunState.ready;
      _time = 0;
      _velocityY = 0;
      _backgroundOffset = 0;
      _score = 0;
      _kills = 0;
      _spawnTimer = 0.8;
      _fireTimer = 0;
      _lastTick = null;
      _scoreRecorded = false;
      _isNewRecord = false;
      _runId += 1;
      _runToken = null;
      _lastDangerPattern = -1;
      _enemies.clear();
      _fireballs.clear();
      _enemyBullets.clear();
      _effects.clear();
      _dragonY = _worldSize.height * 0.45;
    });
  }

  void _tap() {
    if (_worldSize == Size.zero ||
        _state == RunState.paused ||
        _state == RunState.gameOver) {
      return;
    }
    final liftVelocity = -_worldSize.height * _tapLiftSpeedFactor;
    if (_state == RunState.ready) {
      final runId = _runId + 1;
      setState(() {
        _runId = runId;
        _runToken = null;
        _state = RunState.playing;
        _scoreRecorded = false;
        _velocityY = liftVelocity;
      });
      unawaited(_startRankedRun(runId));
    } else {
      _velocityY = liftVelocity;
    }
  }

  Future<void> _startRankedRun(int runId) async {
    final token = await widget.onRankedRunStart();
    if (!mounted || runId != _runId || _state == RunState.ready) return;
    _runToken = token;
  }

  void _retry() {
    final shouldShowInterstitial =
        Duration(
          milliseconds: (_playSecondsSinceInterstitial * 1000).round(),
        ) >=
        _interstitialRetryPlayTime;
    if (!shouldShowInterstitial || !widget.adMob.isInterstitialReady) {
      if (shouldShowInterstitial) {
        // 次のリトライで表示できるように読み込みだけ進めておく。
        widget.adMob.warmUp();
      }
      _reset();
      return;
    }
    _playSecondsSinceInterstitial = 0;
    // 広告のAdActivityが半透明だとFlutterのライフサイクルがpausedまで
    // 進まずBGMが鳴り続けるため、表示前後で明示的に止めて戻す。
    unawaited(widget.audio.pauseMusic());
    unawaited(
      widget.adMob.showInterstitialBefore(() {
        unawaited(widget.audio.resumeMusic());
        _reset();
      }),
    );
  }

  void _togglePause() {
    if (_state == RunState.playing) {
      _stopFireSfx();
      setState(() => _state = RunState.paused);
    } else if (_state == RunState.paused) {
      setState(() => _state = RunState.playing);
    }
  }

  void _updateGame(double dt) {
    final w = _worldSize.width;
    final h = _worldSize.height;
    final speed = _baseSpeed;
    final dragon = _dragonRect;
    _time += dt;
    _score += dt * 82;
    _backgroundOffset += speed * 0.2 * dt;

    final nextVelocityY = math.min(
      _velocityY + h * _gravityFactor * dt,
      h * 0.36,
    );
    _dragonY += (_velocityY + nextVelocityY) * 0.5 * dt;
    _velocityY = nextVelocityY;
    if (_dragonY - dragon.height * 0.45 <= 0 ||
        _dragonY + dragon.height * 0.45 >= h) {
      _gameOver();
      return;
    }

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnPattern();
      _spawnTimer = 0.46 + _rng.nextDouble() * 0.18;
    }

    _fireTimer -= dt;
    if (_fireTimer <= 0) {
      final targets = _targetEnemies(1);
      if (targets.isNotEmpty) {
        _shootFire(targets.first);
        _fireTimer = 0.14;
      }
    }
    if (_fireSfxStopTimer > 0) {
      _fireSfxStopTimer -= dt;
      if (_fireSfxStopTimer <= 0) {
        _stopFireSfx();
      }
    }

    for (final enemy in _enemies) {
      enemy.time += dt;
      enemy.x -= enemy.speed * dt;
      enemy.y =
          enemy.baseY +
          math.sin(enemy.phase + enemy.time * enemy.waveRate) * enemy.amplitude;
      if (enemy.kind == EnemyKind.mage) {
        enemy.shootTimer -= dt;
        if (enemy.shootTimer <= 0 && enemy.x < w * 0.93 && enemy.x > w * 0.36) {
          _shootEnemyBullet(enemy);
          enemy.shootTimer = 1.7 + _rng.nextDouble() * 0.45;
        }
      }
    }

    for (final shot in _fireballs) {
      shot.x += shot.vx * dt;
      shot.y += shot.vy * dt;
    }
    for (final shot in _enemyBullets) {
      shot.x += shot.vx * dt;
      shot.y += shot.vy * dt;
    }
    for (final effect in _effects) {
      effect.age += dt;
    }

    _resolveFireballHits();
    _resolvePlayerHits();

    _enemies.removeWhere((e) => e.x < -e.size * 1.3 || e.dead);
    _fireballs.removeWhere(
      (p) => p.dead || p.x > w + 160 || p.y < -120 || p.y > h + 120,
    );
    _enemyBullets.removeWhere((p) => p.x < -80 || p.dead);
    _effects.removeWhere((e) => e.age >= e.duration);
  }

  double get _shortSide => math.min(_worldSize.width, _worldSize.height);

  double get _baseSpeed => math.max(165, _shortSide * 0.42);

  double get _spawnLead => math.max(86, _shortSide * 0.22);

  double get _enemySpacing => math.max(62, _shortSide * 0.17);

  double get _flappyGap =>
      (_worldSize.height * 0.24).clamp(118.0, 190.0).toDouble();

  Rect get _dragonRect {
    final w = (_shortSide * 0.145).clamp(50.0, 104.0).toDouble();
    final h = w * 0.72;
    return Rect.fromCenter(
      center: Offset(_worldSize.width * 0.22, _dragonY),
      width: w,
      height: h,
    );
  }

  List<EnemyModel> _targetEnemies(int maxTargets) {
    final dragonX = _dragonRect.center.dx;
    final candidates = <({EnemyModel enemy, double distance})>[];
    for (final enemy in _enemies) {
      if (enemy.dead || enemy.x < dragonX + 24) continue;
      final d = (enemy.x - dragonX).abs() + (enemy.y - _dragonY).abs() * 0.35;
      candidates.add((enemy: enemy, distance: d));
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates.take(maxTargets).map((item) => item.enemy).toList();
  }

  void _shootFire(EnemyModel target) {
    final start = Offset(_dragonRect.right - 8, _dragonY - 4);
    final end = Offset(target.x, target.y);
    final delta = end - start;
    final speed = math.max(720.0, _shortSide * 1.36);
    final radius = (_shortSide * 0.026).clamp(8.0, 14.0).toDouble();
    final baseAngle = math.atan2(delta.dy, delta.dx);
    for (final angleOffset in const [
      -_fireSpreadAngle,
      0.0,
      _fireSpreadAngle,
    ]) {
      final angle = baseAngle + angleOffset;
      _fireballs.add(
        ProjectileModel(
          x: start.dx,
          y: start.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          radius: radius,
          spriteIndex: 6,
        ),
      );
    }
    _fireSfxStopTimer = _fireSfxLingerSeconds;
    unawaited(
      widget.audio.startLoopSfx(
        _dragonFireLoopSfxFile,
        volumeScale: _dragonFireSfxVolumeScale,
      ),
    );
  }

  void _stopFireSfx() {
    _fireSfxStopTimer = 0;
    unawaited(widget.audio.stopLoopSfx(_dragonFireLoopSfxFile));
  }

  void _shootEnemyBullet(EnemyModel enemy) {
    _enemyBullets.add(
      ProjectileModel(
        x: enemy.x - enemy.size * 0.28,
        y: enemy.y,
        vx: -_baseSpeed * 0.95,
        vy: (_dragonY - enemy.y).clamp(-90, 90) * 0.36,
        radius: (_shortSide * 0.022).clamp(7.0, 12.0).toDouble(),
        spriteIndex: 5,
      ),
    );
  }

  void _resolveFireballHits() {
    for (final shot in _fireballs) {
      for (final enemy in _enemies) {
        if (enemy.dead) continue;
        final hitDistance = enemy.radius + shot.radius;
        final dx = enemy.x - shot.x;
        final dy = enemy.y - shot.y;
        if (dx * dx + dy * dy <= hitDistance * hitDistance) {
          shot.dead = true;
          enemy.hp -= 1;
          _effects.add(
            EffectModel(
              x: shot.x,
              y: shot.y,
              size: enemy.size * 0.42,
              spriteIndex: 7,
              duration: 0.22,
            ),
          );
          if (enemy.hp <= 0) {
            enemy.dead = true;
            _kills += 1;
            _score += 22;
            _effects.add(
              EffectModel(
                x: enemy.x,
                y: enemy.y,
                size: enemy.size * 1.05,
                spriteIndex: 8,
                duration: 0.34,
              ),
            );
            unawaited(
              widget.audio.playSfx(
                _enemyBurstSfxFile,
                volumeScale: _enemyBurstSfxVolumeScale,
              ),
            );
          }
          break;
        }
      }
    }
  }

  void _resolvePlayerHits() {
    final dragon = _dragonRect;
    final playerRadius = math.min(dragon.width, dragon.height) * 0.48;
    for (final enemy in _enemies) {
      final dx = enemy.x - dragon.center.dx;
      final dy = enemy.y - dragon.center.dy;
      final hitDistance = playerRadius + enemy.radius * 0.9;
      if (dx * dx + dy * dy <= hitDistance * hitDistance) {
        _gameOver();
        return;
      }
    }
    for (final bullet in _enemyBullets) {
      final dx = bullet.x - dragon.center.dx;
      final dy = bullet.y - dragon.center.dy;
      final hitDistance = playerRadius + bullet.radius;
      if (dx * dx + dy * dy <= hitDistance * hitDistance) {
        _gameOver();
        return;
      }
    }
  }

  void _gameOver() {
    if (_state == RunState.gameOver) return;
    _state = RunState.gameOver;
    _stopFireSfx();
    _playSecondsSinceInterstitial += _time;
    _velocityY = 0;
    _isNewRecord = _score.round() > widget.bestScore;
    if (!_scoreRecorded) {
      _scoreRecorded = true;
      unawaited(
        widget.onScore(
          ScoreEntry(
            playerId: widget.settings.playerId,
            name: AppSettings.scoreName(widget.settings.playerName),
            score: _score.round(),
            kills: _kills,
            date: DateTime.now().toUtc(),
            version: _gameVersion,
            runToken: _runToken,
          ),
        ),
      );
    }
  }

  void _spawnPattern() {
    final patterns = List<int>.generate(8, (i) => i);
    if (_lastDangerPattern >= 0) {
      patterns.remove(_lastDangerPattern);
    }
    final pattern = patterns[_rng.nextInt(patterns.length)];
    if (pattern == 3 || pattern == 5) {
      _lastDangerPattern = pattern;
    } else if (_rng.nextBool()) {
      _lastDangerPattern = -1;
    }

    switch (pattern) {
      case 0:
        _spawnRow(EnemyKind.bat, 8, _safeY());
      case 1:
        final gap = _safeY();
        final large = EnemySpec.forKind(EnemyKind.gargoyle, _worldSize).size;
        final x = _worldSize.width + _spawnLead;
        _addEnemy(EnemyKind.gargoyle, x, gap - _flappyGap / 2 - large * 0.52);
        _addEnemy(EnemyKind.gargoyle, x, gap + _flappyGap / 2 + large * 0.52);
        _addEnemy(EnemyKind.bat, x + _enemySpacing, gap - _flappyGap * 0.46);
        _addEnemy(
          EnemyKind.bat,
          x + _enemySpacing * 1.35,
          gap + _flappyGap * 0.46,
        );
        _addEnemy(
          EnemyKind.slime,
          x + _enemySpacing * 2.0,
          gap - _flappyGap * 0.34,
        );
        _addEnemy(
          EnemyKind.slime,
          x + _enemySpacing * 2.35,
          gap + _flappyGap * 0.34,
        );
      case 2:
        final cx = _worldSize.width + _spawnLead * 1.25;
        final cy = _safeY();
        final ringRadius = (_shortSide * 0.13).clamp(46.0, 78.0).toDouble();
        for (var i = 0; i < 12; i++) {
          final a = i / 12 * math.pi * 2;
          _addEnemy(
            EnemyKind.bat,
            cx + math.cos(a) * ringRadius,
            cy + math.sin(a) * ringRadius,
            amplitude: _shortSide * 0.035,
            phase: a,
            waveRate: 3.2,
          );
        }
      case 3:
        final gap = _safeY();
        final x = _worldSize.width + _spawnLead;
        final positions = <double>[
          _worldSize.height * 0.12,
          _worldSize.height * 0.24,
          _worldSize.height * 0.36,
          _worldSize.height * 0.48,
          _worldSize.height * 0.60,
          _worldSize.height * 0.72,
          _worldSize.height * 0.87,
        ];
        for (final y in positions) {
          if ((y - gap).abs() < _flappyGap * 0.56) continue;
          _addEnemy(EnemyKind.gargoyle, x, y);
        }
        _addEnemy(EnemyKind.bat, x + _enemySpacing * 0.95, gap);
      case 4:
        final y = _safeY();
        _addEnemy(EnemyKind.mage, _worldSize.width + _spawnLead * 1.6, y);
        _addEnemy(
          EnemyKind.bat,
          _worldSize.width + _spawnLead,
          y - _flappyGap * 0.45,
        );
        _addEnemy(
          EnemyKind.slime,
          _worldSize.width + _spawnLead * 1.1,
          y + _flappyGap * 0.45,
        );
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead * 1.85,
          y - _flappyGap * 0.18,
          speedBoost: 1.08,
        );
        _addEnemy(
          EnemyKind.bat,
          _worldSize.width + _spawnLead * 1.35,
          y + _flappyGap * 0.16,
        );
        _addEnemy(
          EnemyKind.slime,
          _worldSize.width + _spawnLead * 2.0,
          y + _flappyGap * 0.34,
        );
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead * 2.25,
          y - _flappyGap * 0.42,
          speedBoost: 1.12,
        );
        _addEnemy(
          EnemyKind.bat,
          _worldSize.width + _spawnLead * 2.45,
          y + _flappyGap * 0.52,
        );
      case 5:
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead,
          _safeY(),
          speedBoost: 1.32,
        );
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead + _enemySpacing * 0.72,
          _safeY(),
          speedBoost: 1.24,
        );
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead + _enemySpacing * 1.45,
          _safeY(),
          speedBoost: 1.18,
        );
        _addEnemy(
          EnemyKind.bird,
          _worldSize.width + _spawnLead + _enemySpacing * 2.15,
          _safeY(),
          speedBoost: 1.14,
        );
        _addEnemy(
          EnemyKind.bat,
          _worldSize.width + _spawnLead + _enemySpacing * 2.7,
          _safeY(),
          speedBoost: 1.08,
        );
      case 6:
        final startY = _worldSize.height * (0.25 + _rng.nextDouble() * 0.2);
        for (var i = 0; i < 9; i++) {
          _addEnemy(
            EnemyKind.bat,
            _worldSize.width + _spawnLead + i * _enemySpacing,
            startY + i * _enemySpacing * 0.72,
          );
        }
      case 7:
        for (var i = 0; i < 10; i++) {
          final y = i.isEven
              ? _worldSize.height * 0.28
              : _worldSize.height * 0.68;
          _addEnemy(
            EnemyKind.bat,
            _worldSize.width + _spawnLead + i * _enemySpacing,
            y,
          );
        }
    }
  }

  void _spawnRow(EnemyKind kind, int count, double y) {
    for (var i = 0; i < count; i++) {
      _addEnemy(
        kind,
        _worldSize.width + _spawnLead + i * _enemySpacing,
        y + (i - (count - 1) / 2) * _shortSide * 0.015,
      );
    }
  }

  double _safeY() {
    final large = EnemySpec.forKind(EnemyKind.gargoyle, _worldSize).size;
    final margin = math.max(
      _flappyGap * 0.56 + large * 0.56,
      _worldSize.height * 0.16,
    );
    final maxY = _worldSize.height - margin;
    if (maxY <= margin) return _worldSize.height / 2;
    return margin + _rng.nextDouble() * (maxY - margin);
  }

  void _addEnemy(
    EnemyKind kind,
    double x,
    double y, {
    double amplitude = 0,
    double phase = 0,
    double waveRate = 2.0,
    double speedBoost = 1.0,
  }) {
    final spec = EnemySpec.forKind(kind, _worldSize);
    final margin = math.max(spec.size * 0.52, 28.0);
    final maxY = _worldSize.height - margin;
    final clampedY = maxY <= margin
        ? _worldSize.height / 2
        : y.clamp(margin, maxY).toDouble();
    _enemies.add(
      EnemyModel(
        kind: kind,
        x: x,
        y: clampedY,
        baseY: clampedY,
        size: spec.size,
        speed: spec.speed * speedBoost,
        hp: spec.hp,
        spriteIndex: spec.spriteIndex,
        amplitude: amplitude,
        phase: phase,
        waveRate: waveRate,
        motionPhase: _rng.nextDouble() * math.pi * 2,
        shootTimer: kind == EnemyKind.mage ? 1.0 + _rng.nextDouble() : 999,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return FutureBuilder<GameImages>(
      future: _images,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: SafeArea(
              bottom: false,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final images = snapshot.data!;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                if (_worldSize != size) {
                  _worldSize = size;
                  if (_dragonY == 0) _dragonY = size.height * 0.45;
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _tap,
                        child: CustomPaint(
                          painter: DragonGamePainter(
                            images: images,
                            state: _state,
                            time: _time,
                            backgroundOffset: _backgroundOffset,
                            score: _score,
                            kills: _kills,
                            killChipText: strings.killsCount(_kills),
                            dragonRect: _dragonRect,
                            dragonFrameSize: _dragonFrameSize,
                            enemyCellSize: _enemyCellSize,
                            enemies: _enemies,
                            fireballs: _fireballs,
                            enemyBullets: _enemyBullets,
                            effects: _effects,
                          ),
                        ),
                      ),
                    ),
                    if (_state == RunState.ready)
                      const IgnorePointer(child: _ReadyPrompt()),
                    if (_state == RunState.paused)
                      _PauseOverlay(onResume: _togglePause),
                    if (_state == RunState.gameOver)
                      _ResultOverlay(
                        score: _score.round(),
                        bestScore: math.max(widget.bestScore, _score.round()),
                        kills: _kills,
                        isNewRecord: _isNewRecord,
                        onRetry: _retry,
                        onTitle: widget.onTitle,
                        onScoreboard: widget.onScoreboard,
                        audio: widget.audio,
                      ),
                    if (_state == RunState.playing || _state == RunState.paused)
                      _PauseButton(
                        paused: _state == RunState.paused,
                        onPressed: _togglePause,
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.paused, required this.onPressed});

  final bool paused;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _UiColors.ink.withValues(alpha: 0.72),
                  _UiColors.ember.withValues(alpha: 0.76),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: _UiColors.gold.withValues(alpha: 0.55),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onPressed,
              tooltip: paused ? strings.resume : strings.pause,
              color: Colors.white,
              icon: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadyPrompt extends StatefulWidget {
  const _ReadyPrompt();

  @override
  State<_ReadyPrompt> createState() => _ReadyPromptState();
}

class _ReadyPromptState extends State<_ReadyPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    final pulse = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return Align(
      alignment: const Alignment(0, 0.42),
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -5 * pulse.value),
            child: Transform.scale(scale: 1 + 0.04 * pulse.value, child: child),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _UiColors.ink.withValues(alpha: 0.80),
                _UiColors.ember.withValues(alpha: 0.76),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _UiColors.gold.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _UiColors.gold.withValues(alpha: 0.25),
                blurRadius: 18,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  color: _UiColors.gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  strings.tapToStart,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverlayScrim extends StatelessWidget {
  const _GameOverlayScrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
        child: ColoredBox(
          color: _UiColors.ink.withValues(alpha: 0.38),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * value,
                    child: child,
                  ),
                );
              },
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return _GameOverlayScrim(
      child: _GamePanel(
        maxWidth: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.pause_circle_filled_rounded,
              size: 44,
              color: _UiColors.ember,
            ),
            const SizedBox(height: 8),
            Text(
              strings.pause,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _UiColors.ink,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 18),
            _FantasyButton(
              icon: Icons.play_arrow_rounded,
              label: strings.resume,
              onPressed: onResume,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.score,
    required this.bestScore,
    required this.kills,
    required this.isNewRecord,
    required this.onRetry,
    required this.onTitle,
    required this.onScoreboard,
    required this.audio,
  });

  final int score;
  final int bestScore;
  final int kills;
  final bool isNewRecord;
  final VoidCallback onRetry;
  final VoidCallback onTitle;
  final VoidCallback onScoreboard;
  final GameAudio audio;

  @override
  Widget build(BuildContext context) {
    final strings = DragonStrings.of(context);
    return _GameOverlayScrim(
      child: _GamePanel(
        maxWidth: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'GAME OVER',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _UiColors.ember,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
            const SizedBox(height: 10),
            if (isNewRecord) ...[
              Align(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_UiColors.gold, _UiColors.flame],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _UiColors.gold.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.newRecord,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text.rich(
              TextSpan(
                text: '$score',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _UiColors.ink,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
                children: [
                  TextSpan(
                    text: ' m',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: _UiColors.ink.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ResultStatChip(
                    icon: Icons.workspace_premium_rounded,
                    label: strings.best,
                    value: '$bestScore m',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ResultStatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: strings.defeated,
                    value: '$kills',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _FantasyButton(
              icon: Icons.replay_rounded,
              label: strings.retry,
              onPressed: () {
                onRetry();
              },
            ),
            const SizedBox(height: 10),
            _FantasyButton(
              icon: Icons.leaderboard_rounded,
              label: strings.scoreboard,
              tone: _FantasyButtonTone.secondary,
              height: 50,
              onPressed: () {
                onScoreboard();
              },
            ),
            const SizedBox(height: 10),
            _FantasyButton(
              icon: Icons.home_rounded,
              label: strings.backToTitle,
              tone: _FantasyButtonTone.secondary,
              height: 50,
              onPressed: () {
                onTitle();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultStatChip extends StatelessWidget {
  const _ResultStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _UiColors.deepGold.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: _UiColors.ember),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _UiColors.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _UiColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DragonGamePainter extends CustomPainter {
  static const Rect _dragonVisibleSource = Rect.fromLTWH(15, 12, 226, 167);
  static const double _fireballSourceAngle = math.pi * 0.8;
  static const double _enemyBulletSourceAngle = math.pi;

  DragonGamePainter({
    required this.images,
    required this.state,
    required this.time,
    required this.backgroundOffset,
    required this.score,
    required this.kills,
    required this.killChipText,
    required this.dragonRect,
    required this.dragonFrameSize,
    required this.enemyCellSize,
    required this.enemies,
    required this.fireballs,
    required this.enemyBullets,
    required this.effects,
  });

  final GameImages images;
  final RunState state;
  final double time;
  final double backgroundOffset;
  final double score;
  final int kills;
  final String killChipText;
  final Rect dragonRect;
  final Size dragonFrameSize;
  final Size enemyCellSize;
  final List<EnemyModel> enemies;
  final List<ProjectileModel> fireballs;
  final List<ProjectileModel> enemyBullets;
  final List<EffectModel> effects;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    for (final shot in fireballs) {
      _drawAtlasSprite(
        canvas,
        images.enemyAtlas,
        shot.spriteIndex,
        shot.rect,
        3,
        rotation: _projectileRotation(shot, _fireballSourceAngle),
      );
    }
    for (final bullet in enemyBullets) {
      _drawAtlasSprite(
        canvas,
        images.enemyAtlas,
        bullet.spriteIndex,
        bullet.rect,
        3,
        rotation: _projectileRotation(bullet, _enemyBulletSourceAngle),
      );
    }
    for (final enemy in enemies) {
      _drawEnemy(canvas, enemy);
    }
    for (final effect in effects) {
      final alpha = (1 - effect.age / effect.duration).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      _drawAtlasSprite(
        canvas,
        images.enemyAtlas,
        effect.spriteIndex,
        effect.rect,
        3,
        paint: paint,
      );
    }
    _drawDragon(canvas);
    _drawHud(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final scale = size.height / images.sky.height;
    final drawW = images.sky.width * scale;
    final src = Rect.fromLTWH(
      0,
      0,
      images.sky.width.toDouble(),
      images.sky.height.toDouble(),
    );
    var x = -backgroundOffset % drawW - drawW;
    final paint = Paint()..filterQuality = FilterQuality.high;
    while (x < size.width + drawW) {
      canvas.drawImageRect(
        images.sky,
        src,
        Rect.fromLTWH(x, 0, drawW, size.height),
        paint,
      );
      x += drawW;
    }
  }

  void _drawDragon(Canvas canvas) {
    final frame = (time * 12).floor() % 6;
    final src = Rect.fromLTWH(
      frame * dragonFrameSize.width + _dragonVisibleSource.left,
      _dragonVisibleSource.top,
      _dragonVisibleSource.width,
      _dragonVisibleSource.height,
    );
    canvas.drawImageRect(
      images.dragonAtlas,
      src,
      dragonRect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _drawEnemy(Canvas canvas, EnemyModel enemy) {
    final motion = _enemyMotion(enemy);
    _drawAtlasSprite(
      canvas,
      images.enemyAtlas,
      _enemySpriteIndex(enemy),
      motion.rect,
      3,
      flipX: enemy.shouldFlipSprite,
      rotation: motion.rotation,
      scaleX: motion.scaleX,
      scaleY: motion.scaleY,
    );
  }

  int _enemySpriteIndex(EnemyModel enemy) {
    final frame =
        ((enemy.time * enemy.flapRate) + enemy.motionPhase).floor() % 4;
    return switch (enemy.kind) {
      EnemyKind.bat => switch (frame) {
        0 => 9,
        2 => 10,
        _ => enemy.spriteIndex,
      },
      EnemyKind.gargoyle => switch (frame) {
        0 => 11,
        2 => 12,
        _ => enemy.spriteIndex,
      },
      EnemyKind.bird || EnemyKind.slime || EnemyKind.mage => enemy.spriteIndex,
    };
  }

  ({Rect rect, double rotation, double scaleX, double scaleY}) _enemyMotion(
    EnemyModel enemy,
  ) {
    final t = enemy.time;
    final p = enemy.motionPhase;
    final baseRect = enemy.rect;
    final size = enemy.size;

    Rect centered(double lift) => baseRect.shift(Offset(0, lift));

    Rect bottomAnchored(double lift, double scaleY) {
      return baseRect.shift(Offset(0, size * (1 - scaleY) * 0.5 + lift));
    }

    return switch (enemy.kind) {
      EnemyKind.bat => () {
        final bob = math.sin(t * 7 + p) * size * 0.025;
        return (
          rect: centered(bob),
          rotation: math.sin(t * 6 + p) * 0.035,
          scaleX: 1.0,
          scaleY: 1.0,
        );
      }(),
      EnemyKind.bird => (
        rect: baseRect,
        rotation: 0.0,
        scaleX: 1.0,
        scaleY: 1.0,
      ),
      EnemyKind.slime => () {
        final hop = (math.sin(t * 7.4 + p) + 1) * 0.5;
        final lift = -math.pow(hop, 2).toDouble() * size * 0.18;
        final compression = 1 - hop;
        final scaleX = 1 + compression * 0.11 - hop * 0.03;
        final scaleY = 1 - compression * 0.10 + hop * 0.05;
        return (
          rect: bottomAnchored(lift, scaleY),
          rotation: math.sin(t * 5 + p) * 0.025,
          scaleX: scaleX,
          scaleY: scaleY,
        );
      }(),
      EnemyKind.mage => () {
        final hover = math.sin(t * 2.8 + p);
        final pulse = (math.sin(t * 4.2 + p) + 1) * 0.5;
        return (
          rect: centered(hover * size * 0.045),
          rotation: math.sin(t * 2.2 + p) * 0.035,
          scaleX: 1 + pulse * 0.025,
          scaleY: 1 + (1 - pulse) * 0.025,
        );
      }(),
      EnemyKind.gargoyle => () {
        final hover = math.sin(t * 2.4 + p) * size * 0.025;
        return (
          rect: centered(hover),
          rotation: math.sin(t * 3 + p) * 0.025,
          scaleX: 1.0,
          scaleY: 1.0,
        );
      }(),
    };
  }

  void _drawAtlasSprite(
    Canvas canvas,
    ui.Image image,
    int index,
    Rect dst,
    int columns, {
    Paint? paint,
    bool flipX = false,
    double rotation = 0,
    double scaleX = 1,
    double scaleY = 1,
  }) {
    final col = index % columns;
    final row = index ~/ columns;
    final src = Rect.fromLTWH(
      col * enemyCellSize.width,
      row * enemyCellSize.height,
      enemyCellSize.width,
      enemyCellSize.height,
    );
    final spritePaint = paint ?? (Paint()..filterQuality = FilterQuality.high);
    if (!flipX && rotation == 0 && scaleX == 1 && scaleY == 1) {
      canvas.drawImageRect(image, src, dst, spritePaint);
      return;
    }

    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    canvas.scale(flipX ? -scaleX : scaleX, scaleY);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromCenter(
        center: Offset.zero,
        width: dst.width,
        height: dst.height,
      ),
      spritePaint,
    );
    canvas.restore();
  }

  double _projectileRotation(ProjectileModel projectile, double sourceAngle) {
    return math.atan2(projectile.vy, projectile.vx) - sourceAngle;
  }

  void _drawHud(Canvas canvas, Size size) {
    final scoreFontSize = math.max(24.0, size.width * 0.065);
    _drawOutlinedText(
      canvas,
      text: '${score.round()} m',
      fontSize: scoreFontSize,
      center: Offset(size.width / 2, 30 + scoreFontSize / 2),
    );
    _drawKillChip(canvas, size);
  }

  void _drawOutlinedText(
    Canvas canvas, {
    required String text,
    required double fontSize,
    required Offset center,
  }) {
    final baseStyle = TextStyle(
      fontFamily: 'MPLUSRounded1c',
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = fontSize * 0.16
            ..strokeJoin = StrokeJoin.round
            ..color = _UiColors.ink.withValues(alpha: 0.85),
          shadows: const [
            Shadow(offset: Offset(0, 3), blurRadius: 6, color: Colors.black38),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final origin = center - Offset(stroke.width / 2, stroke.height / 2);
    stroke.paint(canvas, origin);

    final fillRect = origin & Size(stroke.width, stroke.height);
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          foreground: Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xffffe2a8)],
            ).createShader(fillRect),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    fill.paint(canvas, origin);
  }

  void _drawKillChip(Canvas canvas, Size size) {
    final fontSize = math.max(14.0, size.width * 0.036);
    final text = TextPainter(
      text: TextSpan(
        text: killChipText,
        style: TextStyle(
          fontFamily: 'MPLUSRounded1c',
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chipWidth = text.width + 26;
    final chipHeight = text.height + 14;
    final chipRect = Rect.fromLTWH(
      size.width - chipWidth - 14,
      36,
      chipWidth,
      chipHeight,
    );
    final rrect = RRect.fromRectAndRadius(
      chipRect,
      Radius.circular(chipHeight / 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = _UiColors.ink.withValues(alpha: 0.45),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _UiColors.gold.withValues(alpha: 0.6),
    );
    text.paint(
      canvas,
      Offset(
        chipRect.left + (chipWidth - text.width) / 2,
        chipRect.top + (chipHeight - text.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant DragonGamePainter oldDelegate) => true;
}

class _SkyBackdrop extends StatelessWidget {
  const _SkyBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/sky.png',
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }
}

class GameImages {
  GameImages({
    required this.sky,
    required this.dragonAtlas,
    required this.enemyAtlas,
  });

  final ui.Image sky;
  final ui.Image dragonAtlas;
  final ui.Image enemyAtlas;

  static Future<GameImages> load() async {
    final sky = await _loadImage('assets/images/sky.png');
    final dragon = await _loadImage('assets/images/dragon_atlas.png');
    final enemy = await _loadImage('assets/images/enemy_atlas_flap.png');
    return GameImages(sky: sky, dragonAtlas: dragon, enemyAtlas: enemy);
  }

  static Future<ui.Image> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class EnemySpec {
  const EnemySpec({
    required this.hp,
    required this.speed,
    required this.size,
    required this.spriteIndex,
  });

  final int hp;
  final double speed;
  final double size;
  final int spriteIndex;

  static EnemySpec forKind(EnemyKind kind, Size world) {
    final short = math.min(world.width, world.height);
    final base = math.max(165.0, short * 0.42);
    final small = (short * 0.13).clamp(44.0, 70.0).toDouble();
    final medium = (short * 0.16).clamp(54.0, 88.0).toDouble();
    final large = (short * 0.20).clamp(70.0, 112.0).toDouble();
    return switch (kind) {
      EnemyKind.bat => EnemySpec(
        hp: 1,
        speed: base * 1.0,
        size: small,
        spriteIndex: 0,
      ),
      EnemyKind.bird => EnemySpec(
        hp: 1,
        speed: base * 1.18,
        size: medium,
        spriteIndex: 1,
      ),
      EnemyKind.slime => EnemySpec(
        hp: 2,
        speed: base * 0.82,
        size: medium,
        spriteIndex: 2,
      ),
      EnemyKind.mage => EnemySpec(
        hp: 2,
        speed: base * 0.72,
        size: large,
        spriteIndex: 3,
      ),
      EnemyKind.gargoyle => EnemySpec(
        hp: 8,
        speed: base * 0.62,
        size: large,
        spriteIndex: 4,
      ),
    };
  }
}

class EnemyModel {
  EnemyModel({
    required this.kind,
    required this.x,
    required this.y,
    required this.baseY,
    required this.size,
    required this.speed,
    required this.hp,
    required this.spriteIndex,
    required this.amplitude,
    required this.phase,
    required this.waveRate,
    required this.motionPhase,
    required this.shootTimer,
  });

  final EnemyKind kind;
  double x;
  double y;
  final double baseY;
  final double size;
  final double speed;
  int hp;
  final int spriteIndex;
  final double amplitude;
  final double phase;
  final double waveRate;
  final double motionPhase;
  double shootTimer;
  double time = 0;
  bool dead = false;

  double get flapRate => switch (kind) {
    EnemyKind.bat => 20,
    EnemyKind.gargoyle => 7,
    EnemyKind.bird || EnemyKind.slime || EnemyKind.mage => 0,
  };

  bool get shouldFlipSprite => switch (kind) {
    EnemyKind.bat || EnemyKind.mage => true,
    EnemyKind.bird || EnemyKind.slime || EnemyKind.gargoyle => false,
  };

  double get radius => size * 0.43;

  Rect get rect =>
      Rect.fromCenter(center: Offset(x, y), width: size, height: size);
}

class ProjectileModel {
  ProjectileModel({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.spriteIndex,
  });

  double x;
  double y;
  final double vx;
  final double vy;
  final double radius;
  final int spriteIndex;
  bool dead = false;

  Rect get rect => Rect.fromCenter(
    center: Offset(x, y),
    width: radius * 2.8,
    height: radius * 2.8,
  );
}

class EffectModel {
  EffectModel({
    required this.x,
    required this.y,
    required this.size,
    required this.spriteIndex,
    required this.duration,
  });

  final double x;
  final double y;
  final double size;
  final int spriteIndex;
  final double duration;
  double age = 0;

  Rect get rect =>
      Rect.fromCenter(center: Offset(x, y), width: size, height: size);
}

class AppSettings {
  const AppSettings({
    required this.playerId,
    required this.playerName,
    required this.volume,
    required this.adsRemoved,
    this.accountProvider,
  });

  static const int maxPlayerNameLength = 14;
  static const int maxPlayerIdLength = 64;
  static const String fallbackPlayerName = 'Dragon';
  static final RegExp _generatedDefaultNamePattern = RegExp(r'^Dragon(\d{8})$');
  static final RegExp _legacyGeneratedDefaultNamePattern = RegExp(
    r'^Player(\d{8})$',
  );
  static final RegExp _playerIdAllowedPattern = RegExp(r'[^a-zA-Z0-9._:-]');

  final String playerId;
  final String playerName;
  final double volume;
  final bool adsRemoved;
  final AccountProvider? accountProvider;

  static AppSettings defaults() {
    return AppSettings(
      playerId: randomPlayerId(),
      playerName: randomDefaultPlayerName(),
      volume: 0.75,
      adsRemoved: false,
    );
  }

  static AppSettings fromPrefs(SharedPreferences prefs) {
    final storedId = prefs.getString('playerId');
    final storedName = prefs.getString('playerName');
    final cleanId = cleanPlayerId(storedId ?? '');
    return AppSettings(
      playerId: cleanId.isEmpty ? randomPlayerId() : cleanId,
      playerName: storedName == null
          ? randomDefaultPlayerName()
          : normalizeGeneratedPlayerName(storedName),
      volume: (prefs.getDouble('volume') ?? 0.75).clamp(0.0, 1.0),
      adsRemoved: prefs.getBool('adsRemoved') ?? false,
      accountProvider: AccountProvider.fromApiValue(
        prefs.getString('accountProvider'),
      ),
    );
  }

  static String randomDefaultPlayerName() {
    final random = math.Random();
    final digits = List.generate(8, (_) => random.nextInt(10)).join();
    return 'Dragon$digits';
  }

  static String randomPlayerId() {
    late final math.Random random;
    try {
      random = math.Random.secure();
    } on UnsupportedError {
      random = math.Random();
    }
    final bytes = List.generate(16, (_) => random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'p$hex';
  }

  static String cleanPlayerId(String value) {
    return value
        .replaceAll(_playerIdAllowedPattern, '')
        .trim()
        .characters
        .take(maxPlayerIdLength)
        .toString();
  }

  static String normalizeGeneratedPlayerName(String value) {
    final clean = cleanName(value);
    final legacyMatch = _legacyGeneratedDefaultNamePattern.firstMatch(clean);
    if (legacyMatch != null) return 'Dragon${legacyMatch.group(1)}';
    return clean;
  }

  static String emptyNameFallback(String currentName) {
    final clean = normalizeGeneratedPlayerName(currentName);
    if (_generatedDefaultNamePattern.hasMatch(clean)) return clean;
    return randomDefaultPlayerName();
  }

  static String cleanName(String value) {
    final withoutTags = value.replaceAll(RegExp(r'<[^>]*>'), '');
    final withoutUrls = withoutTags.replaceAll(RegExp(r'https?://\S+'), '');
    final clean = withoutUrls.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    return clean.characters.take(maxPlayerNameLength).toString();
  }

  static String scoreName(String value) {
    final clean = cleanName(value);
    if (clean.isEmpty) return fallbackPlayerName;
    return clean;
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('playerId', cleanPlayerId(playerId));
    await prefs.setString('playerName', cleanName(playerName));
    await prefs.setDouble('volume', volume);
    await prefs.setBool('adsRemoved', adsRemoved);
    final provider = accountProvider;
    if (provider == null) {
      await prefs.remove('accountProvider');
    } else {
      await prefs.setString('accountProvider', provider.apiValue);
    }
  }

  AppSettings copyWith({
    String? playerId,
    String? playerName,
    double? volume,
    bool? adsRemoved,
    AccountProvider? accountProvider,
    bool clearAccountProvider = false,
  }) {
    return AppSettings(
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      volume: volume ?? this.volume,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      accountProvider: clearAccountProvider
          ? null
          : accountProvider ?? this.accountProvider,
    );
  }
}

class ScoreEntry {
  const ScoreEntry({
    required this.playerId,
    required this.name,
    required this.score,
    required this.kills,
    required this.date,
    required this.version,
    this.runToken,
  });

  final String playerId;
  final String name;
  final int score;
  final int kills;
  final DateTime date;
  final String version;
  final String? runToken;

  Map<String, Object> toJson({bool includeRunToken = true}) {
    final json = <String, Object>{
      'playerId': AppSettings.cleanPlayerId(playerId),
      'name': AppSettings.scoreName(name),
      'score': score,
      'kills': kills,
      'date': date.toIso8601String(),
      'version': version,
    };
    final token = runToken;
    if (includeRunToken && token != null && token.isNotEmpty) {
      json['runToken'] = token;
    }
    return json;
  }

  static ScoreEntry fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      playerId: AppSettings.cleanPlayerId(
        '${json['playerId'] ?? json['player_id'] ?? ''}',
      ),
      name: AppSettings.scoreName('${json['name'] ?? ''}'),
      score: _intFromJson(json['score']),
      kills: _intFromJson(json['kills']),
      date:
          DateTime.tryParse('${json['date'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      version: '${json['version'] ?? _gameVersion}',
      runToken: null,
    );
  }

  static int _intFromJson(Object? value) {
    if (value is num) return value.round();
    if (value is String) return num.tryParse(value)?.round() ?? 0;
    return 0;
  }
}

class ScoreboardData {
  const ScoreboardData({
    required this.onlineScores,
    required this.sourceLabel,
    required this.message,
  });

  final List<ScoreEntry> onlineScores;
  final String sourceLabel;
  final String message;
}

enum AccountProvider {
  google('google', 'Google'),
  apple('apple', 'Apple');

  const AccountProvider(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static AccountProvider? fromApiValue(String? value) {
    if (value == null) return null;
    for (final provider in values) {
      if (provider.apiValue == value) return provider;
    }
    return null;
  }
}

class ProviderCredential {
  const ProviderCredential({
    required this.provider,
    required this.idToken,
    required this.displayName,
  });

  final AccountProvider provider;
  final String idToken;
  final String displayName;
}

class AuthenticatedPlayer {
  const AuthenticatedPlayer({
    required this.provider,
    required this.playerId,
    required this.name,
  });

  final AccountProvider provider;
  final String playerId;
  final String name;

  static AuthenticatedPlayer fromJson(Map<String, dynamic> json) {
    final provider =
        AccountProvider.fromApiValue('${json['provider'] ?? ''}') ??
        AccountProvider.google;
    final playerId = AppSettings.cleanPlayerId('${json['playerId'] ?? ''}');
    final name = AppSettings.scoreName('${json['name'] ?? ''}');
    if (playerId.isEmpty) {
      throw const FormatException('invalid_authenticated_player_response');
    }
    return AuthenticatedPlayer(
      provider: provider,
      playerId: playerId,
      name: name,
    );
  }
}

class AccountSignIn {
  static Future<void>? _googleInit;

  static Future<ProviderCredential> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw UnsupportedError('google_sign_in_unavailable');
    }
    final lightweightAttempt = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    final lightweightAccount = lightweightAttempt == null
        ? null
        : await lightweightAttempt;
    final account =
        lightweightAccount ?? await GoogleSignIn.instance.authenticate();
    return _googleCredentialFromAccount(account);
  }

  static Future<ProviderCredential> signInWithApple() async {
    if (!await SignInWithApple.isAvailable()) {
      throw UnsupportedError('apple_sign_in_unavailable');
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('missing_apple_identity_token');
    }
    final names = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((value) => value.trim().isNotEmpty);
    return ProviderCredential(
      provider: AccountProvider.apple,
      idToken: idToken,
      displayName: names.join(' '),
    );
  }

  static Future<void> signOut(AccountProvider provider) async {
    // Apple にはサインアウトAPIがないため、ローカル状態の破棄のみで完結する。
    if (provider != AccountProvider.google) return;
    await _ensureGoogleInitialized();
    await GoogleSignIn.instance.signOut();
  }

  static Future<void> _ensureGoogleInitialized() {
    final future = _googleInit;
    if (future != null) return future;
    final init = GoogleSignIn.instance
        .initialize(
          clientId: _googleClientId.isEmpty ? null : _googleClientId,
          serverClientId: _googleServerClientId.isEmpty
              ? null
              : _googleServerClientId,
        )
        .catchError((Object error) {
          _googleInit = null;
          throw error;
        });
    _googleInit = init;
    return init;
  }

  static ProviderCredential _googleCredentialFromAccount(
    GoogleSignInAccount account,
  ) {
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('missing_google_id_token');
    }
    return ProviderCredential(
      provider: AccountProvider.google,
      idToken: idToken,
      displayName: account.displayName ?? '',
    );
  }
}

class ScoreStore {
  static const int maxLeaderboardEntries = 10000;

  static List<ScoreEntry> loadLocalScores(SharedPreferences prefs) {
    final text = prefs.getString('scores');
    if (text == null || text.isEmpty) return const [];
    try {
      final value = jsonDecode(text);
      if (value is! List) return const [];
      return _parseScoreEntryList(value).take(20).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ScoreEntry>> addLocalScore(
    SharedPreferences prefs,
    ScoreEntry entry,
  ) async {
    final scores = [...loadLocalScores(prefs), entry]
      ..sort((a, b) => b.score.compareTo(a.score));
    final trimmed = scores.take(20).toList();
    await prefs.setString(
      'scores',
      jsonEncode(
        trimmed.map((score) => score.toJson(includeRunToken: false)).toList(),
      ),
    );
    return trimmed;
  }

  static Future<ScoreboardData> loadScoreboard(
    List<ScoreEntry> local, {
    ScoreboardPeriod period = ScoreboardPeriod.allTime,
    List<ScoreEntry>? cachedOnlineScores,
    required DragonStrings strings,
  }) async {
    final apiUrl = _scoreApiUrl;
    try {
      final online = await _loadOnline(period);
      return ScoreboardData(
        onlineScores: online.take(maxLeaderboardEntries).toList(),
        sourceLabel: apiUrl.isEmpty
            ? strings.scoreboardBundled
            : strings.scoreboardOnline,
        message: apiUrl.isEmpty ? strings.scoreboardMissingApiMessage : '',
      );
    } catch (_) {
      if (cachedOnlineScores != null) {
        return ScoreboardData(
          onlineScores: cachedOnlineScores.take(maxLeaderboardEntries).toList(),
          sourceLabel: strings.scoreboardOnline,
          message: strings.scoreboardCachedOnlineMessage,
        );
      }
      return ScoreboardData(
        onlineScores: local.take(maxLeaderboardEntries).toList(),
        sourceLabel: strings.scoreboardLocal,
        message: strings.scoreboardLocalFallbackMessage,
      );
    }
  }

  static List<ScoreEntry> filterByPeriod(
    List<ScoreEntry> scores,
    ScoreboardPeriod period, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toLocal();
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final filtered = scores.where((score) {
      final scoreDate = score.date.toLocal();
      final scoreDay = DateTime(scoreDate.year, scoreDate.month, scoreDate.day);
      return switch (period) {
        ScoreboardPeriod.today => scoreDay == referenceDay,
        ScoreboardPeriod.week => _isWithinDays(scoreDay, referenceDay, days: 7),
        ScoreboardPeriod.month => _isWithinDays(
          scoreDay,
          referenceDay,
          days: 30,
        ),
        ScoreboardPeriod.allTime => !scoreDay.isAfter(referenceDay),
      };
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    return filtered.take(maxLeaderboardEntries).toList();
  }

  static bool _isWithinDays(
    DateTime scoreDay,
    DateTime referenceDay, {
    required int days,
  }) {
    final firstDay = referenceDay.subtract(Duration(days: days - 1));
    return !scoreDay.isBefore(firstDay) && !scoreDay.isAfter(referenceDay);
  }

  static Future<List<ScoreEntry>> _loadOnline(ScoreboardPeriod period) async {
    final apiUrl = _scoreApiUrl;
    if (apiUrl.isEmpty) {
      return _loadBundled();
    }
    return _loadRemote(_scoreboardUriForPeriod(Uri.parse(apiUrl), period));
  }

  static Future<List<ScoreEntry>> _loadRemote(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('leaderboard http ${response.statusCode}');
    }
    return _parseScores(response.body);
  }

  static Uri _scoreboardUriForPeriod(Uri uri, ScoreboardPeriod period) {
    final query = {...uri.queryParameters, 'period': period.queryValue};
    final range = _periodRange(period);
    if (range != null) {
      query['from'] = range.from.toIso8601String();
      query['to'] = range.to.toIso8601String();
    }
    return uri.replace(queryParameters: query);
  }

  static ({DateTime from, DateTime to})? _periodRange(
    ScoreboardPeriod period, {
    DateTime? now,
  }) {
    if (period == ScoreboardPeriod.allTime) return null;
    final reference = (now ?? DateTime.now()).toLocal();
    final referenceDay = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final days = switch (period) {
      ScoreboardPeriod.today => 1,
      ScoreboardPeriod.week => 7,
      ScoreboardPeriod.month => 30,
      ScoreboardPeriod.allTime => 0,
    };
    final from = referenceDay.subtract(Duration(days: days - 1));
    final to = referenceDay.add(const Duration(days: 1));
    return (from: from.toUtc(), to: to.toUtc());
  }

  static Future<List<ScoreEntry>> _loadBundled() async {
    final text = await rootBundle.loadString('assets/data/leaderboard.json');
    return _parseScores(text);
  }

  static List<ScoreEntry> _parseScores(String text) {
    return _parseScoresFromJson(jsonDecode(text));
  }

  static List<ScoreEntry> _parseScoresFromJson(Object? json) {
    final list = json is Map ? json['scores'] : json;
    if (list is! List) return const [];
    final scores = _parseScoreEntryList(list);
    return scores.take(maxLeaderboardEntries).toList();
  }

  static List<ScoreEntry> _parseScoreEntryList(List<Object?> list) {
    final scores = <ScoreEntry>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        scores.add(ScoreEntry.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed rows so one bad score cannot break startup.
      }
    }
    return scores..sort((a, b) => b.score.compareTo(a.score));
  }

  static Future<String?> startRankedRun(AppSettings settings) async {
    final apiUrl = _scoreApiUrl;
    if (apiUrl.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'action': 'startRun',
              'playerId': AppSettings.cleanPlayerId(settings.playerId),
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return null;
      final token = '${body['runToken'] ?? ''}'.trim();
      return token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  static Future<List<ScoreEntry>?> submitScore(ScoreEntry entry) async {
    final apiUrl = _scoreApiUrl;
    if (apiUrl.isEmpty) return null;
    final token = entry.runToken;
    if (token == null || token.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(entry.toJson()),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('score submit http ${response.statusCode}');
      }
      final scores = _parseScores(response.body);
      return scores.isEmpty ? null : scores;
    } catch (_) {
      return null;
    }
  }

  static Future<AuthenticatedPlayer> authenticateProvider({
    required AppSettings settings,
    required ProviderCredential credential,
  }) async {
    final response = await _postAction({
      'action': 'authenticateProvider',
      'provider': credential.provider.apiValue,
      'idToken': credential.idToken,
      'playerId': AppSettings.cleanPlayerId(settings.playerId),
      'name': AppSettings.scoreName(
        settings.playerName.isEmpty
            ? credential.displayName
            : settings.playerName,
      ),
    });
    final player = response['player'];
    if (player is! Map) {
      throw const FormatException('invalid_authenticated_player_response');
    }
    return AuthenticatedPlayer.fromJson(Map<String, dynamic>.from(player));
  }

  static Future<Map<String, dynamic>> _postAction(
    Map<String, Object> body,
  ) async {
    final apiUrl = _scoreApiUrl;
    if (apiUrl.isEmpty) {
      throw StateError('score_submit_url_not_configured');
    }
    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('invalid_action_response');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        map['ok'] != true) {
      throw StateError('${map['error'] ?? 'action_failed'}');
    }
    return map;
  }
}

class GameAudio {
  static const int _sfxPoolSize = 4;
  // Ogg Vorbis を再生できないプラットフォーム向けの代替ファイル。
  // (just_audio_windows・iOS/macOS の AVFoundation・Safari は Vorbis 非対応)
  static const Map<String, String> _oggFallbackAudioFileOverrides = {
    'enemy_explosion_ultimate_snap_boom_007.ogg':
        'enemy_explosion_ultimate_snap_boom_007.wav',
    'game_bgm_intro.ogg': 'game_bgm_intro.flac',
    'game_bgm_loop.ogg': 'game_bgm_loop.flac',
  };

  @visibleForTesting
  static Map<String, String> get oggFallbackAudioFileOverrides =>
      _oggFallbackAudioFileOverrides;

  final ja.AudioPlayer _music = ja.AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
    useLazyPreparation: false,
  );
  final audio_session.AndroidAudioAttributes _musicAudioAttributes =
      const audio_session.AndroidAudioAttributes(
        contentType: audio_session.AndroidAudioContentType.music,
        usage: audio_session.AndroidAudioUsage.game,
      );
  final audio_session.AudioSessionConfiguration _musicSessionConfiguration =
      const audio_session.AudioSessionConfiguration(
        // iOS: カテゴリ未指定だとネイティブ側が SoloAmbient にフォールバックし、
        // マナースイッチ(消音)や他アプリ音声の割り込みで効果音・BGMが
        // 無音になる。ゲーム音声は playback で常に再生する。
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        androidAudioAttributes: audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          usage: audio_session.AndroidAudioUsage.game,
        ),
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      );
  late final StreamSubscription<ja.PlayerState> _musicStateSubscription;
  late final StreamSubscription<int?> _musicIndexSubscription;
  AppSettings _settings = AppSettings.defaults();
  Future<void> _musicQueue = Future<void>.value();
  final Map<String, _SfxPool> _sfxPools = {};
  final Map<String, _LoopSfx> _loopSfx = {};
  int _musicGeneration = 0;
  String? _requestedMusicIntroFile;
  String? _requestedMusicFile;
  bool _requestedMusicLoops = false;
  bool _musicSourceReady = false;
  bool _appActive = true;
  bool _audioSessionActive = false;
  // 全画面広告の表示中。ライフサイクル由来の再開経路からBGMが
  // 再生されないよう、resumeMusic() が呼ばれるまで保留する。
  bool _musicHeldForAd = false;
  bool _disposed = false;

  GameAudio() {
    unawaited(_configureMusicSession());
    _musicStateSubscription = _music.playerStateStream.listen((state) {
      if (_disposed || !_appActive || _musicHeldForAd) return;
      if (!_requestedMusicLoops || _requestedMusicFile == null) return;
      if (state.processingState == ja.ProcessingState.completed) {
        unawaited(playMusic(_requestedMusicFile!, loop: true));
      }
    });
    _musicIndexSubscription = _music.currentIndexStream.listen((index) {
      if (_disposed || !_appActive) return;
      if (index != 1 || _requestedMusicIntroFile == null) return;
      if (!_requestedMusicLoops || _requestedMusicFile == null) return;
      _requestedMusicIntroFile = null;
      unawaited(_music.setLoopMode(ja.LoopMode.one));
    });
  }

  void applySettings(AppSettings settings) {
    _settings = settings;
    unawaited(
      _enqueueMusic(() async {
        if (_disposed) return;
        await _music.setVolume(_settings.volume * 0.55);
      }),
    );
  }

  Future<void> preloadSfx(Iterable<String> files) async {
    await Future.wait(files.toSet().map(_ensureSfxPool));
  }

  Future<void> preloadLoopSfx(Iterable<String> files) async {
    await Future.wait(
      files.toSet().map((file) async {
        final loop = _ensureLoopSfx(file);
        try {
          await loop.ready;
        } catch (error) {
          _logAudioError('load $file', error);
        }
      }),
    );
  }

  static bool get _playsOggNatively =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String _audioAssetPath(String file) {
    final platformFile = _playsOggNatively
        ? file
        : _oggFallbackAudioFileOverrides[file] ?? file;
    return 'assets/audio/$platformFile';
  }

  Future<void> playMusic(String file, {required bool loop}) {
    if (_disposed) return Future<void>.value();
    _musicHeldForAd = false;
    _requestedMusicIntroFile = null;
    _requestedMusicFile = file;
    _requestedMusicLoops = loop;
    final generation = ++_musicGeneration;
    return _enqueueMusic(() async {
      if (_disposed || generation != _musicGeneration) return;
      await _haltMusic();
      if (_disposed || generation != _musicGeneration || !_appActive) {
        return;
      }
      await _configureMusicSession();
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _setAndroidAudioAttributes(_music);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setAudioSource(
        createGameAudioSource(_audioAssetPath(file)),
        preload: true,
      );
      _musicSourceReady = true;
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setVolume(_settings.volume * 0.55);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.seek(Duration.zero);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.play();
    });
  }

  Future<void> playMusicIntroThenLoop({
    required String introFile,
    required String loopFile,
  }) {
    if (_disposed) return Future<void>.value();
    _musicHeldForAd = false;
    _requestedMusicIntroFile = introFile;
    _requestedMusicFile = loopFile;
    _requestedMusicLoops = true;
    final generation = ++_musicGeneration;
    return _enqueueMusic(() async {
      if (_disposed || generation != _musicGeneration) return;
      await _haltMusic();
      if (_disposed || generation != _musicGeneration || !_appActive) {
        return;
      }
      await _configureMusicSession();
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _setAndroidAudioAttributes(_music);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setLoopMode(ja.LoopMode.off);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setAudioSources(
        [
          createGameAudioSource(_audioAssetPath(introFile)),
          createGameAudioSource(_audioAssetPath(loopFile)),
        ],
        preload: true,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      _musicSourceReady = true;
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.setVolume(_settings.volume * 0.55);
      if (_disposed || generation != _musicGeneration || !_appActive) return;
      await _music.play();
    });
  }

  Future<void> stopMusic() {
    if (_disposed) return Future<void>.value();
    _requestedMusicIntroFile = null;
    _requestedMusicFile = null;
    _requestedMusicLoops = false;
    _musicGeneration++;
    final generation = _musicGeneration;
    return _enqueueMusic(() async {
      if (_disposed || generation != _musicGeneration) return;
      await _haltMusic();
    });
  }

  Future<void> _enqueueMusic(Future<void> Function() operation) {
    final next = _musicQueue.then((_) => operation()).catchError((
      Object error,
    ) {
      _logAudioError('music operation', error);
    });
    _musicQueue = next;
    return next;
  }

  Future<void> _configureMusicSession() async {
    try {
      final session = await audio_session.AudioSession.instance;
      await session.configure(_musicSessionConfiguration);
    } on MissingPluginException {
      // Desktop platforms do not provide audio_session; just_audio can still play.
    } catch (_) {}
  }

  Future<void> _setAndroidAudioAttributes(ja.AudioPlayer player) async {
    try {
      await player.setAndroidAudioAttributes(_musicAudioAttributes);
    } catch (_) {}
  }

  Future<void> _activateAudioSession() async {
    if (_audioSessionActive) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.configure(_musicSessionConfiguration);
      _audioSessionActive = await session.setActive(true);
    } on MissingPluginException {
      // Desktop platforms do not provide audio_session; just_audio can still play.
      _audioSessionActive = true;
    } catch (error) {
      _logAudioError('activate session', error);
    }
  }

  Future<void> setAppActive(bool active) {
    if (_disposed) return Future<void>.value();
    if (active == _appActive) return Future<void>.value();
    _appActive = active;
    if (!active) {
      // ループSFXはゲーム側のtickerが止まると止められないため、ここで止める。
      for (final file in _loopSfx.keys.toList()) {
        unawaited(stopLoopSfx(file));
      }
      final generation = _musicGeneration;
      unawaited(_pauseMusicForBackground(generation));
      return _enqueueMusic(() async {
        if (_disposed || generation != _musicGeneration || _appActive) return;
        await _pauseMusicForBackground(generation);
      });
    }

    if (_musicHeldForAd) {
      // 広告表示中に 'resumed' 相当のイベントが来てもBGMは再開しない。
      // 広告が閉じたときの resumeMusic() が再開を担う。
      return Future<void>.value();
    }
    final file = _requestedMusicFile;
    if (file == null) {
      return Future<void>.value();
    }
    if (!_musicSourceReady) {
      final introFile = _requestedMusicIntroFile;
      if (introFile != null && _requestedMusicLoops) {
        return playMusicIntroThenLoop(introFile: introFile, loopFile: file);
      }
      return playMusic(file, loop: _requestedMusicLoops);
    }
    return _resumeMusicAfterBackground();
  }

  Future<void> _pauseMusicForBackground(int generation) async {
    if (_disposed || generation != _musicGeneration) return;
    try {
      await _music.pause();
    } catch (_) {}
    if (_disposed || generation != _musicGeneration || _appActive) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    _audioSessionActive = false;
  }

  Future<void> pauseMusic() {
    if (_disposed) return Future<void>.value();
    _musicHeldForAd = true;
    // キューに処理が滞留していても確実に止まるよう、即時にも停止する。
    unawaited(
      _music.pause().catchError((Object error) {
        _logAudioError('pause music', error);
      }),
    );
    final generation = _musicGeneration;
    return _enqueueMusic(() async {
      if (_disposed || generation != _musicGeneration || !_musicHeldForAd) {
        return;
      }
      try {
        await _music.pause();
      } catch (_) {}
    });
  }

  Future<void> resumeMusic() {
    if (_disposed) return Future<void>.value();
    _musicHeldForAd = false;
    return _resumeMusicAfterBackground();
  }

  Future<void> _resumeMusicAfterBackground() {
    return _enqueueMusic(() async {
      if (_disposed || !_appActive || _musicHeldForAd || !_musicSourceReady) {
        return;
      }
      await _activateAudioSession();
      if (_disposed || !_appActive || _musicHeldForAd) return;
      await _music.setVolume(_settings.volume * 0.55);
      if (_disposed || !_appActive || _musicHeldForAd) return;
      await _music.play();
    });
  }

  Future<void> playSfx(String file, {double volumeScale = 1}) {
    if (_disposed || !_appActive) return Future<void>.value();
    final volume = (_settings.volume * volumeScale).clamp(0.0, 1.0).toDouble();
    if (volume <= 0) return Future<void>.value();
    return _playSfx(file, volume);
  }

  Future<void> _playSfx(String file, double volume) async {
    final pool = await _ensureSfxPool(file);
    if (pool == null || _disposed || !_appActive) return;
    try {
      await _activateAudioSession();
      if (_disposed || !_appActive) return;
      final player = pool.nextPlayer();
      if (player.volume != volume) {
        await player.setVolume(volume);
      }
      if (player.playing) {
        await player.pause();
      }
      await player.seek(Duration.zero);
      if (_disposed || !_appActive) return;
      unawaited(
        player.play().catchError((Object error) {
          _logAudioError('play $file', error);
        }),
      );
    } catch (error) {
      _logAudioError('play $file', error);
    }
  }

  Future<_SfxPool?> _ensureSfxPool(String file) async {
    if (_disposed) return null;
    final existing = _sfxPools[file];
    final pool = existing ?? _createSfxPool(file);
    if (existing == null) {
      _sfxPools[file] = pool;
    }
    try {
      await pool.ready;
      return pool;
    } catch (error) {
      _logAudioError('load $file', error);
      if (identical(_sfxPools[file], pool)) {
        _sfxPools.remove(file);
      }
      unawaited(pool.dispose());
      return null;
    }
  }

  // 連射中に鳴らし続けるループSFX。単発SFXと違い、start/stop で
  // 再生状態を切り替えるだけなので発射ごとの再始動レイテンシが出ない。
  Future<void> startLoopSfx(String file, {double volumeScale = 1}) {
    if (_disposed || !_appActive) return Future<void>.value();
    final volume = (_settings.volume * volumeScale).clamp(0.0, 1.0).toDouble();
    if (volume <= 0) return stopLoopSfx(file);
    final loop = _ensureLoopSfx(file);
    loop.wanted = true;
    return loop.enqueue(() async {
      try {
        await loop.ready;
      } catch (error) {
        _logAudioError('load $file', error);
        if (identical(_loopSfx[file], loop)) {
          _loopSfx.remove(file);
        }
        unawaited(loop.dispose());
        return;
      }
      if (_disposed || !_appActive || !loop.wanted) return;
      try {
        await _activateAudioSession();
        if (_disposed || !_appActive || !loop.wanted) return;
        if (loop.player.volume != volume) {
          await loop.player.setVolume(volume);
        }
        if (_disposed || !_appActive || !loop.wanted) return;
        if (loop.player.playing) return;
        await loop.player.seek(Duration.zero);
        if (_disposed || !_appActive || !loop.wanted) return;
        unawaited(
          loop.player.play().catchError((Object error) {
            _logAudioError('play $file', error);
          }),
        );
      } catch (error) {
        _logAudioError('play $file', error);
      }
    });
  }

  Future<void> stopLoopSfx(String file) {
    final loop = _loopSfx[file];
    if (loop == null) return Future<void>.value();
    loop.wanted = false;
    return loop.enqueue(() async {
      if (loop.wanted) return;
      try {
        await loop.ready;
      } catch (_) {
        return;
      }
      try {
        await loop.player.pause();
      } catch (error) {
        _logAudioError('stop $file', error);
      }
    });
  }

  _LoopSfx _ensureLoopSfx(String file) {
    return _loopSfx.putIfAbsent(file, () {
      final player = ja.AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
        useLazyPreparation: false,
      );
      final ready = () async {
        await _setAndroidAudioAttributes(player);
        await player.setLoopMode(ja.LoopMode.one);
        await player.setAudioSource(
          createGameAudioSource(_audioAssetPath(file)),
          preload: true,
        );
      }();
      return _LoopSfx(player: player, ready: ready);
    });
  }

  _SfxPool _createSfxPool(String file) {
    final players = List.generate(
      _sfxPoolSize,
      (_) => ja.AudioPlayer(
        handleInterruptions: false,
        androidApplyAudioAttributes: false,
        useLazyPreparation: false,
      ),
    );
    final ready = () async {
      for (final player in players) {
        await _setAndroidAudioAttributes(player);
        await player.setLoopMode(ja.LoopMode.off);
        await player.setAudioSource(
          createGameAudioSource(_audioAssetPath(file)),
          preload: true,
        );
      }
    }();
    return _SfxPool(players: players, ready: ready);
  }

  void _logAudioError(String action, Object error) {
    if (kDebugMode) {
      debugPrint('Audio $action failed: $error');
    }
  }

  Future<void> _haltMusic({bool deactivateSession = false}) {
    return _haltMusicNow(
      _musicGeneration,
      deactivateSession: deactivateSession,
    );
  }

  Future<void> _haltMusicNow(
    int generation, {
    bool deactivateSession = false,
  }) async {
    if (_disposed || generation != _musicGeneration) return;
    try {
      await _music.setVolume(0);
    } catch (_) {}
    if (_disposed || generation != _musicGeneration) return;
    try {
      await _music.pause();
    } catch (_) {}
    if (_disposed || generation != _musicGeneration) return;
    try {
      await _music.stop();
    } catch (_) {}
    _musicSourceReady = false;
    if (_disposed || generation != _musicGeneration) return;
    if (!deactivateSession) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    _audioSessionActive = false;
  }

  void dispose() {
    _disposed = true;
    _musicGeneration++;
    unawaited(_musicStateSubscription.cancel());
    unawaited(_musicIndexSubscription.cancel());
    unawaited(_haltMusic(deactivateSession: true).whenComplete(_music.dispose));
    for (final pool in _sfxPools.values) {
      unawaited(pool.dispose());
    }
    for (final loop in _loopSfx.values) {
      unawaited(loop.dispose());
    }
  }
}

class _LoopSfx {
  _LoopSfx({required this.player, required this.ready});

  final ja.AudioPlayer player;
  final Future<void> ready;
  // 直近の要求が「再生中であるべき」かどうか。start/stop の非同期処理が
  // 交錯しても最後の要求が勝つよう、キュー内の各処理がこれを確認する。
  bool wanted = false;
  Future<void> _queue = Future<void>.value();

  Future<void> enqueue(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> dispose() async {
    try {
      await ready;
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
  }
}

class _SfxPool {
  _SfxPool({required this.players, required this.ready});

  final List<ja.AudioPlayer> players;
  final Future<void> ready;
  int _cursor = 0;

  ja.AudioPlayer nextPlayer() {
    final player = players[_cursor];
    _cursor = (_cursor + 1) % players.length;
    return player;
  }

  Future<void> dispose() async {
    try {
      await ready;
    } catch (_) {}
    await Future.wait(
      players.map((player) async {
        try {
          await player.dispose();
        } catch (_) {}
      }),
    );
  }
}
