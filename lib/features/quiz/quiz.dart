import 'dart:math';

import '../../data/hadith.dart';
import '../../recitation/recitation_matcher.dart';

/// How many questions a short test asks.
const quizLength = 3;

/// A question asks for at least this many words of the matn, so it is
/// never a single short sentence.
const quizMinWords = 12;

/// One question of the short test: the reciter is shown where to start
/// and says the words of the matn from token [from] up to [to] by voice.
class QuizQuestion {
  const QuizQuestion({
    required this.hadith,
    required this.from,
    required this.to,
    required this.expected,
    this.cueFrom,
  });

  final Hadith hadith;

  /// The words of the matn (split on spaces) to recite: from [from] up to,
  /// not including, [to].
  final int from;
  final int to;

  /// The words to recite, for the recitation session, after the cue's
  /// words as optional ones.
  final List<ExpectedWord> expected;

  /// Where the cue starts: the sentence before [from] is shown to say
  /// where to go on from. Null when reciting from the start of the hadith,
  /// when its title is the cue.
  final int? cueFrom;

  bool get fromStart => cueFrom == null;
}

/// Makes a question on [hadith] starting at a part chosen with [random].
QuizQuestion questionOn(Hadith hadith, Random random) {
  final words = wordsOfMatn(hadith.matn);
  final parts = words.last.part + 1;
  // A start late in the hadith would leave too little to recite: start
  // only where at least [quizMinWords] words follow, or at the start.
  final starts = [
    for (var p = 0; p < parts; p++)
      if (p == 0 ||
          words.where((w) => w.part >= p && !w.optional).length >= quizMinWords)
        p,
  ];
  final start = starts[random.nextInt(starts.length)];
  // Take whole parts from there until there are enough words.
  final expected = <ExpectedWord>[];
  var count = 0;
  for (var p = start; p < parts && count < quizMinWords; p++) {
    final part = [
      for (final w in words)
        if (w.part == p) w,
    ];
    expected.addAll(part);
    count += part.where((w) => !w.optional).length;
  }
  final cue = [
    for (final w in words)
      if (w.part == start - 1)
        ExpectedWord(w.part, w.text, kind: WordKind.cue, token: w.token),
  ];
  return QuizQuestion(
    hadith: hadith,
    from: expected.first.token,
    to: expected.last.token + 1,
    // Saying the cue again before going on is not a mistake.
    expected: [...cue, ...expected],
    cueFrom: cue.isEmpty ? null : cue.first.token,
  );
}

/// A short test of [quizLength] questions on different ahadith of [pool],
/// chosen with [random].
List<QuizQuestion> buildQuiz(List<Hadith> pool, Random random) {
  final chosen = [...pool]..shuffle(random);
  return [for (final h in chosen.take(quizLength)) questionOn(h, random)];
}
