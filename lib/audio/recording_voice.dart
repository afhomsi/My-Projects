import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../data/hadith.dart';
import 'hadith_voice.dart';
import 'recordings.dart';

/// Plays the bundled recording of a hadith with `just_audio`. Offline.
class RecordingVoice implements HadithVoice {
  final _player = AudioPlayer();
  Completer<void>? _done;
  StreamSubscription<ProcessingState>? _states;

  @override
  Future<void> play(Hadith hadith) async {
    _finish();
    final done = _done = Completer<void>();
    try {
      await _player.setAsset(recordingAsset(hadith.number));
    } on Exception {
      _done = null;
      throw const VoiceUnavailable();
    }
    await _states?.cancel();
    _states = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !done.isCompleted) {
        done.complete();
      }
    });
    unawaited(_player.play());
    await done.future;
  }

  void _finish() {
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  @override
  Future<void> stop() async {
    _finish();
    await _player.stop();
  }

  Future<void> dispose() async {
    _finish();
    await _states?.cancel();
    await _player.dispose();
  }
}
