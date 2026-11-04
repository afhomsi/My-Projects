import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'arabic_normalizer.dart';
import 'harakat.dart';
import 'recitation_matcher.dart';
import 'speech_listener.dart';

/// What kind of mistake a reciter made.
enum MistakeKind {
  /// Another word said in place of [Mistake.expected].
  wrong,

  /// The word [Mistake.expected] left out.
  skippedWord,

  /// A whole part of the matn left out; [Mistake.expected] is its start.
  skippedPart,

  /// Words [Mistake.heard] added before [Mistake.expected].
  extra,

  /// Words [Mistake.heard] added after the end.
  extraAtEnd,

  /// The right word with a wrong haraka: shown in orange.
  harakat,
}

/// A mistake found while reciting, to alert the reciter about. The screen
/// turns it into words.
class Mistake {
  const Mistake(this.wordIndex, this.kind, {this.expected = '', this.heard});

  /// Index of the word the mistake is at.
  final int wordIndex;
  final MistakeKind kind;

  /// The word of the matn, as written.
  final String expected;

  /// What was said instead, or the words added.
  final String? heard;
}

/// Why listening cannot go on.
enum ListenError {
  /// No recognizer, or the microphone was refused when asked.
  unavailable,

  /// The microphone was refused.
  permission,

  /// No microphone found.
  noMicrophone,

  /// The recognizer needs the internet, or the Arabic language for
  /// recognition on the device is not installed.
  needsNetwork,

  /// Anything else.
  other,
}

/// The kind of [message], an error a recognizer sent.
ListenError listenErrorKind(String message) {
  if (message.contains('not-allowed') || message.contains('permission')) {
    return ListenError.permission;
  }
  if (message.contains('audio-capture') || message.contains('error_audio')) {
    return ListenError.noMicrophone;
  }
  if (message.contains('network') ||
      message.contains('language') ||
      message.contains('server')) {
    return ListenError.needsNetwork;
  }
  return ListenError.other;
}

/// Whether a recognizer's result [words] starts its text over, after the
/// result [last] of the same listening session, as Google's recognizer on
/// Android does after a pause: it is shorter, not the start of it and
/// shares less than half of it, or as long or shorter, of two words or
/// more, and none of its words is like the one in its place.
bool startsOver(List<String> words, List<String> last) {
  if (words.length > last.length) return false;
  if (words.isEmpty) return last.length >= 3;
  var allOther = true;
  var same = 0;
  while (same < words.length && words[same] == last[same]) {
    same++;
  }
  for (var i = 0; i < words.length; i++) {
    if (_alike(words[i], last[i])) allOther = false;
  }
  if (words.length < last.length &&
      same < words.length &&
      2 * same < last.length) {
    return true;
  }
  return allOther && words.length >= 2;
}

/// Whether two words heard may be the same word written two ways, or
/// one of them cut short.
bool _alike(String a, String b) {
  final x = normalizeWord(a), y = normalizeWord(b);
  return x.startsWith(y) ||
      y.startsWith(x) ||
      wordsMatch(x, y, RecitationMode.lenient);
}

/// Listens to the reciter and keeps the comparison with the text up to
/// date. Ported from the Quran app, where the parts of the matn here are
/// ayat there.
///
/// Recognizers stop after a pause, so listening restarts by itself until the
/// reciter presses stop. Each finished listening session is compared once,
/// from where the previous one ended, so long ahadith stay fast. Within a
/// long session, the words the recognizer has stopped changing are settled
/// the same way, so each new result compares only the last few words and
/// the page keeps up with the reciter.
class RecitationSession extends ChangeNotifier {
  RecitationSession({
    required this.listener,
    required List<ExpectedWord> expected,
    this.mode = RecitationMode.strict,
  }) : expected = [...expected] {
    _clear();
  }

  final SpeechListener listener;

  /// The words to recite.
  final List<ExpectedWord> expected;

  /// How strictly the recitation is checked.
  final RecitationMode mode;

  /// Words compared so far, from finished listening sessions.
  late List<WordResult> _base;
  final _extrasAtEnd = <String>[];

  /// Index of the first word not reached by a finished session.
  int _pos = 0;

