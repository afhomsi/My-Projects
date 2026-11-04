import '../data/hadith.dart';

/// Where the sound of a hadith comes from.
enum VoiceKind {
  /// A human recording bundled with the app, with written permission.
  recording,

  /// The device text-to-speech engine. A stopgap: weak on tashkeel.
  deviceSpeech,
}

/// Thrown when the voice cannot play at all, for example when the device
/// has no Arabic text-to-speech voice installed.
class VoiceUnavailable implements Exception {
  const VoiceUnavailable();
}

/// Plays one hadith once. The repetition lives in `ListenController`, so a
/// recorded voice can later replace device speech without touching it.
abstract class HadithVoice {
  VoiceKind get kind;

  /// Plays [hadith] once. Completes when it ends or when [stop] is called.
  /// Throws [VoiceUnavailable] if this voice cannot play on this device.
  Future<void> play(Hadith hadith);

  Future<void> stop();
}
