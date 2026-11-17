import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/hadith.dart';
import '../../l10n/app_localizations.dart';
import '../../recitation/recitation_matcher.dart';
import '../../recitation/recitation_session.dart';
import '../../recitation/speech_listener.dart';
import '../arabic_numbers.dart';
import '../memorize/word_hiding.dart';
import '../plan/plan_controller.dart';
import '../recitation/recite_screen.dart';
import 'guided_steps.dart';

/// Where the reciter got to in memorizing [hadith] by voice, by [scope].
String guidedKey(int hadith, ReciteScope scope) =>
    'guided.$hadith.${scope.name}';

/// How the last recited step went.
enum _Outcome { passed, failed, easier }

/// Memorizing a hadith by voice, step by step (see [guidedSteps]): each
/// step listens to one sentence or two, shows the words as they are said,
/// and goes on only when they were said without a mistake.
class GuidedScreen extends ConsumerStatefulWidget {
  const GuidedScreen({
    super.key,
    required this.hadith,
    this.scope = ReciteScope.full,
  });

  final Hadith hadith;
  final ReciteScope scope;

  @override
  ConsumerState<GuidedScreen> createState() => _GuidedScreenState();
}

class _GuidedScreenState extends ConsumerState<GuidedScreen> {
  late final List<MatnWord> _tokens = splitMatn(widget.hadith.matn);
  late final List<ExpectedWord> _all = wordsOfMatn(
    widget.hadith.matn,
    scope: widget.scope,
  );
  late final GuidedProgress _progress = GuidedProgress(
    guidedSteps(_all),
    at:
        ref
            .read(sharedPreferencesProvider)
            .getInt(guidedKey(widget.hadith.number, widget.scope)) ??
        0,
  );
  late final int _units = unitsOf(_all).length;

  /// The step being recited and its words.
  late GuidedStep _step;
  late List<ExpectedWord> _expected;
  late List<int?> _indexOfToken;
  late int _from, _to;
  late Set<int> _shown;
  RecitationSession? _session;
  _Outcome? _outcome;

