import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hadith.dart';
import '../features/plan/plan_controller.dart';
import 'device_speech_voice.dart';
import 'hadith_voice.dart';

/// Repeat counts offered to the user. 0 means "without stopping".
const repeatChoices = [1, 3, 10, 20, 50, 0];

/// Silence between two repetitions of the same hadith.
const repeatGap = Duration(milliseconds: 1200);

const _repeatKey = 'listen.repeat';

/// The voice that reads the ahadith; replaced by a fake in tests.
final hadithVoiceProvider = Provider<HadithVoice>((ref) {
  final voice = DeviceSpeechVoice();
  ref.onDispose(voice.stop);
  return voice;
});

final listenProvider = NotifierProvider.autoDispose<ListenController, Listen>(
  ListenController.new,
);

class Listen {
  const Listen({
    required this.repeatCount,
    this.playing,
    this.round = 0,
    this.unavailable = false,
  });

  /// How many times to play the hadith; 0 means without stopping.
  final int repeatCount;

  /// The number of the hadith being played, or null when stopped.
  final int? playing;

  /// Which repetition is playing now, from 1.
  final int round;

  /// True after the voice could not play on this device.
  final bool unavailable;

  bool get isEndless => repeatCount == 0;

  Listen copyWith({
    int? repeatCount,
    int? Function()? playing,
    int? round,
    bool? unavailable,
  }) => Listen(
    repeatCount: repeatCount ?? this.repeatCount,
    playing: playing != null ? playing() : this.playing,
    round: round ?? this.round,
    unavailable: unavailable ?? this.unavailable,
  );
}

/// Plays one hadith the chosen number of times. Leaving the screen stops it.
class ListenController extends AutoDisposeNotifier<Listen> {
  /// Bumped on every play and stop, so an old loop knows it must end.
  int _run = 0;

  HadithVoice get _voice => ref.read(hadithVoiceProvider);

  @override
  Listen build() {
    final voice = ref.watch(hadithVoiceProvider);
    ref.onDispose(() {
      _run++;
      voice.stop();
    });
    final saved = ref.watch(sharedPreferencesProvider).getInt(_repeatKey);
    return Listen(
      repeatCount: repeatChoices.contains(saved) ? saved! : repeatChoices[1],
    );
  }

  void setRepeatCount(int count) {
    assert(repeatChoices.contains(count));
    state = state.copyWith(repeatCount: count);
    ref.read(sharedPreferencesProvider).setInt(_repeatKey, count);
  }

  /// Plays [hadith] [Listen.repeatCount] times, stopping anything playing.
  Future<void> play(Hadith hadith) async {
    final run = ++_run;
    await _voice.stop();
    if (run != _run) return;
    state = state.copyWith(
      playing: () => hadith.number,
      round: 1,
      unavailable: false,
    );
    for (
      var round = 1;
      state.isEndless || round <= state.repeatCount;
      round++
    ) {
      if (round > 1) {
        await Future<void>.delayed(repeatGap);
        if (run != _run) return;
      }
      state = state.copyWith(round: round);
      try {
        await _voice.play(hadith);
      } on VoiceUnavailable {
        if (run != _run) return;
        state = state.copyWith(playing: () => null, unavailable: true);
        return;
      }
      if (run != _run) return;
    }
    state = state.copyWith(playing: () => null, round: 0);
  }

  Future<void> stop() async {
    _run++;
    if (state.playing != null) {
      state = state.copyWith(playing: () => null, round: 0);
    }
    await _voice.stop();
  }
}
