import 'package:flutter_tts/flutter_tts.dart';

import '../data/hadith.dart';
import 'hadith_voice.dart';

/// Reads the matn with the device text-to-speech engine. Works offline when
/// the device has an Arabic voice installed. Needs no licence, but it can
/// mispronounce words, so the screen shows a notice while it plays.
class DeviceSpeechVoice implements HadithVoice {
  DeviceSpeechVoice([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _setup;

  @override
  VoiceKind get kind => VoiceKind.deviceSpeech;

  Future<void> _init() async {
    await _tts.awaitSpeakCompletion(true);
    Object? available;
    try {
      available = await _tts.isLanguageAvailable('ar');
    } catch (_) {
      // Some platforms cannot answer; try to speak anyway.
    }
    if (available == false) throw const VoiceUnavailable();
    await _tts.setLanguage('ar');
  }

  @override
  Future<void> play(Hadith hadith) async {
    try {
      await (_setup ??= _init());
    } on VoiceUnavailable {
      _setup = null;
      rethrow;
    }
    await _tts.speak(hadith.matn);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