  final _committed = <String>[];
  String _current = '';

  /// How many words at the start of the current session are settled.
  int _frozen = 0;

  /// The words of the session's previous result.
  List<String> _lastHeard = const [];
  int _sessionId = 0;
  bool _initialized = false;
  bool _wantListening = false;
  bool _restartPending = false;

  /// Runs when the recognizer has sent nothing new for [quietDelay].
  Timer? _quiet;

  /// How long the last words may stay the same before a mistake in them
  /// is reported. Until then the recognizer may still correct them; after
  /// it, the reciter has likely stopped at the mistake. A recognizer that
  /// sends results seldom, as the offline model, waits longer; see
  /// [quietDelayOf].
  static const quietDelay = quickQuietDelay;
  final _alerted = <String>{};
  final _mistakes = <Mistake>[];
  late RecitationResult _result;

  /// Whether the recognizer wrote harakat, so they could be checked.
  bool heardHarakat = false;

  /// Why the microphone or recognizer cannot be used, shown by the screen.
  ListenError? error;

  /// Called once for each new mistake.
  void Function(Mistake mistake)? onMistake;

  RecitationResult get result => _result;

  /// The words settled so far, leaving out the recognizer's last words,
  /// which it may still change: a recognizer guessing ahead of the
  /// reciter, as Whisper may, then takes those words back.
  RecitationResult get settledResult =>
      RecitationResult(words: _base, endAt: _pos);

  /// Where the reciter stopped last, as the end of [result] once the
  /// recognizer sent nothing new for a while: the reciter paused there,
  /// so the words up to it are no recognizer's guess ahead. The page may
  /// turn to it, though the last words are not settled yet.
  int get pausedEnd => _pausedEnd;
  int _pausedEnd = 0;

  bool get isListening => _wantListening;
  List<Mistake> get mistakes => List.unmodifiable(_mistakes);

  /// The words shown by [hint], as indexes in [result]'s words.
  Set<int> get hints => Set.unmodifiable(_hints);
  final Set<int> _hints = {};

  /// Shows the word the reciter is stuck on: the next word to recite
  /// after the last one said, right or wrong, even when it starts the next
  /// part. A word said wrong already shows, in red, so it is not shown
  /// again. Each press shows one more word, never one before where the
  /// reciter is. Returns false when nothing is left to show.
  bool hint() {
    final words = _result.words;
    var i = _result.end;
    while (i < words.length &&
        (words[i].word.optional ||
            words[i].status != WordStatus.pending ||
            _hints.contains(i))) {
      i++;
    }
    if (i >= words.length) return false;
    _hints.add(i);
    notifyListeners();
    return true;
  }

  /// The last words heard, for showing to the reciter.
  String get heardText {
    final words = [..._committed, _current].join(' ').trim().split(' ');
    return words.skip(words.length > 20 ? words.length - 20 : 0).join(' ');
  }

  Future<void> start() async {
    error = null;
    if (!_initialized) {
      final ok = await listener.initialize(
        onError: _onError,
        onDone: _onSessionDone,
      );
      if (!ok) {
        error = ListenError.unavailable;
        notifyListeners();
        return;
      }
      _initialized = true;
    }
    _wantListening = true;
    notifyListeners();
    await _listen();
  }

  Future<void> stop() async {
    _wantListening = false;
    _commit();
    _update(settled: true);
    await listener.stop();
  }

  /// Clears everything heard, to recite again from the start.
  Future<void> reset() async {
    if (_wantListening) await stop();
    _clear();
    _alerted.clear();
    _mistakes.clear();
    _hints.clear();
    error = null;
    _update();
  }

