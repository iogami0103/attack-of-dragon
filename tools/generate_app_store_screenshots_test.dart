import 'dart:io';

import 'package:attack_of_the_dragon/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _outputRoot = String.fromEnvironment(
  'APP_STORE_SCREENSHOT_OUTPUT',
  defaultValue: 'artifacts/app-store-submission-2026-07-05/screenshots-src',
);
const _flutterRoot = String.fromEnvironment('FLUTTER_ROOT');

const _devices = [
  _ScreenshotDevice(
    name: 'iphone-6-9',
    logicalSize: Size(440, 956),
    pixelRatio: 3,
  ),
  _ScreenshotDevice(
    name: 'ipad-13',
    logicalSize: Size(1032, 1376),
    pixelRatio: 2,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  for (final device in _devices) {
    group(device.name, () {
      testWidgets('title', (tester) async {
        final audio = GameAudio();
        addTearDown(audio.dispose);
        await _capture(
          tester: tester,
          device: device,
          fileName: '01-title.png',
          child: TitleScreen(
            audio: audio,
            onStart: () {},
            onSettings: () {},
            onScoreboard: () {},
          ),
        );
      });

      testWidgets('gameplay', (tester) async {
        await _capture(
          tester: tester,
          device: device,
          fileName: '02-gameplay.png',
          child: const _GameplayPoster(),
        );
      });

      testWidgets('scoreboard', (tester) async {
        final audio = GameAudio();
        addTearDown(audio.dispose);
        final now = DateTime(2026, 7, 5, 12);
        final scores = [
          ScoreEntry(
            playerId: 'p1',
            name: 'Dragon77777777',
            score: 12840,
            kills: 42,
            date: now,
            version: '1.0.0',
          ),
          ScoreEntry(
            playerId: 'p2',
            name: 'Hinoko',
            score: 11220,
            kills: 36,
            date: now.subtract(const Duration(hours: 3)),
            version: '1.0.0',
          ),
          ScoreEntry(
            playerId: 'p3',
            name: 'SkyFlame',
            score: 9870,
            kills: 31,
            date: now.subtract(const Duration(days: 1)),
            version: '1.0.0',
          ),
          ScoreEntry(
            playerId: 'p4',
            name: 'Aodragon',
            score: 8650,
            kills: 28,
            date: now.subtract(const Duration(days: 2)),
            version: '1.0.0',
          ),
        ];
        await _capture(
          tester: tester,
          device: device,
          fileName: '03-scoreboard.png',
          child: ScoreboardScreen(
            localScores: scores,
            onlineScores: scores,
            audio: audio,
            onBack: () {},
          ),
        );
      });

      testWidgets('settings and purchase', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          final audio = GameAudio();
          addTearDown(audio.dispose);
          await _capture(
            tester: tester,
            device: device,
            fileName: '04-settings-iap.png',
            child: SettingsScreen(
              settings: AppSettings.defaults().copyWith(adsRemoved: true),
              audio: audio,
              adRemoval: AdRemovalPurchaseService(),
              onChanged: (_) {},
              onBack: () {},
            ),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    });
  }
}

class _GameplayPoster extends StatelessWidget {
  const _GameplayPoster();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/sky.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          CustomPaint(
            painter: const _GameplayPosterPainter(),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

class _GameplayPosterPainter extends CustomPainter {
  const _GameplayPosterPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.14);
    canvas.drawRect(Offset.zero & size, overlay);

    _drawHud(canvas, size);
    _drawDragon(canvas, size);
    _drawEnemy(canvas, size, const Offset(0.68, 0.24), 0);
    _drawEnemy(canvas, size, const Offset(0.78, 0.48), 1);
    _drawEnemy(canvas, size, const Offset(0.62, 0.68), 2);
    _drawProjectiles(canvas, size);
  }

  void _drawHud(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 24, mathMin(240, size.width - 96), 58),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = const Color(0xfffff6e8).withValues(alpha: 0.88),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffffb13b).withValues(alpha: 0.82),
    );
    _drawText(
      canvas,
      'SCORE 12840',
      Offset(panel.left + 18, panel.top + 9),
      21,
      const Color(0xff2f1a13),
      FontWeight.w900,
    );
    _drawText(
      canvas,
      '撃破 42',
      Offset(panel.left + 18, panel.top + 34),
      15,
      const Color(0xffa8421d),
      FontWeight.w800,
    );

    final pauseCenter = Offset(size.width - 48, 52);
    canvas.drawCircle(
      pauseCenter,
      26,
      Paint()..color = const Color(0xfffff6e8).withValues(alpha: 0.90),
    );
    canvas.drawCircle(
      pauseCenter,
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffffb13b).withValues(alpha: 0.82),
    );
    final pausePaint = Paint()..color = const Color(0xffa8421d);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pauseCenter.translate(-5, 0),
          width: 5,
          height: 22,
        ),
        const Radius.circular(2),
      ),
      pausePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pauseCenter.translate(5, 0),
          width: 5,
          height: 22,
        ),
        const Radius.circular(2),
      ),
      pausePaint,
    );
  }

  void _drawDragon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.31, size.height * 0.50);
    final scale = size.width / 440;
    final bodyPaint = Paint()..color = const Color(0xffd64b28);
    final wingPaint = Paint()..color = const Color(0xff9b2f1e);
    final bellyPaint = Paint()..color = const Color(0xffffc15a);

    final leftWing = Path()
      ..moveTo(center.dx - 34 * scale, center.dy - 12 * scale)
      ..lineTo(center.dx - 116 * scale, center.dy - 72 * scale)
      ..lineTo(center.dx - 78 * scale, center.dy + 16 * scale)
      ..close();
    final rightWing = Path()
      ..moveTo(center.dx + 20 * scale, center.dy - 8 * scale)
      ..lineTo(center.dx + 96 * scale, center.dy - 62 * scale)
      ..lineTo(center.dx + 70 * scale, center.dy + 18 * scale)
      ..close();
    canvas
      ..drawPath(leftWing, wingPaint)
      ..drawPath(rightWing, wingPaint)
      ..drawOval(
        Rect.fromCenter(center: center, width: 132 * scale, height: 76 * scale),
        bodyPaint,
      )
      ..drawOval(
        Rect.fromCenter(
          center: center.translate(22 * scale, 6 * scale),
          width: 58 * scale,
          height: 30 * scale,
        ),
        bellyPaint,
      )
      ..drawCircle(
        center.translate(74 * scale, -18 * scale),
        28 * scale,
        bodyPaint,
      )
      ..drawCircle(
        center.translate(84 * scale, -24 * scale),
        4 * scale,
        Paint()..color = Colors.white,
      )
      ..drawCircle(
        center.translate(86 * scale, -24 * scale),
        2 * scale,
        Paint()..color = Colors.black,
      );
  }

  void _drawEnemy(Canvas canvas, Size size, Offset relative, int frame) {
    final center = Offset(size.width * relative.dx, size.height * relative.dy);
    final radius = size.width * (0.052 + frame * 0.004);
    final paint = Paint()
      ..color = [
        const Color(0xff5e2ca5),
        const Color(0xff1b8f8a),
        const Color(0xffa8421d),
      ][frame % 3];
    canvas
      ..drawCircle(center, radius, paint)
      ..drawCircle(
        center.translate(-radius * 0.32, -radius * 0.18),
        radius * 0.16,
        Paint()..color = Colors.white,
      )
      ..drawCircle(
        center.translate(radius * 0.32, -radius * 0.18),
        radius * 0.16,
        Paint()..color = Colors.white,
      );
  }

  void _drawProjectiles(Canvas canvas, Size size) {
    final firePaint = Paint()..color = const Color(0xffffd15c);
    final fireCore = Paint()..color = const Color(0xffffffff);
    for (final point in [
      Offset(size.width * 0.48, size.height * 0.47),
      Offset(size.width * 0.58, size.height * 0.42),
      Offset(size.width * 0.63, size.height * 0.55),
    ]) {
      canvas.drawCircle(point, 15, firePaint);
      canvas.drawCircle(point, 6, fireCore);
    }

    final bulletPaint = Paint()..color = const Color(0xff6831a5);
    for (final point in [
      Offset(size.width * 0.54, size.height * 0.32),
      Offset(size.width * 0.50, size.height * 0.64),
    ]) {
      canvas.drawCircle(point, 10, bulletPaint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
    FontWeight fontWeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFamily: 'MPLUSRounded1c',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GameplayPosterPainter oldDelegate) {
    return false;
  }
}

double mathMin(double a, double b) => a < b ? a : b;

class _ScreenshotDevice {
  const _ScreenshotDevice({
    required this.name,
    required this.logicalSize,
    required this.pixelRatio,
  });

  final String name;
  final Size logicalSize;
  final double pixelRatio;
}

final _captureKey = GlobalKey();

Future<void> _capture({
  required WidgetTester tester,
  required _ScreenshotDevice device,
  required String fileName,
  required Widget child,
}) async {
  await _pumpForCapture(tester: tester, device: device, child: child);
  await _writeScreenshot(tester, device, fileName);
}

Future<void> _pumpForCapture({
  required WidgetTester tester,
  required _ScreenshotDevice device,
  required Widget child,
}) async {
  tester.view
    ..physicalSize = device.logicalSize
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ja'),
        supportedLocales: DragonStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: ThemeData(
          fontFamily: 'MPLUSRounded1c',
          fontFamilyFallback: const [
            'Hiragino Sans',
            'Yu Gothic',
            'Meiryo',
            'sans-serif',
          ],
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _writeScreenshot(
  WidgetTester tester,
  _ScreenshotDevice device,
  String fileName,
) async {
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile('../$_outputRoot/${device.name}/$fileName'),
  );
}

Future<void> _loadFonts() async {
  await (FontLoader('MPLUSRounded1c')
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Medium.ttf'))
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Bold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-ExtraBold.ttf'))
        ..addFont(rootBundle.load('assets/fonts/MPLUSRounded1c-Black.ttf')))
      .load();

  if (_flutterRoot.isEmpty) return;
  final materialIcons = File(
    '$_flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!materialIcons.existsSync()) return;
  final bytes = await materialIcons.readAsBytes();
  await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes)))))
      .load();
}
