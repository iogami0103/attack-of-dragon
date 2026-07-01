import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shingeki_dragon/main.dart';

void main() {
  test('default player name is Dragon plus eight digits', () {
    final name = AppSettings.randomDefaultPlayerName();

    expect(name, matches(RegExp(r'^Dragon\d{8}$')));
    expect(name.length, AppSettings.maxPlayerNameLength);
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
        name: 'today',
        score: 10,
        kills: 1,
        date: DateTime(2026, 7, 2, 1),
        version: 'test',
      ),
      ScoreEntry(
        name: 'week',
        score: 40,
        kills: 1,
        date: DateTime(2026, 6, 28),
        version: 'test',
      ),
      ScoreEntry(
        name: 'month',
        score: 30,
        kills: 1,
        date: DateTime(2026, 6, 15),
        version: 'test',
      ),
      ScoreEntry(
        name: 'old',
        score: 100,
        kills: 1,
        date: DateTime(2026, 5, 1),
        version: 'test',
      ),
      ScoreEntry(
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

  testWidgets('uses generated player name when settings name is cleared', (
    WidgetTester tester,
  ) async {
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
  });
}
