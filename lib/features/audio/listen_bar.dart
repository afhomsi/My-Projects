import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/hadith_voice.dart';
import '../../audio/listen_controller.dart';
import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../arabic_numbers.dart';

/// Listen to the current hadith, repeated the number of times the user chose.
class ListenBar extends ConsumerWidget {
  const ListenBar({super.key, required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final listen = ref.watch(listenProvider);
    final controller = ref.read(listenProvider.notifier);
    final playingThis = listen.playing == hadith.number;
    final notice = listen.unavailable
        ? s.voiceUnavailable
        : playingThis &&
              ref.read(hadithVoiceProvider).kind == VoiceKind.deviceSpeech
        ? s.deviceVoiceNotice
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('listen-toggle'),
              onPressed: () =>
                  playingThis ? controller.stop() : controller.play(hadith),
              icon: Icon(playingThis ? Icons.stop : Icons.play_arrow),
              label: Text(playingThis ? s.stopAction : s.listenAction),
            ),
            const SizedBox(width: 12),
            if (playingThis)
              Expanded(
                child: Text(
                  listen.isEndless
                      ? s.repeatRoundEndless(arabicNumber(listen.round))
                      : s.repeatRound(
                          arabicNumber(listen.round),
                          arabicNumber(listen.repeatCount),
                        ),
                  key: const ValueKey('listen-round'),
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              const Spacer(),
            PopupMenuButton<int>(
              key: const ValueKey('listen-repeat'),
              initialValue: listen.repeatCount,
              onSelected: controller.setRepeatCount,
              itemBuilder: (context) => [
                for (final count in repeatChoices)
                  PopupMenuItem(value: count, child: Text(_times(s, count))),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.repeat, size: 20),
                    const SizedBox(width: 4),
                    Text(s.repeatLabel(_times(s, listen.repeatCount))),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              notice,
              key: const ValueKey('listen-notice'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  static String _times(S s, int count) =>
      count == 0 ? s.repeatEndless : s.repeatTimes(count, arabicNumber(count));
}
