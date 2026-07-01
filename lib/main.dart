import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' as ja;
import 'package:shared_preferences/shared_preferences.dart';

const _leaderboardUrl = String.fromEnvironment('LEADERBOARD_URL');
const _scoreSubmitUrl = String.fromEnvironment('SCORE_SUBMIT_URL');
const _gameVersion = '1.0.0';
const _gameBgmIntroFile = 'game_bgm_intro.flac';
const _gameBgmLoopFile = 'game_bgm_loop.flac';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DragonApp());
}

class DragonApp extends StatelessWidget {
  const DragonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attack of Dragon',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffe6652a),
          brightness: Brightness.light,
        ),
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
        useMaterial3: true,
      ),
      home: const _PortraitOnly(child: DragonShell()),
    );
  }
}

class _PortraitOnly extends StatelessWidget {
  const _PortraitOnly({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= size.height) {
      return child;
    }
    return const _LandscapeBlockedScreen();
  }
}

class _LandscapeBlockedScreen extends StatelessWidget {
  const _LandscapeBlockedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SkyBackdrop(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.screen_rotation_alt_rounded,
                          size: 42,
                          color: Color(0xffb53c18),
                        ),
                        SizedBox(height: 12),
                        Text(
                          '横画面では遊べません',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '画面を縦向きに戻してください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
    'shingeki_dragon/audio_lifecycle',
  );