  Future<void> _listen() async {
    final id = ++_sessionId;
    _startedAgain = true;
    try {
      await listener.listen(
        onResult: (text, isFinal) {
          if (id != _sessionId) return;
          if (!heardHarakat && hasHarakat(text)) heardHarakat = true;
          final words = _wordsOf(text);
          _startSegmentIfNew(words);
          if (!isFinal) _freezeStable(text);
          final kept = !isFinal && _isStartOfLast(words) ? _lastHeard : words;
          _current = kept.skip(_frozen).join(' ');
          if (isFinal) _commit();
          _update();
          _quiet?.cancel();
          if (!isFinal) {
            _quiet = Timer(quietDelayOf(listener), () {
              if (id != _sessionId) return;
              _update(settled: true);
              if (_result.end > _pausedEnd) {
                _pausedEnd = _result.end;
                notifyListeners();
              }
            });
          }
          if (isFinal) _restart();
        },
      );
    } catch (e) {
      _onError('$e');
    }
  }

  void _clear() {
    _pausedEnd = 0;
    _committed.clear();
    _current = '';
    _frozen = 0;
    _lastHeard = const [];
    _base = [
      for (final w in expected) WordResult(word: w, status: WordStatus.pending),
    ];
    _extrasAtEnd.clear();
    _pos = 0;
    _result = RecitationResult(words: _base);
  }

  static List<String> _wordsOf(String text) => [
    for (final w in text.trim().split(RegExp(r'\s+')))
      if (w.isNotEmpty) w,
  ];

  /// Words this far from the end of a result may still change.
  static const _liveWords = 8;

  /// Words further than this from the end are settled even when the
  /// recognizer still changes them, so the words open to compare stay
  /// few however long the reciter recites without a pause.
  static const _maxLiveWords = 3 * _liveWords;

  /// Settles the start of the session's text once enough words of it came
  /// back unchanged in two results in a row, keeping the last
  /// [_liveWords] open. Only the words after those settled already are
  /// compared: a recognizer that rewrites a word it heard long ago must
  /// not keep the rest open.
  void _freezeStable(String text) {
    final words = _wordsOf(text);
    var same = _frozen;
    while (same < words.length &&
        same < _lastHeard.length &&
        words[same] == _lastHeard[same]) {
      same++;
    }
    // A result shorter than the last and starting the same may be the
    // start of a new segment; the last is kept to tell.
    if (_isStartOfLast(words)) return;
    _lastHeard = words;
    var upTo = max(
      min(same, words.length - _liveWords),
      words.length - _maxLiveWords,
    );
    if (upTo - _frozen < _liveWords) return;
    // Words after the last one found in the text may be someone else
    // speaking, or the start of a word the next result completes; they
    // stay open to be compared with the words that follow them.
    final forced = words.length - _maxLiveWords;
    final (_, sub) = _alignFromPos(
      words.sublist(_frozen, upTo).join(' '),
      settled: true,
    );
    upTo = max(_frozen + sub.heardMatched, forced);
    if (upTo <= _frozen) return;
    _settle(words.sublist(_frozen, upTo).join(' '));
    _frozen = upTo;
  }

  /// Some recognizers, as Google's on Android, start over after a pause
  /// within one listening session: the next results hold only the words
  /// said since. What was heard before is then kept, and the new words are
  /// compared from where it ended, so the ayat recited do not hide again.
  ///
  /// A new start is a result shorter than the last one that differs from
  /// its start (see [startsOver]): after a short part the last may be of
  /// two or three words. One that starts the same, as a new
  /// segment beginning with the same word does, is not taken for one until
  /// it differs: a recognizer taking back words it guessed ahead also
  /// sends one.
  void _startSegmentIfNew(List<String> words) {
    final last = _lastHeard;
    if (words.isEmpty ||
        !startsOver(words, last) && !_afterOneWordAyah(words, last)) {
      return;
    }
    _settle(last.skip(_frozen).join(' '));
    _frozen = 0;
    _lastHeard = const [];
    _startedAgain = true;
  }

  /// Whether one word heard after one other starts the text over: the
  /// other is a whole part still to settle, and the word is one
  /// of the first after it. A first word heard wrongly and then put right
  /// is not taken for the start of new words.
  bool _afterOneWordAyah(List<String> words, List<String> last) {
    if (words.length != 1 || last.length != 1 || _frozen > 0) return false;
    if (_pos >= expected.length) return false;
    final ayah = expected[_pos];
    if (!ayah.pause || !wordsMatch(ayah.key, normalizeWord(last.single))) {
      return false;
    }
    final heard = normalizeWord(words.single);
    for (
      var k = _pos + 1;
      k < expected.length && k <= _pos + 1 + lostOnRestart;
      k++
    ) {
      if (wordsMatch(expected[k].key, heard)) return true;
    }
    return false;
  }

