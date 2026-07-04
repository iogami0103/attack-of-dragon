import 'dart:io';

import 'package:just_audio/just_audio.dart' as ja;

ja.AudioSource createGameAudioSource(String assetPath) {
  if (!Platform.isWindows) {
    return ja.AudioSource.asset(assetPath);
  }

  final file = _windowsBundledAssetFile(assetPath);
  if (file.existsSync()) {
    return ja.AudioSource.file(_windowsPlayableAudioFile(file, assetPath).path);
  }

  return ja.AudioSource.asset(assetPath);
}

File _windowsPlayableAudioFile(File bundledFile, String assetPath) {
  try {
    final playableFile = _windowsPlayableCacheFile(assetPath);
    final bundledLength = bundledFile.lengthSync();
    final needsCopy =
        !playableFile.existsSync() ||
        playableFile.lengthSync() != bundledLength;
    if (needsCopy) {
      playableFile.parent.createSync(recursive: true);
      bundledFile.copySync(playableFile.path);
    }
    return playableFile;
  } catch (_) {
    return bundledFile;
  }
}

File _windowsPlayableCacheFile(String assetPath) {
  return File(
    _joinPath([
      Directory.systemTemp.path,
      'attack_of_the_dragon_audio',
      ...assetPath.split('/'),
    ]),
  );
}

File _windowsBundledAssetFile(String assetPath) {
  final executableDirectory = File(Platform.resolvedExecutable).parent.path;
  return File(
    _joinPath([
      executableDirectory,
      'data',
      'flutter_assets',
      ...assetPath.split('/'),
    ]),
  );
}

String _joinPath(Iterable<String> segments) {
  return segments
      .where((segment) => segment.isNotEmpty)
      .join(Platform.pathSeparator);
}
