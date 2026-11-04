import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import '../../recitation/speech_listener.dart';
import '../../theme/app_theme.dart';
import '../arabic_numbers.dart';
import '../memorize/word_hiding.dart';
import '../plan/plan_controller.dart';
import '../plan/review_schedule.dart';

/// The grade a recitation with [mistakes] suggests: none is good, a few
/// is hard, more means it is not memorized yet.
Grade suggestedGrade(int mistakes) => switch (mistakes) {
  0 => Grade.good,
  <= 3 => Grade.hard,
  _ => Grade.again,
};

/// Tasmee' by voice: the reciter says the hadith from memory, each word
/// shows as it is said, and mistakes show in red and in a list.
class ReciteScreen extends ConsumerStatefulWidget {
  const ReciteScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  ConsumerState<ReciteScreen> createState() => _ReciteScreenState();
}

class _ReciteScreenState extends ConsumerState<ReciteScreen> {
  late final List<MatnWord> _tokens = splitMatn(widget.hadith.matn);
  late final List<ExpectedWord> _expected = wordsOfMatn(widget.hadith.matn);

  /// For each word of the matn, its index in [_expected], or null for the
  /// sign ﷺ and lone punctuation, which always show.
  late final List<int?> _indexOfToken = () {
    final index = List<int?>.filled(_tokens.length, null);
    for (var i = 0; i < _expected.length; i++) {
      final w = _expected[i];
      if (!w.optional) index[w.token] = i;
    }
    return index;
  }();

  RecitationSession? _session;
  bool _showText = false;

  @override
  void initState() {
    super.initState();
    _newSession();
  }

  void _newSession() {
    _session?.removeListener(_changed);
    _session?.dispose();
    _session = RecitationSession(
      listener: ref.read(speechListenerProvider),
      expected: _expected,
    )..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session?.removeListener(_changed);
    _session?.dispose();
    super.dispose();
  }

  Future<void> _allowOnline() async {
    ref.read(allowOnlineSpeechProvider.notifier).set(true);
    _newSession();
    setState(() {});
    await _session!.start();
  }

  void _deviceOnly() {
    ref.read(allowOnlineSpeechProvider.notifier).set(false);
    _newSession();
    setState(() {});
  }

