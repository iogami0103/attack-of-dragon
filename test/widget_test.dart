import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shingeki_dragon/main.dart';

void main() {
  test('default player name is Player plus eight digits', () {
    final name = AppSettings.randomDefaultPlayerName();

    expect(name, matches(RegExp(r'^Player\d{8}$')));
    expect(name.length, AppSettings.maxPlayerNameLength);
  });

  test('cleanName allows an empty editing value', () {
    expect(AppSettings.cleanName(''), '');
    expect(AppSettings.scoreName(''), AppSettings.fallbackPlayerName);
  });

  test('emptyNameFallback keeps or creates a generated player name', () {
    expect(AppSettings.emptyNameFallback('Player12345678'), 'Player12345678');

    final fallback = AppSettings.emptyNameFallback('CustomName');
    expect(fallback, matches(RegExp(r'^Player\d{8}$')));
    expect(fallback.length, AppSettings.maxPlayerNameLength);
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
      'playerName': 'Player12345678',
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
      'Player12345678',
    );

    await tester.enterText(nameField, '');
    await tester.pumpAndSettle();

    final clearedField = tester.widget<TextField>(nameField);
    expect(clearedField.controller?.text, '');
    expect(clearedField.decoration?.hintText, 'Player12345678');

    await tester.tap(find.text('タイトルへ戻る'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('playerName'), 'Player12345678');
  });
}