  /// Whether the recognizer started listening again, or started its text
  /// over, since the last words found in the text.
  bool _startedAgain = false;

  /// How many words may be lost when the recognizer starts again.
  ///
  /// Google's recognizer misses the first words said while it starts
  /// listening again, after a pause or a listening session that ended.
  /// Words left out just there are taken for recited, as the reciter
  /// cannot be told apart from the recognizer, so they do not count as
  /// mistakes or stop the ayat showing.
  static const lostOnRestart = 2;

  /// [sub], compared from [from], with the words left out at its start
  /// taken for recited when the recognizer has just started again; see
  /// [lostOnRestart].
  RecitationResult _withLostWords(int from, RecitationResult sub) {
    if (!_startedAgain) return sub;
    final words = sub.words;
    var k = _pos - from;
    var lost = 0;
    while (k < words.length &&
        (words[k].status == WordStatus.skipped ||
            (words[k].word.optional &&
                words[k].status == WordStatus.pending))) {
      if (words[k].status == WordStatus.skipped) lost++;
      k++;
    }
    if (k >= words.length) return sub;
    // The start of a word may be lost too.
    final w = words[k];
    var end = w.heard == null ? '' : normalizeWord(w.heard!);
    if (end.startsWith('ا')) end = end.substring(1);
    final cutWord =
        w.status == WordStatus.wrong &&
        w.extrasBefore.isEmpty &&
        end.length >= 2 &&
        w.word.key.endsWith(end);
    if (cutWord) {
      k++;
    } else if (lost == 0 || w.status != WordStatus.correct) {
      return sub;
    }
    if (lost > lostOnRestart) return sub;
    final start = _pos - from;
    return RecitationResult(
      words: [
        for (var i = 0; i < words.length; i++)
          i >= start &&
                  i < k &&
                  (words[i].status == WordStatus.skipped ||
                      words[i].status == WordStatus.wrong)
              ? WordResult(word: words[i].word, status: WordStatus.correct)
              : words[i],
      ],
      extrasAtEnd: sub.extrasAtEnd,
      endAt: sub.endAt,
      heardMatched: sub.heardMatched,
    );
  }

  /// Whether [words] are the start of the last result, shorter: the
  /// start of a new segment beginning with the same words, or the
  /// recognizer taking back words. Until it tells, the last result stays.
  bool _isStartOfLast(List<String> words) {
    final last = _lastHeard;
    if (words.length >= last.length) return false;
    for (var i = 0; i < words.length; i++) {
      if (words[i] != last[i]) return false;
    }
    return true;
  }

  /// Keeps the current session's text and ignores anything it still sends.
  void _commit() {
    _sessionId++;
    _quiet?.cancel();
    var text = _current;
    _current = '';
    _frozen = 0;
    _lastHeard = const [];
    // Many words after the last one found in the text are someone else
    // speaking once the reciter stopped; they are not compared, so they
    // do not take the place of the next word to recite.
    final words = _wordsOf(text);
    if (words.isNotEmpty && _pos < expected.length) {
      final (from, sub) = _alignFromPos(text, settled: true);
      final reachedEnd = from + sub.words.length == expected.length;
      if (!reachedEnd && words.length - sub.heardMatched >= sideSpeechWords) {
        text = words.take(sub.heardMatched).join(' ');
      }
    }
    _settle(text);
  }

  /// Compares [text] from where the last settled words ended and moves on.
  void _settle(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    var (from, sub) = _alignFromPos(text, settled: true);
    _committed.add(text);
    sub = _withLostWords(from, sub);
    if (sub.heardMatched > 0) _startedAgain = false;
    _base = _overlay(_base, from, sub);
    if (from + sub.words.length == expected.length) {
      _extrasAtEnd.addAll(sub.extrasAtEnd);
    }
    _pos = from + sub.end;
  }