  void _grade(Grade grade) {
    final s = S.of(context);
    final notifier = ref.read(planProvider.notifier);
    final card = notifier.grade(widget.hadith.number, grade);
    final days = card.dueDay - notifier.today;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.nextReviewIn(days, arabicNumber(days)))),
    );
    Navigator.of(context).pop(card);
  }

  String _mistakeText(S s, Mistake m) => switch (m.kind) {
    MistakeKind.wrong => s.mistakeWrong(m.heard ?? '', m.expected),
    MistakeKind.skippedWord => s.mistakeSkippedWord(m.expected),
    MistakeKind.skippedPart => s.mistakeSkippedPart(m.expected),
    MistakeKind.extra => s.mistakeExtra(m.heard ?? '', m.expected),
    MistakeKind.extraAtEnd => s.mistakeExtraAtEnd(m.heard ?? ''),
    MistakeKind.harakat => s.mistakeHarakat(m.heard ?? '', m.expected),
  };

  String _errorText(S s, ListenError error, bool online) => switch (error) {
    ListenError.needsNetwork =>
      online ? s.reciteErrorNetwork : s.reciteErrorOffline,
    ListenError.permission => s.reciteErrorPermission,
    ListenError.noMicrophone => s.reciteErrorNoMic,
    ListenError.unavailable => s.reciteErrorUnavailable,
    ListenError.other => s.reciteErrorOther,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final session = _session!;
    final online = ref.watch(allowOnlineSpeechProvider);
    final result = session.result;
    final mistakes = session.mistakes;
    final total = _indexOfToken.whereType<int>().length;
    final done = [
      for (final i in _indexOfToken.whereType<int>())
        if (result.words[i].status != WordStatus.pending) i,
    ].length;
    final finished = result.isComplete;
    final error = session.error;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.reciteTitle(arabicNumber(widget.hadith.number))),
        actions: [
          IconButton(
            key: const ValueKey('recite-show-text'),
            tooltip: s.reciteShowText,
            isSelected: _showText,
            icon: const Icon(Icons.visibility_outlined),
            selectedIcon: const Icon(Icons.visibility),
            onPressed: () => setState(() => _showText = !_showText),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            widget.hadith.title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            s.reciteHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _RecitedMatn(
            tokens: _tokens,
            indexOfToken: _indexOfToken,
            result: result,
            hints: session.hints,
            showText: _showText,
          ),
          if (mistakes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.reciteMistakes, style: theme.textTheme.titleSmall),
            for (final m in mistakes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: m.kind == MistakeKind.harakat
                      ? Colors.orange.shade800
                      : theme.colorScheme.error,
                ),
                title: Text(_mistakeText(s, m)),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.reciteProgress(arabicNumber(done), arabicNumber(total)),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              if (session.isListening && session.heardText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  s.reciteHeard(session.heardText),
                  key: const ValueKey('recite-heard'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Card(
                  key: const ValueKey('recite-error'),
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          _errorText(s, error, online || kIsWeb),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        if (error == ListenError.needsNetwork &&
                            !online &&
                            !kIsWeb) ...[
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            key: const ValueKey('recite-allow-online'),
                            onPressed: _allowOnline,
                            child: Text(s.reciteAllowOnline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              if (finished) ...[
                Text(
                  s.reciteDone(mistakes.length, arabicNumber(mistakes.length)),
                  key: const ValueKey('recite-done'),
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(s.gradeQuestion, style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                _GradeRow(
                  suggested: suggestedGrade(mistakes.length),
                  onGrade: _grade,
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('recite-restart'),
                    tooltip: s.reciteRestart,
                    icon: const Icon(Icons.replay),
                    onPressed: done == 0 && mistakes.isEmpty
                        ? null
                        : () => session.reset(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: session.isListening
                        ? FilledButton.tonalIcon(
                            key: const ValueKey('recite-stop'),
                            onPressed: () => session.stop(),
                            icon: const Icon(Icons.stop),
                            label: Text(s.reciteStop),
                          )
                        : FilledButton.icon(
                            key: const ValueKey('recite-start'),
                            onPressed: finished ? null : () => session.start(),
                            icon: const Icon(Icons.mic),
                            label: Text(
                              done == 0 ? s.reciteStart : s.reciteContinue,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('recite-hint'),
                    tooltip: s.revealNextWord,
                    icon: const Icon(Icons.lightbulb_outline),
                    onPressed: finished ? null : () => session.hint(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _PrivacyLine(
                online: online,
                onDeviceOnly: session.isListening ? null : _deviceOnly,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Says where the voice goes, and lets the user go back to recognition on
/// the device after allowing the internet.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.online, required this.onDeviceOnly});

  final bool online;
  final VoidCallback? onDeviceOnly;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final text = kIsWeb
        ? s.recitePrivacyWeb
        : online
        ? s.recitePrivacyOnline
        : s.recitePrivacyDevice;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: style, textAlign: TextAlign.center),
        if (online && !kIsWeb)
          TextButton(
            key: const ValueKey('recite-device-only'),
            onPressed: onDeviceOnly,
            child: Text(s.reciteDeviceOnly),
          ),
      ],
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.suggested, required this.onGrade});

  final Grade suggested;
  final ValueChanged<Grade> onGrade;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        for (final (grade, label) in [
          (Grade.again, s.gradeAgain),
          (Grade.hard, s.gradeHard),
          (Grade.good, s.gradeGood),
        ]) ...[
          Expanded(
            child: grade == suggested
                ? FilledButton(
                    key: ValueKey('recite-grade-${grade.name}'),
                    onPressed: () => onGrade(grade),
                    child: Text(label),
                  )
                : OutlinedButton(
                    key: ValueKey('recite-grade-${grade.name}'),
                    onPressed: () => onGrade(grade),
                    child: Text(label),
                  ),
          ),
          if (grade != Grade.good) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// The matn as recited so far: words said show, words to come are hidden
/// (keeping their width, so the text does not jump), and mistakes show in
/// red. With [showText] the words to come show faded, to read along.
class _RecitedMatn extends StatelessWidget {
  const _RecitedMatn({
    required this.tokens,
    required this.indexOfToken,
    required this.result,
    required this.hints,
    required this.showText,
  });

  final List<MatnWord> tokens;
  final List<int?> indexOfToken;
  final RecitationResult result;
  final Set<int> hints;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = matnStyle(context);
    final hiddenStyle = style.copyWith(
      color: Colors.transparent,
      decoration: TextDecoration.underline,
      decorationColor: scheme.outline,
      decorationThickness: 2,
    );
    final fadedStyle = style.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
    );
    final wrongStyle = style.copyWith(
      color: scheme.error,
      decoration: TextDecoration.underline,
      decorationColor: scheme.error,
    );
    final harakatStyle = style.copyWith(color: Colors.orange.shade800);
    final hintStyle = style.copyWith(color: scheme.primary);
    final spans = <InlineSpan>[];
    for (var k = 0; k < tokens.length; k++) {
      final t = tokens[k];
      if (k > 0) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(text: t.prefix));
      final i = indexOfToken[k];
      if (i == null) {
        spans.add(TextSpan(text: t.core));
      } else {
        final w = result.words[i];
        final TextStyle? wordStyle;
        if (w.status == WordStatus.wrong || w.status == WordStatus.skipped) {
          wordStyle = wrongStyle;
        } else if (w.isHarakatMistake) {
          wordStyle = harakatStyle;
        } else if (w.status == WordStatus.correct) {
          wordStyle = null;
        } else if (hints.contains(i)) {
          wordStyle = hintStyle;
        } else {
          wordStyle = showText ? fadedStyle : hiddenStyle;
        }
        spans.add(TextSpan(text: t.core, style: wordStyle));
      }
      spans.add(TextSpan(text: t.suffix));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.justify,
      key: const ValueKey('recited-matn'),
    );
  }
}
