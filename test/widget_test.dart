import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attack_of_the_dragon/audio_cache.dart';
import 'package:attack_of_the_dragon/main.dart';

void main() {
  testWidgets('loads referenced audio assets', (tester) async {
    const files = [
      'game_bgm_intro.ogg',
      'game_bgm_loop.ogg',
      'dragon_fire_flame_pip.wav',
      'enemy_explosion_ultimate_snap_boom_007.ogg',
    ];

    for (final file in files) {
      final data = await rootBundle.load('assets/audio/$file');

      expect(data.lengthInBytes, greaterThan(1000), reason: file);
    }
  });

  testWidgets('loads ogg fallback audio assets', (tester) async {
    for (final entry in GameAudio.oggFallbackAudioFileOverrides.entries) {
      final data = await rootBundle.load('assets/audio/${entry.value}');

      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '${entry.key} -> ${entry.value}',
      );
    }
  });

  test('repairs zero byte just_audio asset cache files on Windows', () async {
    final file = File(
      '${Directory.systemTemp.path}'
      '${Platform.pathSeparator}just_audio_cache'
      '${Platform.pathSeparator}codex_test_zero_audio.tmp',
    );
    await file.create(recursive: true);

    await repairJustAudioAssetCache();

    if (Platform.isWindows) {
      expect(file.existsSync(), isFalse);
    } else {
      expect(file.existsSync(), isTrue);
      await file.delete();
    }
  });

  test('default player name is Dragon plus eight digits', () {
    final name = AppSettings.randomDefaultPlayerName();

    expect(name, matches(RegExp(r'^Dragon\d{8}$')));
    expect(name.length, AppSettings.maxPlayerNameLength);
  });

  test('default player id is stable identifier shaped', () {
    final id = AppSettings.randomPlayerId();

    expect(id, matches(RegExp(r'^p[0-9a-f]{32}$')));
    expect(id.length, lessThanOrEqualTo(AppSettings.maxPlayerIdLength));
  });

  test('cleanName allows an empty editing value', () {
    expect(AppSettings.cleanName(''), '');
    expect(AppSettings.scoreName(''), AppSettings.fallbackPlayerName);
  });

  test('emptyNameFallback keeps or creates a generated player name', () {
    expect(AppSettings.emptyNameFallback('Dragon12345678'), 'Dragon12345678');
    expect(AppSettings.emptyNameFallback('Player12345678'), 'Dragon12345678');

    final fallback = AppSettings.emptyNameFallback('CustomName');
    expect(fallback, matches(RegExp(r'^Dragon\d{8}$')));
    expect(fallback.length, AppSettings.maxPlayerNameLength);
  });

  test('fromPrefs migrates legacy generated player names', () async {
    SharedPreferences.setMockInitialValues({
      'playerName': 'Player87654321',
      'volume': 0.7,
    });

    final prefs = await SharedPreferences.getInstance();

    expect(AppSettings.fromPrefs(prefs).playerName, 'Dragon87654321');
  });

  test('fromPrefs keeps stored player id or creates one', () async {
    SharedPreferences.setMockInitialValues({
      'playerId': 'player:abc_123',
      'playerName': 'Dragon12345678',
      'volume': 0.7,
    });

    var prefs = await SharedPreferences.getInstance();

    expect(AppSettings.fromPrefs(prefs).playerId, 'player:abc_123');

    SharedPreferences.setMockInitialValues({
      'playerName': 'Dragon12345678',
      'volume': 0.7,
    });

    prefs = await SharedPreferences.getInstance();

    expect(
      AppSettings.fromPrefs(prefs).playerId,
      matches(RegExp(r'^p[0-9a-f]{32}$')),
    );
  });

  test('fromPrefs restores linked account provider', () async {
    SharedPreferences.setMockInitialValues({
      'playerId': 'player:abc_123',
      'playerName': 'Dragon12345678',
      'volume': 0.7,
      'accountProvider': 'google',
    });

    final prefs = await SharedPreferences.getInstance();

    expect(
      AppSettings.fromPrefs(prefs).accountProvider,
      AccountProvider.google,
    );
  });

  test('fromPrefs restores ad removal purchase state', () async {
    SharedPreferences.setMockInitialValues({
      'playerId': 'player:abc_123',
      'playerName': 'Dragon12345678',
      'volume': 0.7,
      'adsRemoved': true,
    });

    final prefs = await SharedPreferences.getInstance();

    expect(AppSettings.fromPrefs(prefs).adsRemoved, isTrue);
  });

  test('authenticated player response parses provider account payload', () {
    final player = AuthenticatedPlayer.fromJson({
      'provider': 'apple',
      'playerId': 'p0123456789abcdef',
      'name': 'Hinoko',
    });

    expect(player.provider, AccountProvider.apple);
    expect(player.playerId, 'p0123456789abcdef');
    expect(player.name, 'Hinoko');
  });

  test('loadLocalScores returns empty when stored JSON is corrupt', () async {
    SharedPreferences.setMockInitialValues({'scores': 'not-json'});

    final prefs = await SharedPreferences.getInstance();

    expect(ScoreStore.loadLocalScores(prefs), isEmpty);
  });

  test('loadLocalScores tolerates malformed score fields', () async {
    SharedPreferences.setMockInitialValues({
      'scores': jsonEncode([
        {
          'playerId': 'test-player',
          'name': 'BadScore',
          'score': {'unexpected': true},
          'kills': 'not-a-number',
          'date': '2026-07-02T00:00:00.000Z',
          'version': 'test',
        },
      ]),
    });

    final prefs = await SharedPreferences.getInstance();
    final scores = ScoreStore.loadLocalScores(prefs);

    expect(scores, hasLength(1));
    expect(scores.single.score, 0);
    expect(scores.single.kills, 0);
  });

  test('android release manifest declares internet permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.INTERNET'));
  });

  test('filterByPeriod applies scoreboard date ranges', () {
    final now = DateTime(2026, 7, 2, 12);
    final scores = [
      ScoreEntry(
        playerId: 'test-player',
        name: 'today',
        score: 10,
        kills: 1,
        date: DateTime(2026, 7, 2, 1),
        version: 'test',
      ),
      ScoreEntry(
        playerId: 'test-player',
        name: 'week',
        score: 40,
        kills: 1,
        date: DateTime(2026, 6, 28),
        version: 'test',
      ),
      ScoreEntry(
        playerId: 'test-player',
        name: 'month',
        score: 30,
        kills: 1,
        date: DateTime(2026, 6, 15),
        version: 'test',
      ),
      ScoreEntry(
        playerId: 'test-player',
        name: 'old',
        score: 100,
        kills: 1,
        date: DateTime(2026, 5, 1),
        version: 'test',
      ),
      ScoreEntry(
        playerId: 'test-player',
        name: 'future',
        score: 200,
        kills: 1,
        date: DateTime(2026, 7, 3),
        version: 'test',
      ),
    ];

    List<String> namesFor(ScoreboardPeriod period) {
      return ScoreStore.filterByPeriod(
        scores,
        period,
        now: now,
      ).map((score) => score.name).toList();
    }

    expect(namesFor(ScoreboardPeriod.today), ['today']);
    expect(namesFor(ScoreboardPeriod.week), ['week', 'today']);
    expect(namesFor(ScoreboardPeriod.month), ['week', 'month', 'today']);
    expect(namesFor(ScoreboardPeriod.allTime), [
      'old',
      'week',
      'month',
      'today',
    ]);
  });

  testWidgets('shows title menu actions', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(540, 960)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DragonApp());
    await tester.pumpAndSettle();

    expect(find.text('スタート'), findsOneWidget);
    expect(find.text('設定'), findsOneWidget);
    expect(find.text('スコアボード'), findsOneWidget);
  });

  testWidgets('pause button pauses and resumes gameplay', (
    WidgetTester tester,
  ) async {
    final audio = GameAudio();
    addTearDown(audio.dispose);
    final images = (await tester.runAsync<GameImages>(() async {
      return GameImages(
        sky: await createTestImage(width: 16, height: 16, cache: false),
        dragonAtlas: await createTestImage(
          width: 1536,
          height: 192,
          cache: false,
        ),
        enemyAtlas: await createTestImage(
          width: 768,
          height: 768,
          cache: false,
        ),
      );
    }))!;
    tester.view
      ..physicalSize = const Size(540, 960)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          settings: AppSettings.defaults(),
          bestScore: 0,
          audio: audio,
          adMob: AdMobService(),
          onRankedRunStart: () async => null,
          onScore: (_) async {},
          onTitle: () {},
          onScoreboard: () {},
          images: Future.value(images),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(270, 480));
    await tester.pump();

    expect(find.byTooltip('一時停止'), findsOneWidget);

    await tester.tap(find.byTooltip('一時停止'));
    await tester.pump();

    expect(find.text('一時停止'), findsOneWidget);
    expect(find.text('再開'), findsWidgets);
    expect(find.text('リトライ'), findsNothing);
    expect(find.text('タイトルへ戻る'), findsNothing);

    await tester.tap(find.widgetWithText(InkWell, '再開'));
    await tester.pump();

    expect(find.text('一時停止'), findsNothing);
    expect(find.byTooltip('一時停止'), findsOneWidget);
  });

  testWidgets('uses generated player name when settings name is cleared', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      SharedPreferences.setMockInitialValues({
        'playerName': 'Dragon12345678',
        'volume': 0.7,
      });
      tester.view
        ..physicalSize = const Size(540, 960)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const DragonApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();

      expect(find.text('引き継ぎコードを発行'), findsNothing);
      expect(find.text('コードで復元'), findsNothing);
      expect(find.text('Googleでログイン'), findsOneWidget);
      expect(find.text('Appleでログイン'), findsNothing);

      final nameField = find.byType(TextField);
      expect(
        tester.widget<TextField>(nameField).decoration?.hintText,
        'Dragon12345678',
      );

      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      final clearedField = tester.widget<TextField>(nameField);
      expect(clearedField.controller?.text, '');
      expect(clearedField.decoration?.hintText, 'Dragon12345678');

      await tester.tap(find.text('タイトルへ戻る'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('playerName'), 'Dragon12345678');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('settings shows Apple login on iOS only', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final audio = GameAudio();
      addTearDown(audio.dispose);
      tester.view
        ..physicalSize = const Size(540, 960)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            settings: AppSettings.defaults(),
            audio: audio,
            adRemoval: AdRemovalPurchaseService(),
            onChanged: (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Googleでログイン'), findsNothing);
      expect(find.text('Appleでログイン'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('settings includes release credits', (WidgetTester tester) async {
    final audio = GameAudio();
    addTearDown(audio.dispose);
    tester.view
      ..physicalSize = const Size(540, 960)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: AppSettings.defaults(),
          audio: audio,
          adRemoval: AdRemovalPurchaseService(),
          onChanged: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credits'), findsOneWidget);
    expect(
      find.text('Music: YouFulca (https://youfulca.com/)'),
      findsOneWidget,
    );
    expect(
      find.text('Font: M PLUS Rounded 1c (SIL Open Font License 1.1)'),
      findsOneWidget,
    );
    expect(
      find.text('SFX: The Ultimate 2017 16 bit Mini pack (CC0)'),
      findsOneWidget,
    );
  });

  testWidgets('settings marks ad removal purchase state', (
    WidgetTester tester,
  ) async {
    final audio = GameAudio();
    addTearDown(audio.dispose);
    tester.view
      ..physicalSize = const Size(540, 960)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          settings: AppSettings.defaults().copyWith(adsRemoved: true),
          audio: audio,
          adRemoval: AdRemovalPurchaseService(),
          onChanged: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('広告削除'), findsOneWidget);
    expect(find.text('広告削除済み'), findsWidgets);
  });

  testWidgets('settings marks Google login state', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final audio = GameAudio();
      addTearDown(audio.dispose);
      tester.view
        ..physicalSize = const Size(540, 960)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            settings: AppSettings.defaults().copyWith(
              accountProvider: AccountProvider.google,
            ),
            audio: audio,
            adRemoval: AdRemovalPurchaseService(),
            onChanged: (_) {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Googleでログイン済み'), findsOneWidget);
      expect(find.text('Googleアカウントを変更'), findsOneWidget);
      expect(find.text('Googleでログイン'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('scoreboard exposes source and period selectors', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(540, 960)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const DragonApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スコアボード'));
    await tester.pumpAndSettle();

    expect(find.text('オンライン'), findsOneWidget);
    expect(find.text('ローカル'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('週間'), findsOneWidget);
    expect(find.text('月間'), findsOneWidget);
    expect(find.text('全期間'), findsOneWidget);

    await tester.tap(find.text('ローカル'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();

    expect(find.text('ローカル / 今日'), findsOneWidget);

    await tester.tap(find.text('タイトルへ戻る'));
    await tester.pumpAndSettle();

    expect(find.text('スタート'), findsOneWidget);
  });

  testWidgets('local scoreboard rows show recorded datetime instead of name', (
    WidgetTester tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final audio = GameAudio();
    addTearDown(audio.dispose);
    final localScore = ScoreEntry(
      playerId: 'test-player',
      name: 'Dragon12345678',
      score: 1234,
      kills: 5,
      date: DateTime(2026, 7, 2, 9, 5),
      version: 'test',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ScoreboardScreen(
          localScores: [localScore],
          onlineScores: const [],
          audio: audio,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ローカル'));
    await tester.pumpAndSettle();

    final dateTimeText = find.text('2026/07/02 09:05');
    expect(dateTimeText, findsOneWidget);
    expect(
      find.ancestor(of: dateTimeText, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(dateTimeText).overflow,
      isNot(TextOverflow.ellipsis),
    );
    expect(find.text('Dragon12345678'), findsNothing);
    expect(find.text('撃破 5'), findsOneWidget);
  });

  testWidgets('scoreboard can return to result context', (
    WidgetTester tester,
  ) async {
    final audio = GameAudio();
    addTearDown(audio.dispose);
    var returnedToResult = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ScoreboardScreen(
          localScores: const [],
          onlineScores: const [],
          audio: audio,
          backLabel: 'リザルトへ戻る',
          onBack: () {
            returnedToResult = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('リザルトへ戻る'), findsOneWidget);

    await tester.tap(find.text('リザルトへ戻る'));
    await tester.pump();

    expect(returnedToResult, isTrue);
  });
}
