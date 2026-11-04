import 'dart:math';

import 'arabic_normalizer.dart';
import 'harakat.dart';

/// How strictly a recitation is checked, chosen before reciting.
enum RecitationMode {
  /// The words and their harakat, where the recognizer writes harakat.
  strict,

  /// Only the words, forgiving small slips of the recognizer and extra
  /// words.
  lenient,
}

enum WordStatus {
  /// Not recited yet.
  pending,
  correct,

  /// Another word was said in its place.
  wrong,

  /// Left out: the reciter went on to a later word.
  skipped,
}

/// What a word to recite belongs to.
enum WordKind {
  /// A word of the matn as written.
  matn,

  /// "صلى الله عليه وسلم", written ﷺ in the matn. Saying it is good but
  /// leaving it out is not a mistake, and the sign itself stays shown.
  salawat,
}

/// One word to recite and how it was recited.
class WordResult {
  const WordResult({
    required this.word,
    required this.status,
    this.heard,
    this.extrasBefore = const [],
    this.wrongHarakat,
  });

  final ExpectedWord word;
  final WordStatus status;

  /// What was said instead, for [WordStatus.wrong].
  final String? heard;

  /// Words said just before this one that do not belong to the recitation.
  final List<String> extrasBefore;

  /// How a word said with wrong harakat was said; such a word is still
  /// [WordStatus.correct].
  final String? wrongHarakat;

  int get part => word.part;

  /// The word as written in the matn.
  String get text => word.text;

  bool get isMistake =>
      status == WordStatus.wrong ||
      status == WordStatus.skipped ||
      extrasBefore.isNotEmpty;

  bool get isHarakatMistake =>
      status == WordStatus.correct && wrongHarakat != null;
}

/// The words to recite with their status after comparing them to what was
/// heard.
class RecitationResult {
  const RecitationResult({
    required this.words,
    this.extrasAtEnd = const [],
    this.endAt,
    this.heardMatched = 0,
  });

  final List<WordResult> words;

  /// Extra words said after the last word.
  final List<String> extrasAtEnd;

  /// Where the alignment ended, when it was told; see [end].
  final int? endAt;

  /// How many of the words heard come up to the last one that matched a
  /// word to recite; the words after it matched nothing.
  final int heardMatched;

  /// Index of the word the reciter is about to say. Usually [progress],
  /// but earlier after going back to recite some words again.
  int get end => endAt ?? progress;

  /// Number of words recited so far, mistakes included.
  int get progress =>
      words.lastIndexWhere((w) => w.status != WordStatus.pending) + 1;

  bool get isComplete =>
      words.every((w) => w.status != WordStatus.pending || w.word.optional);

  int get mistakeCount =>
      words.where((w) => w.isMistake).length + (extrasAtEnd.isEmpty ? 0 : 1);

  int get harakatMistakeCount => words.where((w) => w.isHarakatMistake).length;
}

/// A word to recite, with the part of the matn it belongs to.
class ExpectedWord {
  ExpectedWord(
    this.part,
    this.text, {
    this.kind = WordKind.matn,
    this.pause = false,
    this.token = -1,
  }) : key = normalizeWord(text);

  /// Which word of the matn, split on spaces, this is; for the salawat,
  /// the sign ﷺ. Lets the screen show each word's status in the matn.
  final int token;

  /// Which part of the matn the word is in: the matn is cut into parts at
  /// the end of each sentence, which play the role of the ayat of the
  /// Quran app (a reciter who goes back starts again at most one part
  /// earlier, and a part left out whole is told as such).
  final int part;
  final String text;
  final WordKind kind;
  final String key;

  /// Whether the reciter may stop after this word: at a punctuation mark
  /// or at the end of the matn.
  final bool pause;

  bool get optional => kind != WordKind.matn;
}

/// The salawat said for the sign ﷺ.
const salawatWords = ['صلى', 'الله', 'عليه', 'وسلم'];

/// Punctuation after which a reciter may stop.
final _pauseMark = RegExp('[.،,:؛;؟?!»﴾)]\$');

/// Punctuation that ends a sentence, and so a part. Not the colon, which
/// mostly opens the words quoted after «قال».
final _partEnd = RegExp('[.؛;؟?!]["»﴾)]*\$');

