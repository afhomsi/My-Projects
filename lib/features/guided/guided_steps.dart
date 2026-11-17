import '../../recitation/recitation_matcher.dart';
import '../memorize/word_hiding.dart';

/// A sentence shorter than this many words is learnt together with the
/// next one (or, at the end, with the one before), so no step is a
/// couple of words.
const minUnitWords = 5;

/// Failing a step this many times in a row shows more of the text.
const failuresBeforeEasier = 2;

/// One step of memorizing by voice: recite the words [from] up to, not
/// including, [to] of the matn with [level] of them hidden.
///
/// The flow follows the "memorize" mode of open-source Quran apps such as
/// Quranm (based on Tilawa): read a short unit aloud with the text in
/// front of you, then recite it with more and more of it hidden, then link
/// it with the unit before, and finish with the whole text from memory.
class GuidedStep {
  const GuidedStep({
    required this.unit,
    required this.from,
    required this.to,
    required this.level,
    this.kind = GuidedStepKind.learn,
  });

  /// Which unit (a sentence or a few short ones) this step is on; for a
  /// link, the later of the two units.
  final int unit;
  final int from;
  final int to;
  final HideLevel level;
  final GuidedStepKind kind;

  /// The words of [all] that this step recites.
  List<ExpectedWord> wordsOf(List<ExpectedWord> all) => all.sublist(from, to);

  @override
  bool operator ==(Object other) =>
      other is GuidedStep &&
      other.unit == unit &&
      other.from == from &&
      other.to == to &&
      other.level == level &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(unit, from, to, level, kind);

  @override
  String toString() => 'GuidedStep($kind, unit $unit, words $from-$to, $level)';
}

enum GuidedStepKind {
  /// Learning one unit, from reading it to reciting it from memory.
  learn,

  /// Reciting a unit together with the one before it, from memory.
  link,

  /// Reciting the whole text from memory.
  whole,
}

/// A unit ends at a comma or a colon once it has this many words; at the
/// end of a sentence once it has [minUnitWords].
const unitWordsAtPause = 8;

/// Cuts [words] into units to learn one at a time: a unit ends at the end
/// of a sentence once it has at least [minUnitWords] words, or at a comma
/// or colon once it has [unitWordsAtPause], so a long sentence such as
/// the first of hadith 1 is learnt in pieces. Returns each unit's first
/// word and the word after its last, as indexes in [words].
List<(int, int)> unitsOf(List<ExpectedWord> words) {
  if (words.isEmpty) return const [];
  final units = <(int, int)>[];
  var from = 0, size = 0;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (!w.optional) size++;
    final partEnd = i + 1 < words.length && words[i + 1].part != w.part;
    if ((partEnd && size >= minUnitWords) ||
        (w.pause && size >= unitWordsAtPause)) {
      units.add((from, i + 1));
      from = i + 1;
      size = 0;
    }
  }
  if (from < words.length) {
    // A short end goes with the unit before it.
    if (units.isEmpty || size >= minUnitWords) {
      units.add((from, words.length));
    } else {
      units.last = (units.last.$1, words.length);
    }
  }
  return units;
}

/// The steps to memorize [words] by voice: for each unit, read it with the
/// text shown, then with a third, two thirds and all of it hidden; from
/// the second unit on, link it with the one before; and when there are
/// more than two units, end with the whole text from memory.
List<GuidedStep> guidedSteps(List<ExpectedWord> words) {
  final units = unitsOf(words);
  final steps = <GuidedStep>[];
  for (var u = 0; u < units.length; u++) {
    final (from, to) = units[u];
    for (final level in HideLevel.values) {
      steps.add(GuidedStep(unit: u, from: from, to: to, level: level));
    }
    if (u > 0) {
      steps.add(
        GuidedStep(
          unit: u,
          from: units[u - 1].$1,
          to: to,
          level: HideLevel.all,
          kind: GuidedStepKind.link,
        ),
      );
    }
  }
  if (units.length > 2) {
    steps.add(
      GuidedStep(
        unit: units.length - 1,
        from: 0,
        to: words.length,
        level: HideLevel.all,
        kind: GuidedStepKind.whole,
      ),
    );
  }
  return steps;
}

/// Where the reciter is in [steps], and what a pass or a failure does.
class GuidedProgress {
  GuidedProgress(this.steps, {int at = 0})
    : at = at.clamp(0, steps.length).toInt();

  final List<GuidedStep> steps;

  /// Index of the current step; [steps.length] once all are done.
  int at;

  /// Failures in a row on the current step.
  int failures = 0;

  bool get isDone => at >= steps.length;
  GuidedStep get current => steps[at];

  /// The step was recited without a mistake: go on to the next one.
  void pass() {
    if (isDone) return;
    at++;
    failures = 0;
  }

  /// The step had mistakes. After [failuresBeforeEasier] in a row on a
  /// unit being learnt with some words hidden, go back one step, so more
  /// of the text shows. Returns whether it went back.
  bool fail() {
    if (isDone) return false;
    failures++;
    if (failures < failuresBeforeEasier) return false;
    final step = current;
    if (step.kind != GuidedStepKind.learn || step.level == HideLevel.none) {
      return false;
    }
    at--;
    failures = 0;
    return true;
  }
}