  /// Where a reciter going back may start again from: the start of the
  /// part before the one being recited.
  int _backLimit() {
    var k = _pos;
    for (var parts = 0; parts < 2 && k > 0; parts++) {
      final part = expected[k - 1].part;
      while (k > 0 && expected[k - 1].part == part) {
        k--;
      }
    }
    return k;
  }

  /// Compares [text] with the words from [_pos] on, in a window long enough
  /// for everything that was said and starting where the reciter may go
  /// back to.
  (int, RecitationResult) _alignFromPos(String text, {required bool settled}) {
    final heard = text.split(RegExp(r'\s+'));
    final from = _backLimit();
    final end = (_pos + 2 * heard.length + 30).clamp(0, expected.length);
    final window = expected.sublist(from, end);
    var sub = alignRecitation(
      window,
      heard,
      settled: settled,
      start: _pos - from,
      mode: mode,
      lostAtStart: _startedAgain ? lostOnRestart : 0,
    );
    if (end < expected.length && sub.extrasAtEnd.isNotEmpty) {
      // Left over past a window that is not the end of the text. The window
      // is twice as long as what was heard, so this is only noise; drop it.
      sub = RecitationResult(words: sub.words, endAt: sub.endAt);
    }
    return (from, sub);
  }

  List<WordResult> _overlay(
    List<WordResult> base,
    int from,
    RecitationResult sub,
  ) => [
    ...base.take(from),
    for (var k = 0; k < sub.words.length; k++)
      _merge(base[from + k], sub.words[k]),
    ...base.skip(from + sub.words.length),
  ];

  /// A word not reached by [now] keeps what it was. One reached for the
  /// first time adds to the extra words said before it; one recited again
  /// takes only the new try, so an ayah recited again correctly is right.
  static WordResult _merge(WordResult before, WordResult now) {
    if (now.status == WordStatus.pending) {
      if (now.extrasBefore.isEmpty) return before;
      return WordResult(
        word: before.word,
        status: before.status,
        heard: before.heard,
        extrasBefore: _withoutSideSpeech([
          ...before.extrasBefore,
          ...now.extrasBefore,
        ]),
        wrongHarakat: before.wrongHarakat,
      );
    }
    return WordResult(
      word: now.word,
      status: now.status,
      heard: now.heard,
      extrasBefore: _withoutSideSpeech(
        before.status == WordStatus.pending
            ? [...before.extrasBefore, ...now.extrasBefore]
            : now.extrasBefore,
      ),
      wrongHarakat: now.wrongHarakat,
    );
  }

  /// How many extra words in a row are taken for someone else speaking
  /// near the reciter rather than for words the reciter added.
  static const sideSpeechWords = 3;

  /// Extra words said between two words, unless they are so many they
  /// are someone else speaking, which is not the reciter's mistake.
  static List<String> _withoutSideSpeech(List<String> extras) =>
      extras.length >= sideSpeechWords ? const [] : extras;

  void _onSessionDone() {
    if (_disposed) return;
    _commit();
    _update();
    _restart();
  }

  void _restart() {
    if (!_wantListening || _result.isComplete) {
      _wantListening = false;
      notifyListeners();
      return;
    }
    if (_restartPending) return;
    _restartPending = true;
    // A short gap lets the recognizer release the microphone first.
    Future.delayed(const Duration(milliseconds: 300), () {
      _restartPending = false;
      if (_wantListening) _listen();
    });
  }

  void _onError(String message) {
    // Silence and "nothing recognized" are normal pauses while reciting.
    if (message.contains('no_match') ||
        message.contains('no-speech') ||
        message.contains('speech_timeout') ||
        message.contains('aborted')) {
      return;
    }
    error = listenErrorKind(message);
    _wantListening = false;
    notifyListeners();
  }

