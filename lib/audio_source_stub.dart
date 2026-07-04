import 'package:just_audio/just_audio.dart' as ja;

ja.AudioSource createGameAudioSource(String assetPath) {
  return ja.AudioSource.asset(assetPath);
}
