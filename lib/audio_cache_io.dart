import 'dart:io';

Future<void> repairJustAudioAssetCache() async {
  if (!Platform.isWindows) return;

  final cache = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}just_audio_cache',
  );
  if (!cache.existsSync()) return;

  await for (final entity in cache.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    try {
      final stat = await entity.stat();
      if (stat.size == 0) {
        await entity.delete();
      }
    } catch (_) {
      // Cache repair is best-effort; playback will report any remaining issue.
    }
  }
}