  /// Compares the words heard so far. Mistakes in the last words, which
  /// the recognizer may still change, are held back unless [settled].
  void _update({bool settled = false}) {
    var words = _base;
    var extrasAtEnd = _extrasAtEnd;
    if (_current.trim().isNotEmpty) {
      var (from, sub) = _alignFromPos(_current, settled: settled);
      sub = _withLostWords(from, sub);
      words = _overlay(_base, from, sub);
      if (from + sub.words.length == expected.length) {
        extrasAtEnd = [..._extrasAtEnd, ...sub.extrasAtEnd];
      }
      if (!settled) words = _keepHeardRight(words);
    }
    _result = RecitationResult(words: words, extrasAtEnd: extrasAtEnd);
    if (_result.isComplete && _wantListening) {
      _wantListening = false;
      listener.stop();
    }
    // The recognizer may still change its last words, also some before
    // the last one it got right; only mistakes in the words settled are
    // told, or in all once it has sent nothing new for a while.
    _reportMistakes(
      settled
          ? _result
          : RecitationResult(words: _base, extrasAtEnd: _extrasAtEnd),
    );
    notifyListeners();
  }

  /// A word heard right that the recognizer's last words, still open,
  /// now make wrong or left out, stays right until they are settled: the
  /// recognizer often writes a word one way and then back again, and an
  /// ayah shown must not hide again for that.
  List<WordResult> _keepHeardRight(List<WordResult> words) {
    final before = _result.words;
    return [
      for (var i = 0; i < words.length; i++)
        i < before.length &&
                before[i].status == WordStatus.correct &&
                (words[i].status == WordStatus.wrong ||
                    words[i].status == WordStatus.skipped) &&
                !_base[i].isMistake
            ? before[i]
            : words[i],
    ];
  }

  void _reportMistakes(RecitationResult result) {
    final words = result.words;
    final leftOut = _partsLeftOut(words);
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      // Extra words before a word not recited yet may be the start of
      // someone else speaking; they count once the reciter goes on.
      if (w.extrasBefore.isNotEmpty && w.status != WordStatus.pending) {
        final extra = w.extrasBefore.join(' ');
        _alert(
          'extra:$i:$extra',
          Mistake(i, MistakeKind.extra, expected: w.text, heard: extra),
        );
      }
      if (w.status == WordStatus.wrong) {
        _alert(
          'wrong:$i:${w.heard}',
          Mistake(i, MistakeKind.wrong, expected: w.text, heard: w.heard),
        );
      } else if (w.status == WordStatus.skipped) {
        if (leftOut.contains(w.part)) {
          // Told once, at the first word of the part.
          final first = words.indexWhere(
            (o) => o.part == w.part && !o.word.optional,
          );
          _alert(
            'skippedPart:${w.part}',
            Mistake(
              first,
              MistakeKind.skippedPart,
              expected: _startOfPart(words, first),
            ),
          );
        } else {
          _alert(
            'skipped:$i',
            Mistake(i, MistakeKind.skippedWord, expected: w.text),
          );
        }
      } else if (w.isHarakatMistake) {
        _alert(
          'harakat:$i:${w.wrongHarakat}',
          Mistake(
            i,
            MistakeKind.harakat,
            expected: w.text,
            heard: w.wrongHarakat,
          ),
        );
      }
    }
    if (result.extrasAtEnd.isNotEmpty) {
      final extra = result.extrasAtEnd.join(' ');
      _alert(
        'end:$extra',
        Mistake(words.length - 1, MistakeKind.extraAtEnd, heard: extra),
      );
    }
  }

  /// The parts whose words were all left out.
  static Set<int> _partsLeftOut(List<WordResult> words) {
    final all = <int>{};
    final not = <int>{};
    for (final w in words) {
      if (w.word.optional) continue;
      (w.status == WordStatus.skipped ? all : not).add(w.part);
    }
    return all.difference(not);
  }

  /// The first few words of the part starting at word [first], to name it.
  static String _startOfPart(List<WordResult> words, int first) {
    final part = words[first].part;
    final start = [
      for (var k = first; k < words.length && words[k].part == part; k++)
        if (!words[k].word.optional) words[k].text,
    ];
    return start.length > 4 ? '${start.take(4).join(' ')} …' : start.join(' ');
  }

  void _alert(String key, Mistake mistake) {
    if (!_alerted.add(key)) return;
    _mistakes.add(mistake);
    onMistake?.call(mistake);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _quiet?.cancel();
    _wantListening = false;
    _sessionId++;
    listener.stop();
    super.dispose();
  }
}
