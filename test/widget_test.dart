import 'dart:ui';

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
}