/// The words of [matn] to recite, in reading order, with the sign ﷺ said
/// as optional words.
List<ExpectedWord> wordsOfMatn(String matn) {
  final words = <ExpectedWord>[];
  var part = 0;
  final tokens = [
    for (final t in matn.split(RegExp(r'\s+')))
      if (t.isNotEmpty) t,
  ];
  for (var k = 0; k < tokens.length; k++) {
    final t = tokens[k];
    final last = k == tokens.length - 1;
    if (t.contains('ﷺ')) {
      for (final w in salawatWords) {
        words.add(ExpectedWord(part, w, kind: WordKind.salawat, token: k));
      }
    } else if (normalizeWord(t).isNotEmpty) {
      words.add(
        ExpectedWord(part, t, pause: last || _pauseMark.hasMatch(t), token: k),
      );
    }
    if (_partEnd.hasMatch(t) && !last) part++;
  }
  return words;
}

/// Whether a heard word counts as the expected one. Long words may differ by
/// one letter, because recognizers often misspell a letter that was recited
/// correctly.
///
/// [RecitationMode.lenient] forgives more: one letter from four letters on
/// and two letters from eight on.
bool wordsMatch(
  String expected,
  String heard, [
  RecitationMode mode = RecitationMode.strict,
]) {
  if (expected == heard) return true;
  final shorter = min(expected.length, heard.length);
  if (mode == RecitationMode.lenient) {
    if (shorter < 4) return false;
    if (_withinOneEdit(expected, heard)) return true;
    return shorter >= 8 && _editDistance(expected, heard, 2) <= 2;
  }
  if (shorter < 5) return false;
  return _withinOneEdit(expected, heard);
}

/// The number of letters to change, add or remove to make [a] into [b],
/// or more than [limit] once it is past it.
int _editDistance(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var prev = List.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final row = List.filled(b.length + 1, i);
    var best = row[0];
    for (var j = 1; j <= b.length; j++) {
      final same = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1);
      row[j] = min(
        min(row[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (same ? 0 : 1),
      );
      best = min(best, row[j]);
    }
    if (best > limit) return limit + 1;
    prev = row;
  }
  return prev[b.length];
}

/// Whether [a] becomes [b] by changing, adding or removing at most one
/// letter. Checked letter by letter, as it runs for every pair of words
/// on each result while reciting.
bool _withinOneEdit(String a, String b) {
  if (a.length < b.length) return _withinOneEdit(b, a);
  if (a.length - b.length > 1) return false;
  var i = 0;
  while (i < b.length && a.codeUnitAt(i) == b.codeUnitAt(i)) {
    i++;
  }
  if (i == b.length) return true;
  // Past the first difference the rest must match, after skipping one
  // letter of the longer word, or one of each when the lengths are equal.
  final skipB = a.length == b.length ? 1 : 0;
  return a.substring(i + 1) == b.substring(i + skipB);
}

