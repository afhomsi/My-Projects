import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../features/plan/plan_controller.dart';

/// Turns the microphone into text, one listening session at a time.
///
/// Kept behind an interface so the tasmee' screen can be tested without
/// a microphone. Ported from the Quran app.
abstract class SpeechListener {
  /// Asks for the microphone and returns whether recognition is available.
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  });

  /// Starts a session. [onResult] receives the whole text heard in this
  /// session so far; [isFinal] is true once the session's text is settled.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  });

  Future<void> stop();
}

/// How long a recognizer that sends a result for every word or so may
/// send nothing new before the reciter has likely stopped.
const quickQuietDelay = Duration(milliseconds: 1200);

/// A recognizer that sends its results seldom, as one transcribing what
/// was said every few seconds.
abstract interface class SlowResults {
  /// How long it may send nothing new while the reciter goes on.
  Duration get quietDelay;
}

/// How long [listener] may send nothing new while the reciter goes on.
Duration quietDelayOf(SpeechListener listener) => switch (listener) {
  final SlowResults slow => slow.quietDelay,
  _ => quickQuietDelay,
};

/// Recognition through the platform: Google's recognizer on Android and in
/// Chrome, Apple's on iOS.
///
/// With [onDevice] (the default) the voice is recognized on the phone and
/// never leaves it: on Android 12 and later and on iOS this needs the
/// Arabic language for offline recognition, and listening fails with a
/// network or language error when it is missing. On older Android the
/// recognizer is only asked to prefer the device. In Chrome the browser
/// always sends the voice to Google.
class PlatformSpeechListener implements SpeechListener {
  PlatformSpeechListener({this.onDevice = true});

  final bool onDevice;
  final _speech = SpeechToText();
  String? _localeId;

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function() onDone,
  }) async {
    final ok = await _speech.initialize(
      onError: (SpeechRecognitionError e) => onError(e.errorMsg),
      onStatus: (status) {
        if (status == SpeechToText.doneStatus) onDone();
        // In Chrome every result is partial, so a session the browser ends
        // by itself never turns final. Stopping makes the plugin send the
        // last result as final shortly after.
        if (status == SpeechToText.notListeningStatus) _speech.stop();
      },
    );
    if (!ok) return false;
    _localeId = await _arabicLocale();
    return true;
  }

  Future<String> _arabicLocale() async {
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();
      for (final preferred in ['ar_SA', 'ar-SA', 'ar_EG', 'ar-EG']) {
        if (ids.contains(preferred)) return preferred;
      }
      final anyArabic = ids.where((id) => id.startsWith('ar'));
      if (anyArabic.isNotEmpty) return anyArabic.first;
    } catch (_) {
      // Some platforms cannot list locales; ask for Arabic anyway.
    }
    return 'ar-SA';
  }

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: false,
        onDevice: onDevice,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 6),
        listenFor: const Duration(minutes: 5),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
}

const _onlineKey = 'recite.allowOnline';

/// Whether the user allowed the voice to be recognized over the internet
/// when the device cannot recognize Arabic by itself. Off until they
/// choose it, so by default the voice stays on the phone.
final allowOnlineSpeechProvider = NotifierProvider<AllowOnlineSpeech, bool>(
  AllowOnlineSpeech.new,
);

class AllowOnlineSpeech extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_onlineKey) ?? false;

  void set(bool allow) {
    state = allow;
    ref.read(sharedPreferencesProvider).setBool(_onlineKey, allow);
  }
}

/// The recognizer; replaced by a fake in tests.
final speechListenerProvider = Provider<SpeechListener>(
  (ref) =>
      PlatformSpeechListener(onDevice: !ref.watch(allowOnlineSpeechProvider)),
);