  final GameAudio _audio = GameAudio();
  late final AppLifecycleListener _appLifecycleListener;
  ShellScreen _screen = ShellScreen.title;
  AppSettings _settings = AppSettings.defaults();
  List<ScoreEntry> _localScores = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleListener = AppLifecycleListener(
      onResume: () => _setAudioActive(true),
      onInactive: () => _setAudioActive(false),
      onHide: () => _setAudioActive(false),
      onPause: () => _setAudioActive(false),
      onDetach: () => _setAudioActive(false),
    );
    _audioLifecycleChannel.setMethodCallHandler(_handleAudioLifecycleCall);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioLifecycleChannel.setMethodCallHandler(null);
    _appLifecycleListener.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setAudioActive(state == AppLifecycleState.resumed);
  }

  void _setAudioActive(bool active) {
    unawaited(_audio.setAppActive(active));
  }

  Future<void> _handleAudioLifecycleCall(MethodCall call) async {
    switch (call.method) {
      case 'resumed':
        await _audio.setAppActive(true);
        return;
      case 'inactive':
        await _audio.setAppActive(false);
        return;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPlayerName = prefs.containsKey('playerName');
    final settings = AppSettings.fromPrefs(prefs);
    final scores = ScoreStore.loadLocalScores(prefs);
    if (!hasPlayerName) {
      await settings.save(prefs);
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _localScores = scores;
      _loaded = true;
    });
    _audio.applySettings(settings);
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
  }

  Future<void> _recordScore(ScoreEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final scores = await ScoreStore.addLocalScore(prefs, entry);
    if (mounted) setState(() => _localScores = scores);
    if (_scoreSubmitUrl.isNotEmpty) {
      unawaited(ScoreStore.submitScore(entry));
    }
  }

  void _show(ShellScreen screen) {
    setState(() => _screen = screen);
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

    return switch (_screen) {
      ShellScreen.title => TitleScreen(
        audio: _audio,
        onStart: () => _show(ShellScreen.game),
        onSettings: () => _show(ShellScreen.settings),
        onScoreboard: () => _show(ShellScreen.scoreboard),
      ),
      ShellScreen.game => GameScreen(
        settings: _settings,
        bestScore: _bestScore,
        audio: _audio,
        onScore: _recordScore,
        onTitle: () => _show(ShellScreen.title),
      ),
      ShellScreen.settings => SettingsScreen(
        settings: _settings,
        audio: _audio,
        onChanged: _saveSettings,
        onBack: () => _show(ShellScreen.title),
      ),
      ShellScreen.scoreboard => ScoreboardScreen(
        localScores: _localScores,
        audio: _audio,
        onBack: () => _show(ShellScreen.title),
      ),
    };
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
    return Scaffold(
      body: Stack(
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
                    width: math.min(MediaQuery.sizeOf(context).width - 48, 560),
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'スタート',
                          onPressed: () {
                            unawaited(audio.playSfx('ui_accept.ogg'));
                            onStart();
                          },
                        ),
                        const SizedBox(height: 14),
                        _MenuButton(
                          icon: Icons.tune_rounded,
                          label: '設定',
                          onPressed: () {
                            unawaited(audio.playSfx('ui_accept.ogg'));
                            onSettings();
                          },
                        ),
                        const SizedBox(height: 14),
                        _MenuButton(
                          icon: Icons.leaderboard_rounded,
                          label: 'スコアボード',
                          onPressed: () {
                            unawaited(audio.playSfx('ui_accept.ogg'));
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
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.audio,
    required this.onChanged,
    required this.onBack,
    super.key,
  });

  final AppSettings settings;
  final GameAudio audio;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onBack;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late AppSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.settings;
    _nameController = TextEditingController(text: _draft.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _commit(AppSettings settings) {
    setState(() => _draft = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SkyBackdrop(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _nameController,
                            maxLength: AppSettings.maxPlayerNameLength,
                            decoration: const InputDecoration(
                              labelText: 'プレイヤー名',
                              counterText: '',
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
                          Text('音量 ${(100 * _draft.volume).round()}%'),
                          Slider(
                            value: _draft.volume,
                            onChanged: (value) {
                              _commit(_draft.copyWith(volume: value));
                            },
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () {
                              unawaited(widget.audio.playSfx('ui_cancel.ogg'));
                              widget.onBack();
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('タイトルへ戻る'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({
    required this.localScores,
    required this.audio,
    required this.onBack,
    super.key,
  });

  final List<ScoreEntry> localScores;
  final GameAudio audio;
  final VoidCallback onBack;

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  late Future<ScoreboardData> _scores;

  int get _bestScore {
    if (widget.localScores.isEmpty) return 0;
    return widget.localScores.map((score) => score.score).reduce(math.max);
  }

  @override
  void initState() {
    super.initState();
    _scores = ScoreStore.loadScoreboard(widget.localScores);
  }

  @override
  Widget build(BuildContext context) {
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
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  final scores = data?.scores ?? widget.localScores;
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
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.leaderboard_rounded),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        data?.sourceLabel ?? 'スコアボード',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (isLoading)
                                      const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _BestScoreBlock(score: _bestScore),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: itemCount == 0
                                      ? const Center(child: Text('まだ記録がありません'))
                                      : ListView.builder(
                                          itemCount: itemCount,
                                          itemBuilder: (context, index) {
                                            return _ScoreRow(
                                              rank: index + 1,
                                              score: scores[index],
                                            );
                                          },
                                        ),
                                ),
                                if (data?.message case final message?
                                    when message.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          unawaited(widget.audio.playSfx('ui_cancel.ogg'));
                          widget.onBack();
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('タイトルへ戻る'),
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

class _BestScoreBlock extends StatelessWidget {
  const _BestScoreBlock({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final scoreText = score == 0 ? '--' : '$score m';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '自己ベスト',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xffc85b24),
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                scoreText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xff662b15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.rank, required this.score});

  final int rank;
  final ScoreEntry score;

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
    return ColoredBox(
      color: topRank ? accent.withValues(alpha: 0.12) : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: topRank
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_rankIcon, color: accent, size: 18),
                        const SizedBox(width: 3),
                        Text(
                          '$rank',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '#$rank',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                  Text(
                    '撃破 ${score.kills}',
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
            SizedBox(
              width: 104,
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
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.settings,
    required this.bestScore,
    required this.audio,
    required this.onScore,
    required this.onTitle,
    super.key,
  });

  final AppSettings settings;
  final int bestScore;
  final GameAudio audio;
  final Future<void> Function(ScoreEntry score) onScore;
  final VoidCallback onTitle;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum RunState { ready, playing, gameOver }

enum EnemyKind { bat, bird, slime, mage, gargoyle }

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const _dragonFrameSize = Size(256, 192);
  static const _enemyCellSize = Size(256, 256);
  static const double _fireSpreadAngle = 0.20;
  static const double _tapLiftSpeedFactor = 0.28;
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
  double _dragonY = 0;
  double _velocityY = 0;
  double _backgroundOffset = 0;
  double _score = 0;
  int _kills = 0;
  double _spawnTimer = 0.8;
  double _fireTimer = 0;
  bool _scoreRecorded = false;
  int _lastDangerPattern = -1;
  final List<EnemyModel> _enemies = [];
  final List<ProjectileModel> _fireballs = [];
  final List<ProjectileModel> _enemyBullets = [];
  final List<EffectModel> _effects = [];

  @override
  void initState() {
    super.initState();
    _images = GameImages.load();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
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
      _lastDangerPattern = -1;
      _enemies.clear();
      _fireballs.clear();
      _enemyBullets.clear();
      _effects.clear();
      _dragonY = _worldSize.height * 0.45;
    });
  }

  void _tap() {
    if (_worldSize == Size.zero || _state == RunState.gameOver) return;
    if (_state == RunState.ready) {
      _state = RunState.playing;
      _scoreRecorded = false;
    }
    _velocityY = -_worldSize.height * _tapLiftSpeedFactor;
    unawaited(widget.audio.playSfx('player_jump.ogg', volumeScale: 0.45));
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
    unawaited(widget.audio.playSfx('fireball.ogg', volumeScale: 0.42));
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
    unawaited(widget.audio.playSfx('enemy_charge.mp3', volumeScale: 0.28));
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
            unawaited(widget.audio.playSfx('explosion.ogg', volumeScale: 0.38));
          } else {
            unawaited(widget.audio.playSfx('enemy_hit.ogg', volumeScale: 0.36));
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
    _velocityY = 0;
    unawaited(widget.audio.playSfx('player_damage.ogg', volumeScale: 0.7));
    if (!_scoreRecorded) {
      _scoreRecorded = true;
      unawaited(
        widget.onScore(
          ScoreEntry(
            name: AppSettings.scoreName(widget.settings.playerName),
            score: _score.round(),
            kills: _kills,
            date: DateTime.now().toUtc(),
            version: _gameVersion,
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
    return margin + _rng.nextDouble() * (_worldSize.height - margin * 2);
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
    final clampedY = y.clamp(margin, _worldSize.height - margin).toDouble();
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
        shootTimer: kind == EnemyKind.mage ? 1.0 + _rng.nextDouble() : 999,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GameImages>(
      future: _images,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final images = snapshot.data!;
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (_worldSize != size) {
                _worldSize = size;
                if (_dragonY == 0) _dragonY = size.height * 0.45;
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: DragonGamePainter(
                        images: images,
                        state: _state,
                        time: _time,
                        backgroundOffset: _backgroundOffset,
                        score: _score,
                        kills: _kills,
                        dragonRect: _dragonRect,
                        dragonFrameSize: _dragonFrameSize,
                        enemyCellSize: _enemyCellSize,
                        enemies: _enemies,
                        fireballs: _fireballs,
                        enemyBullets: _enemyBullets,
                        effects: _effects,
                      ),
                    ),
                    if (_state == RunState.ready) const _ReadyPrompt(),
                    if (_state == RunState.gameOver)
                      _ResultOverlay(
                        score: _score.round(),
                        bestScore: math.max(widget.bestScore, _score.round()),
                        kills: _kills,
                        onRetry: _reset,
                        onTitle: widget.onTitle,
                        audio: widget.audio,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReadyPrompt extends StatelessWidget {
  const _ReadyPrompt();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.42),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            'タップしてスタート',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    required this.onRetry,
    required this.onTitle,
    required this.audio,
  });

  final int score;
  final int bestScore;
  final int kills;
  final VoidCallback onRetry;
  final VoidCallback onTitle;
  final GameAudio audio;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$score m',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ベスト $bestScore m',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff9a3d16),
                    ),
                  ),
                  Text(
                    '撃破 $kills',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      unawaited(audio.playSfx('ui_accept.ogg'));
                      onRetry();
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('リトライ'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      unawaited(audio.playSfx('ui_cancel.ogg'));
                      onTitle();
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('タイトルへ戻る'),
                  ),
                ],
              ),
            ),
          ),
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
      _drawAtlasSprite(
        canvas,
        images.enemyAtlas,
        enemy.spriteIndex,
        enemy.rect,
        3,
        flipX: enemy.shouldFlipSprite,
      );
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

  void _drawAtlasSprite(
    Canvas canvas,
    ui.Image image,
    int index,
    Rect dst,
    int columns, {
    Paint? paint,
    bool flipX = false,
    double rotation = 0,
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
    if (!flipX && rotation == 0) {
      canvas.drawImageRect(image, src, dst, spritePaint);
      return;
    }

    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    if (flipX) {
      canvas.scale(-1, 1);
    }
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
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: math.max(22, size.width * 0.06),
      fontWeight: FontWeight.w900,
      shadows: const [
        Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black54),
      ],
    );
    final scoreText = TextPainter(
      text: TextSpan(text: '${score.round()} m', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    scoreText.paint(canvas, Offset((size.width - scoreText.width) / 2, 30));

    final killText = TextPainter(
      text: TextSpan(
        text: '撃破 $kills',
        style: textStyle.copyWith(fontSize: math.max(14, size.width * 0.035)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    killText.paint(canvas, Offset(size.width - killText.width - 16, 40));
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
    final enemy = await _loadImage('assets/images/enemy_atlas.png');
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
  double shootTimer;
  double time = 0;
  bool dead = false;

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
  const AppSettings({required this.playerName, required this.volume});

  static const int maxPlayerNameLength = 14;
  static const String fallbackPlayerName = 'Player';

  final String playerName;
  final double volume;

  static AppSettings defaults() {
    return AppSettings(playerName: randomDefaultPlayerName(), volume: 0.75);
  }

  static AppSettings fromPrefs(SharedPreferences prefs) {
    final storedName = prefs.getString('playerName');
    return AppSettings(
      playerName: storedName == null
          ? randomDefaultPlayerName()
          : cleanName(storedName),
      volume: (prefs.getDouble('volume') ?? 0.75).clamp(0.0, 1.0),
    );
  }

  static String randomDefaultPlayerName() {
    final random = math.Random();
    final digits = List.generate(8, (_) => random.nextInt(10)).join();
    return 'Player$digits';
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
    await prefs.setString('playerName', cleanName(playerName));
    await prefs.setDouble('volume', volume);
  }

  AppSettings copyWith({String? playerName, double? volume}) {
    return AppSettings(
      playerName: playerName ?? this.playerName,
      volume: volume ?? this.volume,
    );
  }
}

class ScoreEntry {
  const ScoreEntry({
    required this.name,
    required this.score,
    required this.kills,
    required this.date,
    required this.version,
  });

  final String name;
  final int score;
  final int kills;
  final DateTime date;
  final String version;

  Map<String, Object> toJson() {
    return {
      'name': AppSettings.scoreName(name),
      'score': score,
      'kills': kills,
      'date': date.toIso8601String(),
      'version': version,
    };
  }

  static ScoreEntry fromJson(Map<String, dynamic> json) {
    return ScoreEntry(
      name: AppSettings.scoreName('${json['name'] ?? ''}'),
      score: (json['score'] as num?)?.round() ?? 0,
      kills: (json['kills'] as num?)?.round() ?? 0,
      date:
          DateTime.tryParse('${json['date'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      version: '${json['version'] ?? _gameVersion}',
    );
  }
}

class ScoreboardData {
  const ScoreboardData({
    required this.scores,
    required this.sourceLabel,
    required this.message,
  });

  final List<ScoreEntry> scores;
  final String sourceLabel;
  final String message;
}

class ScoreStore {
  static const int maxLeaderboardEntries = 10000;

  static List<ScoreEntry> loadLocalScores(SharedPreferences prefs) {
    final text = prefs.getString('scores');
    if (text == null || text.isEmpty) return const [];
    final value = jsonDecode(text);
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(ScoreEntry.fromJson)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
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
      jsonEncode(trimmed.map((score) => score.toJson()).toList()),
    );
    return trimmed;
  }

  static Future<ScoreboardData> loadScoreboard(List<ScoreEntry> local) async {
    try {
      final online = await _loadOnline();
      final merged = [...online, ...local]
        ..sort((a, b) => b.score.compareTo(a.score));
      return ScoreboardData(
        scores: merged.take(maxLeaderboardEntries).toList(),
        sourceLabel: _leaderboardUrl.isEmpty ? 'スコアボード' : 'オンラインスコア',
        message: _leaderboardUrl.isEmpty
            ? 'LEADERBOARD_URL 未設定のため、同梱データとローカル記録を表示しています。'
            : '',
      );
    } catch (_) {
      final fallback = await _loadBundled();
      final merged = [...fallback, ...local]
        ..sort((a, b) => b.score.compareTo(a.score));
      return ScoreboardData(
        scores: merged.take(maxLeaderboardEntries).toList(),
        sourceLabel: 'スコアボード',
        message: 'オンライン取得に失敗したため、同梱データとローカル記録を表示しています。',
      );
    }
  }

  static Future<List<ScoreEntry>> _loadOnline() async {
    if (_leaderboardUrl.isEmpty) return _loadBundled();
    final response = await http.get(Uri.parse(_leaderboardUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('leaderboard http ${response.statusCode}');
    }
    return _parseScores(response.body);
  }

  static Future<List<ScoreEntry>> _loadBundled() async {
    final text = await rootBundle.loadString('assets/data/leaderboard.json');
    return _parseScores(text);
  }

  static List<ScoreEntry> _parseScores(String text) {
    final json = jsonDecode(text);
    final list = json is Map ? json['scores'] : json;
    if (list is! List) return const [];
    final scores =
        list.whereType<Map<String, dynamic>>().map(ScoreEntry.fromJson).toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return scores.take(maxLeaderboardEntries).toList();
  }

  static Future<void> submitScore(ScoreEntry entry) async {
    if (_scoreSubmitUrl.isEmpty) return;
    try {
      final response = await http
          .post(
            Uri.parse(_scoreSubmitUrl),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(entry.toJson()),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('score submit http ${response.statusCode}');
      }
    } catch (_) {}
  }
}

class GameAudio {
  static const int _sfxPoolSize = 4;

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
  int _musicGeneration = 0;
  String? _requestedMusicIntroFile;
  String? _requestedMusicFile;
  bool _requestedMusicLoops = false;
  bool _appActive = true;
  bool _disposed = false;

  GameAudio() {
    unawaited(_configureMusicSession());
    _musicStateSubscription = _music.playerStateStream.listen((state) {
      if (_disposed || !_appActive) return;
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

  Future<void> playMusic(String file, {required bool loop}) {
    if (_disposed) return Future<void>.value();
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
      if (_disposed || generation != _musicGeneration) return;
      await _setAndroidAudioAttributes(_music);
      if (_disposed || generation != _musicGeneration) return;
      await _music.setLoopMode(loop ? ja.LoopMode.one : ja.LoopMode.off);
      if (_disposed || generation != _musicGeneration) return;
      await _music.setAudioSource(
        ja.AudioSource.asset('assets/audio/$file'),
        preload: true,
      );
      if (_disposed || generation != _musicGeneration) return;
      await _music.setVolume(_settings.volume * 0.55);
      if (_disposed || generation != _musicGeneration) return;
      await _music.seek(Duration.zero);
      if (_disposed || generation != _musicGeneration) return;
      await _music.play();
    });
  }

  Future<void> playMusicIntroThenLoop({
    required String introFile,
    required String loopFile,
  }) {
    if (_disposed) return Future<void>.value();
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
      if (_disposed || generation != _musicGeneration) return;
      await _setAndroidAudioAttributes(_music);
      if (_disposed || generation != _musicGeneration) return;
      await _music.setLoopMode(ja.LoopMode.off);
      if (_disposed || generation != _musicGeneration) return;
      await _music.setAudioSources(
        [
          ja.AudioSource.asset('assets/audio/$introFile'),
          ja.AudioSource.asset('assets/audio/$loopFile'),
        ],
        preload: true,
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      if (_disposed || generation != _musicGeneration) return;
      await _music.setVolume(_settings.volume * 0.55);
      if (_disposed || generation != _musicGeneration) return;
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
    final next = _musicQueue.then((_) => operation()).catchError((Object _) {});
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

  Future<void> setAppActive(bool active) {
    if (_disposed) return Future<void>.value();
    if (active && _appActive) return Future<void>.value();
    _appActive = active;
    if (!active) {
      _musicGeneration++;
      final generation = _musicGeneration;
      unawaited(_haltMusicNow(generation, deactivateSession: true));
      return _enqueueMusic(() async {
        if (_disposed || generation != _musicGeneration) return;
        await _haltMusicNow(generation, deactivateSession: true);
      });
    }

    final file = _requestedMusicFile;
    if (file == null || !_requestedMusicLoops) {
      return Future<void>.value();
    }
    final introFile = _requestedMusicIntroFile;
    if (introFile != null) {
      return playMusicIntroThenLoop(introFile: introFile, loopFile: file);
    }
    return playMusic(file, loop: true);
  }

  Future<void> playSfx(String file, {double volumeScale = 1}) {
    if (_disposed || !_appActive) return Future<void>.value();
    final volume = (_settings.volume * volumeScale).clamp(0.0, 1.0).toDouble();
    if (volume <= 0) return Future<void>.value();
    return _playSfx(file, volume);
  }

  Future<void> _playSfx(String file, double volume) async {
    try {
      final pool = _sfxPools[file] ??= _createSfxPool(file);
      await pool.ready;
      if (_disposed || !_appActive) return;
      final player = pool.nextPlayer();
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
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
    final ready = Future.wait(
      players.map((player) async {
        await _setAndroidAudioAttributes(player);
        await player.setLoopMode(ja.LoopMode.off);
        await player.setAudioSource(
          ja.AudioSource.asset('assets/audio/$file'),
          preload: true,
        );
      }),
    );
    return _SfxPool(players: players, ready: ready);
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
    if (_disposed || generation != _musicGeneration) return;
    if (!deactivateSession) return;
    try {
      final session = await audio_session.AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
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