  /// Whether the step is being stopped and checked.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    if (!_progress.isDone) _open();
  }

  void _open() {
    _session?.removeListener(_changed);
    _session?.dispose();
    _outcome = null;
    _finishing = false;
    _step = _progress.current;
    _expected = _step.wordsOf(_all);
    _indexOfToken = List<int?>.filled(_tokens.length, null);
    for (var i = 0; i < _expected.length; i++) {
      final w = _expected[i];
      if (!w.optional) _indexOfToken[w.token] = i;
    }
    _from = _expected.first.token;
    _to = _expected.last.token + 1;
    // The same words stay hidden as more are hidden, as the seed is the
    // same for a unit.
    final range = _tokens.sublist(_from, _to);
    final hidden = pickHidden(
      range,
      _step.level,
      widget.hadith.number * 100 + _step.unit,
    ).map((k) => k + _from).toSet();
    _shown = {
      for (var k = _from; k < _to; k++)
        if (!hidden.contains(k)) k,
    };
    _session = RecitationSession(
      listener: ref.read(speechListenerProvider),
      expected: _expected,
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    final session = _session!;
    // The session stops listening by itself once every word was said.
    if (_outcome == null && !_finishing && session.result.isComplete) {
      _finish();
    }
    setState(() {});
  }

  Future<void> _finish() async {
    final session = _session!;
    // Later results must not finish the step again while stopping.
    _finishing = true;
    await session.stop();
    final mistakes = session.mistakes.where(
      (m) => m.kind != MistakeKind.harakat,
    );
    if (mistakes.isEmpty) {
      _progress.pass();
      _outcome = _Outcome.passed;
    } else {
      _outcome = _progress.fail() ? _Outcome.easier : _Outcome.failed;
    }
    _finishing = false;
    _save();
    if (mounted) setState(() {});
  }

  void _save() => ref
      .read(sharedPreferencesProvider)
      .setInt(guidedKey(widget.hadith.number, widget.scope), _progress.at);

  Future<void> _go() async {
    if (_progress.isDone) {
      setState(() => _outcome = null);
      return;
    }
    setState(_open);
    await _session!.start();
  }

  void _startOver() {
    _progress
      ..at = 0
      ..failures = 0;
    _save();
    setState(_open);
  }

  Future<void> _allowOnline() async {
    ref.read(allowOnlineSpeechProvider.notifier).set(true);
    setState(_open);
    await _session!.start();
  }

  void _deviceOnly() {
    ref.read(allowOnlineSpeechProvider.notifier).set(false);
    setState(_open);
  }

  @override
  void dispose() {
    _session?.removeListener(_changed);
    _session?.dispose();
    super.dispose();
  }

  String _stageText(S s) => switch ((_step.kind, _step.level)) {
    (GuidedStepKind.whole, _) => s.guidedStageWhole,
    (GuidedStepKind.link, _) => s.guidedStageLink,
    (_, HideLevel.none) => s.guidedStageRead,
    (_, HideLevel.third) => s.guidedStageThird,
    (_, HideLevel.twoThirds) => s.guidedStageTwoThirds,
    (_, HideLevel.all) => s.guidedStageAll,
  };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final title = Text(s.guidedTitle(arabicNumber(widget.hadith.number)));
    if (_progress.isDone && _outcome == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: _Done(
          onRecite: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ReciteScreen(hadith: widget.hadith, scope: widget.scope),
            ),
          ),
          onStartOver: _startOver,
        ),
      );
    }
    final theme = Theme.of(context);
    final session = _session!;
    final online = ref.watch(allowOnlineSpeechProvider);
    final error = session.error;
    final steps = _progress.steps.length;
    final stepNumber = _progress.steps.indexOf(_step) + 1;
    final mistakes = session.mistakes;
    final outcome = _outcome;
    final finishing = _finishing;
    return Scaffold(
      appBar: AppBar(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          LinearProgressIndicator(
            value: _progress.at / steps,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.guidedStep(arabicNumber(stepNumber), arabicNumber(steps))}'
            ' · '
            '${s.guidedUnit(arabicNumber(_step.unit + 1), arabicNumber(_units))}',
            key: const ValueKey('guided-step'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _stageText(s),
            key: const ValueKey('guided-stage'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          if (stepNumber == 1 && outcome == null) ...[
            const SizedBox(height: 8),
            Text(
              s.guidedHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          RecitedMatn(
            key: const ValueKey('guided-matn'),
            tokens: _tokens,
            indexOfToken: _indexOfToken,
            result: session.result,
            hints: session.hints,
            showText: false,
            from: _from,
            to: _to,
            shownTokens: _shown,
            muteUnrecited: widget.scope == ReciteScope.prophetWords,
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
              if (session.isListening && session.heardText.isNotEmpty)
                Text(
                  s.reciteHeard(session.heardText),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          listenErrorText(s, error, online: online || kIsWeb),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        if (error == ListenError.needsNetwork &&
                            !online &&
                            !kIsWeb) ...[
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: _allowOnline,
                            child: Text(s.reciteAllowOnline),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (outcome != null) ...[
                const SizedBox(height: 6),
                Text(
                  switch (outcome) {
                    _Outcome.passed => s.guidedPassed,
                    _Outcome.failed => s.guidedFailed,
                    _Outcome.easier => s.guidedEasier,
                  },
                  key: const ValueKey('guided-outcome'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: outcome == _Outcome.passed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('guided-restart'),
                    tooltip: s.reciteRestart,
                    icon: const Icon(Icons.replay),
                    onPressed: outcome != null || finishing
                        ? null
                        : () => session.reset(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _mainButton(s, session, outcome, finishing)),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey('guided-hint'),
                    tooltip: s.revealNextWord,
                    icon: const Icon(Icons.lightbulb_outline),
                    onPressed: outcome != null || finishing
                        ? null
                        : () => session.hint(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              PrivacyLine(
                online: online,
                onDeviceOnly: session.isListening ? null : _deviceOnly,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainButton(
    S s,
    RecitationSession session,
    _Outcome? outcome,
    bool finishing,
  ) {
    if (finishing) {
      return const FilledButton(onPressed: null, child: SizedBox.shrink());
    }
    if (outcome != null) {
      final passed = outcome == _Outcome.passed;
      return FilledButton.icon(
        key: const ValueKey('guided-go'),
        onPressed: _go,
        icon: Icon(passed ? Icons.arrow_back : Icons.replay),
        label: Text(passed ? s.guidedNext : s.guidedRetry),
      );
    }
    if (session.isListening) {
      return FilledButton.tonalIcon(
        key: const ValueKey('guided-stop'),
        onPressed: () => session.stop(),
        icon: const Icon(Icons.stop),
        label: Text(s.reciteStop),
      );
    }
    final started = session.result.progress > 0;
    return FilledButton.icon(
      key: const ValueKey('guided-start'),
      onPressed: () => session.start(),
      icon: const Icon(Icons.mic),
      label: Text(started ? s.reciteContinue : s.reciteStart),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.onRecite, required this.onStartOver});

  final VoidCallback onRecite;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              s.guidedDone,
              key: const ValueKey('guided-done'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('guided-recite-now'),
              onPressed: onRecite,
              icon: const Icon(Icons.mic),
              label: Text(s.guidedReciteNow),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('guided-start-over'),
              onPressed: onStartOver,
              child: Text(s.guidedStartOver),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks what to recite (see [chooseReciteScope]), then opens memorizing
/// by voice step by step.
Future<void> openGuided(BuildContext context, Hadith hadith) async {
  final scope = await chooseReciteScope(context, hadith);
  if (scope == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GuidedScreen(hadith: hadith, scope: scope),
    ),
  );
}
