import '../data/hadith.dart';

/// Thrown when a recording cannot be played on this device.
class VoiceUnavailable implements Exception {
  const VoiceUnavailable();
}

/// Plays one hadith once. The repetition lives in `ListenController`, so the
/// voice can change without touching it, and tests use a fake.
abstract class HadithVoice {
  /// Plays [hadith] once. Completes when it ends or when [stop] is called.
  /// Throws [VoiceUnavailable] if it cannot be played.
  Future<void> play(Hadith hadith);

  Future<void> stop();
}
