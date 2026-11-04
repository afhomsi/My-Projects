import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../../recitation/recitation_session.dart';
import '../../recitation/speech_listener.dart';
import '../arabic_numbers.dart';
import '../memorize/word_hiding.dart';
import '../recitation/recite_screen.dart';
import 'quiz.dart';

/// How a question of the test went.
class QuizAnswer {
  const QuizAnswer({required this.mistakes, required this.gaveUp});

  final int mistakes;

  /// The reciter showed the answer instead of finishing.
  final bool gaveUp;

  bool get isRight => mistakes == 0 && !gaveUp;
}

/// The cue shows at most this many words of the sentence before.
const _cueWords = 10;

/// A short test: a few ahadith, each to go on reciting by voice from a
/// cue, then the result. It does not change the memorization plan.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.questions, this.onAgain});

  final List<QuizQuestion> questions;

  /// Starts another test, from the result.
  final VoidCallback? onAgain;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _at = 0;
  final _answers = <QuizAnswer>[];
  late RecitationSession _session;
  late List<MatnWord> _tokens;
  late List<int?> _indexOfToken;
  bool _revealed = false;

  QuizQuestion get _question => widget.questions[_at];

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    final q = _question;
    _tokens = splitMatn(q.hadith.matn);
    _indexOfToken = List<int?>.filled(_tokens.length, null);
    for (var i = 0; i < q.expected.length; i++) {
      final w = q.expected[i];
      if (!w.optional) _indexOfToken[w.token] = i;
    }
    _revealed = false;
    _session = RecitationSession(
      listener: ref.read(speechListenerProvider),
      expected: q.expected,
    )..addListener(_changed);
  }

  void _close() {
    _session.removeListener(_changed);
    _session.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // After the last question its session is closed already.
    if (_at < widget.questions.length) _close();
    super.dispose();
  }

  Future<void> _reveal() async {
    await _session.stop();
    setState(() => _revealed = true);
  }

  void _next() {
    _answers.add(
      QuizAnswer(mistakes: _session.mistakes.length, gaveUp: _revealed),
    );
    _close();
    setState(() {
      _at++;
      if (_at < widget.questions.length) _open();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (_at >= widget.questions.length) {
      return _QuizResult(
        questions: widget.questions,
        answers: _answers,
        onAgain: widget.onAgain,
      );
    }
    final theme = Theme.of(context);
    final q = _question;
    final session = _session;
    final finished = session.result.isComplete || _revealed;
    final online = ref.watch(allowOnlineSpeechProvider);
    final error = session.error;
    final cueTokens = q.fromStart
        ? const <MatnWord>[]
        : _tokens.sublist(q.cueFrom!, q.from);
    final cue = [
      if (cueTokens.length > _cueWords) '…',
      for (final t in cueTokens.skip(
        cueTokens.length > _cueWords ? cueTokens.length - _cueWords : 0,
      ))
        '${t.prefix}${t.core}${t.suffix}',
    ].join(' ');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.quizQuestion(
            arabicNumber(_at + 1),
            arabicNumber(widget.questions.length),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            '${s.hadithNumber(arabicNumber(q.hadith.number))}: '
            '${q.hadith.title}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            q.fromStart ? s.quizFromStart : s.quizGoOn,
            style: theme.textTheme.titleSmall,
          ),
          if (!q.fromStart) ...[
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  cue,
                  key: const ValueKey('quiz-cue'),
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.9),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          RecitedMatn(
            tokens: _tokens,
            indexOfToken: _indexOfToken,
            result: session.result,
            hints: session.hints,
            showText: _revealed,
            from: q.from,
            to: q.to,
          ),
          if (session.isListening && session.heardText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.reciteHeard(session.heardText),
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
              key: const ValueKey('quiz-error'),
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  listenErrorText(s, error, online: online || kIsWeb),
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
          if (session.mistakes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.reciteMistakes, style: theme.textTheme.titleSmall),
            for (final m in session.mistakes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(mistakeText(s, m)),
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
              if (finished)
                FilledButton(
                  key: const ValueKey('quiz-next'),
                  onPressed: _next,
                  child: Text(
                    _at + 1 < widget.questions.length
                        ? s.quizNext
                        : s.quizFinish,
                  ),
                )
              else
                Row(
                  children: [
                    TextButton(
                      key: const ValueKey('quiz-reveal'),
                      onPressed: _reveal,
                      child: Text(s.quizShowAnswer),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: session.isListening
                          ? FilledButton.tonalIcon(
                              key: const ValueKey('quiz-stop'),
                              onPressed: () => session.stop(),
                              icon: const Icon(Icons.stop),
                              label: Text(s.reciteStop),
                            )
                          : FilledButton.icon(
                              key: const ValueKey('quiz-start'),
                              onPressed: () => session.start(),
                              icon: const Icon(Icons.mic),
                              label: Text(s.reciteStart),
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('quiz-hint'),
                      tooltip: s.revealNextWord,
                      icon: const Icon(Icons.lightbulb_outline),
                      onPressed: () => session.hint(),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              PrivacyLine(online: online, onDeviceOnly: null),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({
    required this.questions,
    required this.answers,
    required this.onAgain,
  });

  final List<QuizQuestion> questions;
  final List<QuizAnswer> answers;
  final VoidCallback? onAgain;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final right = answers.where((a) => a.isRight).length;
    return Scaffold(
      appBar: AppBar(title: Text(s.quizResultTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            s.quizScore(arabicNumber(right), arabicNumber(answers.length)),
            key: const ValueKey('quiz-score'),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < answers.length; i++)
            ListTile(
              leading: Icon(
                answers[i].isRight ? Icons.check_circle : Icons.cancel,
                color: answers[i].isRight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              title: Text(
                '${s.hadithNumber(arabicNumber(questions[i].hadith.number))}: '
                '${questions[i].hadith.title}',
              ),
              subtitle: Text(
                answers[i].gaveUp
                    ? s.quizGaveUp
                    : s.quizMistakes(
                        answers[i].mistakes,
                        arabicNumber(answers[i].mistakes),
                      ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              if (onAgain != null) ...[
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('quiz-again'),
                    onPressed: onAgain,
                    child: Text(s.quizAgain),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton(
                  key: const ValueKey('quiz-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(s.quizDone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a new short test on [pool]; [replace] swaps it for the screen
/// showing, as when starting another test from a result.
void openQuiz(
  BuildContext context,
  List<Hadith> pool, {
  Random? random,
  bool replace = false,
}) {
  final rng = random ?? Random();
  final route = MaterialPageRoute<void>(
    builder: (context) => QuizScreen(
      questions: buildQuiz(pool, rng),
      onAgain: () => openQuiz(context, pool, random: rng, replace: true),
    ),
  );
  final nav = Navigator.of(context);
  replace ? nav.pushReplacement(route) : nav.push(route);
}
