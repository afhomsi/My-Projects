import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../arabic_numbers.dart';
import '../plan/plan_controller.dart';
import '../plan/review_schedule.dart';
import 'word_hiding.dart';

/// Recite a hadith from memory: words are hidden, tap one to peek at it,
/// then grade the recitation to schedule the next review.
class MemorizeScreen extends ConsumerStatefulWidget {
  const MemorizeScreen({
    super.key,
    required this.hadith,
    this.initialLevel = HideLevel.third,
    this.seed,
  });

  final Hadith hadith;
  final HideLevel initialLevel;

  /// Fixes which words are hidden; random when null.
  final int? seed;

  @override
  ConsumerState<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends ConsumerState<MemorizeScreen> {
  late final List<MatnWord> _words = splitMatn(widget.hadith.matn);
  late HideLevel _level = widget.initialLevel;
  late int _seed = widget.seed ?? DateTime.now().microsecondsSinceEpoch;
  late Set<int> _hidden;
  final Set<int> _revealed = {};
  bool _hints = false;

  @override
  void initState() {
    super.initState();
    _hidden = pickHidden(_words, _level, _seed);
  }

  void _reset({HideLevel? level, bool reshuffle = false}) => setState(() {
    _level = level ?? _level;
    if (reshuffle) _seed++;
    _hidden = pickHidden(_words, _level, _seed);
    _revealed.clear();
  });

  void _reveal(int i) => setState(() => _revealed.add(i));

  /// Reveals the first word still hidden, in reading order.
  void _revealNext() {
    for (var i = 0; i < _words.length; i++) {
      if (_hidden.contains(i) && !_revealed.contains(i)) return _reveal(i);
    }
  }

  bool get _allShown => _hidden.every(_revealed.contains);

  void _grade(Grade grade) {
    final s = S.of(context);
    final card = ref
        .read(planProvider.notifier)
        .grade(widget.hadith.number, grade);
    final days = card.dueDay - ref.read(planProvider.notifier).today;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.nextReviewIn(days, arabicNumber(days)))),
    );
    Navigator.of(context).pop(card);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.memorizeTitle(arabicNumber(widget.hadith.number))),
        actions: [
          IconButton(
            tooltip: s.firstLetterHint,
            isSelected: _hints,
            icon: const Icon(Icons.text_fields_outlined),
            selectedIcon: const Icon(Icons.text_fields),
            onPressed: () => setState(() => _hints = !_hints),
          ),
          IconButton(
            tooltip: s.reshuffle,
            icon: const Icon(Icons.shuffle),
            onPressed: () => _reset(reshuffle: true),
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
          const SizedBox(height: 12),
          Text(s.hideLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<HideLevel>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: HideLevel.none, label: Text(s.hideNone)),
              ButtonSegment(value: HideLevel.third, label: Text(s.hideThird)),
              ButtonSegment(
                value: HideLevel.twoThirds,
                label: Text(s.hideTwoThirds),
              ),
              ButtonSegment(value: HideLevel.all, label: Text(s.hideAll)),
            ],
            selected: {_level},
            onSelectionChanged: (v) => _reset(level: v.single),
          ),
          const SizedBox(height: 8),
          Text(
            s.memorizeHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          HiddenMatn(
            words: _words,
            hidden: _hidden,
            revealed: _revealed,
            hints: _hints,
            onReveal: _reveal,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _allShown ? null : _revealNext,
                icon: const Icon(Icons.visibility_outlined),
                label: Text(s.revealNextWord),
              ),
              const SizedBox(height: 6),
              Text(s.gradeQuestion, style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final (grade, label) in [
                    (Grade.again, s.gradeAgain),
                    (Grade.hard, s.gradeHard),
                    (Grade.good, s.gradeGood),
                  ]) ...[
                    Expanded(
                      child: grade == Grade.good
                          ? FilledButton(
                              onPressed: () => _grade(grade),
                              child: Text(label),
                            )
                          : FilledButton.tonal(
                              onPressed: () => _grade(grade),
                              child: Text(label),
                            ),
                    ),
                    if (grade != Grade.good) const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The matn with some words hidden. A hidden word keeps its exact width
/// (drawn in a transparent colour over a line), so the text does not jump
/// when a word is revealed.
class HiddenMatn extends StatefulWidget {
  const HiddenMatn({
    super.key,
    required this.words,
    required this.hidden,
    required this.revealed,
    required this.hints,
    required this.onReveal,
  });

  final List<MatnWord> words;
  final Set<int> hidden;
  final Set<int> revealed;

  /// Show the first letter of each hidden word.
  final bool hints;
  final ValueChanged<int> onReveal;

  @override
  State<HiddenMatn> createState() => _HiddenMatnState();
}

class _HiddenMatnState extends State<HiddenMatn> {
  final Map<int, TapGestureRecognizer> _taps = {};

  TapGestureRecognizer _tap(int i) =>
      _taps[i] ??= TapGestureRecognizer()..onTap = () => widget.onReveal(i);

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

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
    final revealedStyle = style.copyWith(color: scheme.primary);
    final spans = <InlineSpan>[];
    for (var i = 0; i < widget.words.length; i++) {
      final w = widget.words[i];
      if (i > 0) spans.add(const TextSpan(text: ' '));
      spans.add(TextSpan(text: w.prefix));
      if (!widget.hidden.contains(i)) {
        spans.add(TextSpan(text: w.core));
      } else if (widget.revealed.contains(i)) {
        spans.add(TextSpan(text: w.core, style: revealedStyle));
      } else {
        final hint = widget.hints ? w.firstLetter : '';
        if (hint.isNotEmpty) {
          spans.add(
            TextSpan(
              text: hint,
              recognizer: _tap(i),
              style: hiddenStyle.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: hint.isEmpty ? w.core : w.rest,
            recognizer: _tap(i),
            style: hiddenStyle,
            semanticsLabel: '…',
          ),
        );
      }
      spans.add(TextSpan(text: w.suffix));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: TextAlign.justify,
      key: const ValueKey('hidden-matn'),
    );
  }
}
