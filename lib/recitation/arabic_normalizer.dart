/// Turns the matn and speech-recognizer output into comparable letter
/// skeletons.
///
/// Ported from the Quran app, where it also bridges Uthmani spelling; the
/// matn of the Forty is in plain spelling with tashkeel, so most of the
/// Uthmani rules below simply never apply. Speech recognizers write plain
/// Arabic without diacritics. Both sides are reduced to the same skeleton: diacritics and Quranic marks are removed,
/// hamza and alef forms are unified, and long alefs inside a word are dropped
/// because the two spellings disagree on exactly those.
///
/// Other spellings that differ the same way are made the same too: a
/// hamza on a seat or on its own is dropped (شيئا, شَيۡـٔٗا), alef
/// maqsura is a long alef (أدراك, أَدۡرَىٰكَ), the waw written for an alef
/// before ta marbuta is one (الصلاة, ٱلصَّلَوٰةَ), and a letter the mushaf
/// writes once with a shadda where plain spelling writes it twice is
/// written once (الليل, ٱلَّيۡلِ; داوود, دَاوُۥدَ; يحيي, يُحۡيِۦ).
library;

final _marks = RegExp(
  '['
  'ؐ-ؚ' // honorifics and small signs
  'ً-ٟ' // harakat, tanween, shadda, sukun
  'ٰ' // dagger alef
  'ۖ-ۭ' // Quranic pause and recitation marks
  'ـ' // tatweel
  ']',
);

final _nonLetters = RegExp('[^ء-ي]');

final _alefs = RegExp('[أإآٱ]');

/// A waw read as a long alef, before ta marbuta or a final alef.
final _wawAlef = RegExp('و[ً-ٟ]*ٰ[ً-ٟۖ-ۭ]*(?=[ةا]|\$)');

/// A ya or waw carrying a hamza below, as in ٱمۡرِيٕٖ: a hamza on its own.
/// (The Quran app also drops a ya with a sukun after إِ, as in أَفَإِيْن;
/// in plain spelling that sukun is said, as in إِيْمَان, so not here.)
final _yaHamza = RegExp('[وي](?=[ً-ٟ]*ٕ)');

/// A lam doubled in plain spelling, as in الليل; not in الله.
final _doubleLam = RegExp('لل(?!ه)');

/// A waw or ya written twice, as in داوود and يحيي.
final _doubleWeak = RegExp(r'([وي])\1');

/// Skeletons already made: the same words come back in every partial
/// result while reciting, so each is reduced only once.
final _cache = <String, String>{};

/// The comparable skeleton of a single word.
String normalizeWord(String word) {
  final cached = _cache[word];
  if (cached != null) return cached;
  if (_cache.length > 20000) _cache.clear();
  return _cache[word] = _normalize(word);
}

String _normalize(String word) {
  var w = word
      .replaceAll(_wawAlef, 'ا')
      .replaceAll(_yaHamza, '')
      .replaceAll(_marks, '');
  w = w
      .replaceAll(_alefs, 'ا')
      .replaceAll('ى', 'ا')
      .replaceAll(RegExp('[ءئؤ]'), '')
      .replaceAll('ة', 'ه');
  w = w.replaceAll(_nonLetters, '');
  if (w.length > 1) {
    w = w[0] + w.substring(1).replaceAll('ا', '');
  }
  return w
      .replaceAll(_doubleLam, 'ل')
      .replaceAllMapped(_doubleWeak, (m) => m[1]!);
}

/// Splits [text] into words and normalizes each, dropping empty ones.
List<String> normalizeWords(String text) => text
    .split(RegExp(r'\s+'))
    .map(normalizeWord)
    .where((w) => w.isNotEmpty)
    .toList();