/// Aligns [heard] (raw recognizer words) with [expected] and reports each
/// expected word's status.
///
/// The alignment is a word-level edit distance where the unrecited end is
/// free, so stopping half way is not a mistake, and so are optional words
/// (the salawat for ﷺ). Reciting starts at word [start]; the words before
/// it are only reached by going back.
///
/// A reciter who notices a mistake usually goes back and recites again
/// from an earlier word. Going back costs a little, so it is chosen only
/// when the words said again match better than as extra words, and each
/// word keeps the status of the last time it was recited: a part recited
/// again correctly counts as right. Words not reached stay pending.
///
/// While the reciter is still speaking ([settled] false) the recognizer's
/// last words can still change, so mistakes after the last correctly
/// recited word are held back, and so are harakat mistakes in the words
/// from [start] on.
///
/// [lostAtStart] words from [start] on may have been lost by the
/// recognizer, as when it starts listening again: they are left out more
/// readily.
///
/// In [RecitationMode.strict] the harakat of words said right are
/// compared too, when the recognizer writes them. In
/// [RecitationMode.lenient] words are matched more loosely and extra
/// words are not mistakes.
RecitationResult alignRecitation(
  List<ExpectedWord> expected,
  List<String> heard, {
  bool settled = true,
  int start = 0,
  RecitationMode mode = RecitationMode.strict,
  int lostAtStart = 0,
}) {
  final h = <String>[];
  final hRaw = <String>[];
  final hAt = <int>[];
  for (var k = 0; k < heard.length; k++) {
    final key = normalizeWord(heard[k]);
    if (key.isEmpty) continue;
    h.add(key);
    hRaw.add(heard[k]);
    hAt.add(k);
  }
  // A recognizer may write a word of the matn as two, or two as one, as
  // «يا عبادي» heard as «ياعبادي»: such a pair
  // matches as one word, when the letters are the same.
  // A pair spelled together loses no letter; one that does, as «قل لا»
  // becoming «قلا», is not taken for one word.
  String? pair(String a, String b, String keyA, String keyB) {
    final key = normalizeWord(a + b);
    return key == keyA || key == keyB ? null : key;
  }

  final pairHeard = [
    for (var j = 1; j < h.length; j++)
      pair(hRaw[j - 1], hRaw[j], h[j - 1], h[j]),
  ];
  final pairExpected = [
    for (var i = 1; i < expected.length; i++)
      pair(
        expected[i - 1].text,
        expected[i].text,
        expected[i - 1].key,
        expected[i].key,
      ),
  ];
  final n = expected.length, m = h.length;
  // Costs are in tenths. An extra word costs a little less than a wrong
  // one, so when the reciter goes back after a slip, the slip is taken
  // for extra words rather than for words recited right before it said
  // wrong. Words before [start] were recited already: going back, the
  // words said again are taken for them only where they fit, so a slip or
  // a misheard word does not undo ayat recited right.
  //
  // Leaving out a run of words costs at most [jumpCost], so a reciter
  // found again a few words later is followed from there however many
  // words were lost before: the recognizer may miss words, as when it
  // restarts, and the reciter must not be left behind waiting for them.
  const wordCost = 10, extraCost = 9, goBackCost = 10;
  // The first [lostAtStart] words may have been said while the recognizer
  // was not listening: leaving them out before anything heard costs
  // less than a wrong word, but not less than a wrong word taken for an
  // extra one.
  const lostCost = 4;
  const jumpCost = 3 * wordCost;
  int skipCost(int i) =>
      expected[i].optional ? 0 : (i < start ? 2 * wordCost : wordCost);
  int wrongCost(int i) => i < start ? 2 * wordCost : wordCost;
  const unreachable = 1 << 30;

  // cost[j][i]: best cost of having said heard[0, j) and being about to
  // recite expected[i]. step[j][i] is how that state was reached, and
  // from[j][i] where from, for going back.
  final cost = List.generate(m + 1, (_) => List.filled(n + 1, unreachable));
  final step = List.generate(m + 1, (_) => List.filled(n + 1, _Step.none));
  final from = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var j = 0; j <= m; j++) {
    final c = cost[j], s = step[j];
    if (j == 0) {
      c[start] = 0;
    } else {
      final prev = cost[j - 1];
      for (var i = 0; i <= n; i++) {
        const extra = extraCost;
        if (prev[i] + extra < c[i]) {
          c[i] = prev[i] + extra;
          s[i] = _Step.extra;
        }
        if (i > 0) {
          final d =
              prev[i - 1] +
              (wordsMatch(expected[i - 1].key, h[j - 1], mode)
                  ? 0
                  : wrongCost(i - 1));
          if (d <= c[i]) {
            c[i] = d;
            s[i] = _Step.word;
          }
          if (j > 1 &&
              cost[j - 2][i - 1] < c[i] &&
              expected[i - 1].key == pairHeard[j - 2]) {
            c[i] = cost[j - 2][i - 1];
            s[i] = _Step.pairHeard;
          }
          if (i > 1 &&
              !expected[i - 2].optional &&
              prev[i - 2] < c[i] &&
              pairExpected[i - 2] == h[j - 1]) {
            c[i] = prev[i - 2];
            s[i] = _Step.pairExpected;
          }
        }
      }
    }
    void skipForward() {
      var jumpBest = unreachable, jumpAt = 0;
      for (var i = 1; i <= n; i++) {
        if (i - 1 >= start && c[i - 1] < jumpBest) {
          jumpBest = c[i - 1];
          jumpAt = i - 1;
        }
        final d =
            c[i - 1] +
            (j == 0 && i - 1 - start < lostAtStart && !expected[i - 1].optional
                ? lostCost
                : skipCost(i - 1));
        if (d < c[i]) {
          c[i] = d;
          s[i] = _Step.skip;
        }
        if (jumpBest + jumpCost < c[i]) {
          c[i] = jumpBest + jumpCost;
          s[i] = _Step.jump;
          from[j][i] = jumpAt;
        }
      }
    }

    skipForward();
    // Going back to any earlier word, from the best state after it; not
    // to an optional word.
    var best = unreachable, bestAt = n;
    for (var k = n; k >= 0; k--) {
      if (best + goBackCost < c[k] && (k == n || !expected[k].optional)) {
        c[k] = best + goBackCost;
        s[k] = _Step.back;
        from[j][k] = bestAt;
      }
      if (c[k] < best && s[k] != _Step.back) {
        best = c[k];
        bestAt = k;
      }
    }
    skipForward();
  }

  // Everything heard is used; the later end wins also over one costing
  // an extra word less, so a wrong last word is reported as wrong rather
  // than as extra.
  var best = 0;
  for (var i = 1; i <= n; i++) {
    if (cost[m][i] < cost[m][best]) best = i;
  }
  var end = 0;
  for (var i = 0; i <= n; i++) {
    if (cost[m][i] <= cost[m][best] + wordCost - extraCost) end = i;
  }
  // Optional words not said yet are still ahead, not passed.
  while (end > 0 && step[m][end] == _Step.skip && expected[end - 1].optional) {
    end--;
  }

  // Walking back from the end, the first time a word is met is the last
  // time it was recited. Each going back starts an earlier attempt; extra
  // words count only within the attempt that recited the word after them.
  final status = List.filled(n, WordStatus.pending);
  final said = List<String?>.filled(n, null);
  final harakat = List<String?>.filled(n, null);
  final extras = List.generate(n + 1, (_) => <String>[]);
  final attemptOf = List.filled(n + 1, -1);
  var attempt = 0;
  var heardMatched = 0;
  var i = end, j = m;
  while (true) {
    switch (step[j][i]) {
      case _Step.none:
        break;
      case _Step.word:
        if (heardMatched == 0 &&
            wordsMatch(expected[i - 1].key, h[j - 1], mode)) {
          heardMatched = hAt[j - 1] + 1;
        }
        if (attemptOf[i - 1] < 0) {
          attemptOf[i - 1] = attempt;
          final e = expected[i - 1];
          final match = wordsMatch(e.key, h[j - 1], mode);
          status[i - 1] = match ? WordStatus.correct : WordStatus.wrong;
          if (!match) {
            said[i - 1] = hRaw[j - 1];
          } else if (mode == RecitationMode.strict &&
              e.kind == WordKind.matn &&
              (settled || i - 1 < start) &&
              e.key == h[j - 1] &&
              harakatDiffer(e.text, hRaw[j - 1], pause: e.pause)) {
            harakat[i - 1] = hRaw[j - 1];
          }
        }
        i--;
        j--;
        continue;
      case _Step.pairHeard:
        if (heardMatched == 0) heardMatched = hAt[j - 1] + 1;
        if (attemptOf[i - 1] < 0) {
          attemptOf[i - 1] = attempt;
          status[i - 1] = WordStatus.correct;
        }
        i--;
        j -= 2;
        continue;
      case _Step.pairExpected:
        if (heardMatched == 0) heardMatched = hAt[j - 1] + 1;
        for (final k in [i - 1, i - 2]) {
          if (attemptOf[k] >= 0) continue;
          attemptOf[k] = attempt;
          status[k] = WordStatus.correct;
        }
        i -= 2;
        j--;
        continue;
      case _Step.skip:
        if (attemptOf[i - 1] < 0) {
          attemptOf[i - 1] = attempt;
          if (!expected[i - 1].optional) status[i - 1] = WordStatus.skipped;
        }
        i--;
        continue;
      case _Step.jump:
        for (var k = i - 1; k >= from[j][i]; k--) {
          if (attemptOf[k] >= 0) continue;
          attemptOf[k] = attempt;
          if (!expected[k].optional) status[k] = WordStatus.skipped;
        }
        i = from[j][i];
        continue;
      case _Step.extra:
        if (attemptOf[i] == attempt || (attempt == 0 && i == end)) {
          extras[i].insert(0, hRaw[j - 1]);
        }
        j--;
        continue;
      case _Step.back:
        i = from[j][i];
        attempt++;
        continue;
    }
    break;
  }

  // Optional words that were not said stay pending, also before the
  // current position.
  for (var k = 0; k < n; k++) {
    if (expected[k].optional && status[k] == WordStatus.wrong) {
      // A wrong word in place of an optional one is an extra word before
      // the next word.
      extras[k + 1].insert(0, said[k]!);
      status[k] = WordStatus.pending;
      said[k] = null;
      extras[k + 1].insertAll(0, extras[k]);
      extras[k].clear();
    }
  }

  if (!settled) {
    final lastCorrect = status.lastIndexOf(WordStatus.correct);
    for (var k = lastCorrect + 1; k < n; k++) {
      status[k] = WordStatus.pending;
      said[k] = null;
      extras[k].clear();
    }
    extras[n].clear();
  }

  if (mode == RecitationMode.lenient) {
    for (final e in extras) {
      e.clear();
    }
  }

  return RecitationResult(
    words: [
      for (var k = 0; k < n; k++)
        WordResult(
          word: expected[k],
          status: status[k],
          heard: said[k],
          extrasBefore: extras[k],
          wrongHarakat: harakat[k],
        ),
    ],
    extrasAtEnd: extras[n],
    endAt: end,
    heardMatched: heardMatched,
  );
}

enum _Step {
  none,
  word,

  /// Two words heard for one word to recite.
  pairHeard,

  /// One word heard for two words to recite.
  pairExpected,
  skip,
  jump,
  extra,
  back,
}
