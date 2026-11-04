import 'package:arbaeen/recitation/speech_listener.dart';

/// Plays back text instead of listening to a microphone.
class FakeListener implements SpeechListener {
  void Function(String text, bool isFinal)? _onResult;
  void Function(String message)? _onError;
  late void Function() _onDone;
  bool listening = false;
  bool available = true;
  int sessions = 0;

  void say(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal);

  void fail(String message) => _onError?.call(message);

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    _onError = onError;
    _onDone = onDone;
    return available;
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    listening = true;
    sessions++;
  }

  @override
  Future<void> stop() async {
    if (!listening) return;
    listening = false;
    _onDone();
  }
}
