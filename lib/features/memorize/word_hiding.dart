import 'dart:math';

/// One word of the matn, split so that punctuation around it stays visible.
///
/// For "«إِنَّمَا" the [prefix] is "«", the [core] is "إِنَّمَا" and the
/// [suffix] is empty. Only the core is ever hidden.
class MatnWord {
  const MatnWord({required this.prefix, required this.core, this.suffix = ''});

  final String prefix;
  final String core;
  final String suffix;

  /// True when the word has Arabic letters that can be hidden. Words like
  /// "ﷺ" or a lone "«" stay visible as anchors while reciting.
  bool get isHideable => core.isNotEmpty;

  /// The first letter of the core with its harakat, used as a hint. For a
  /// word with the article "ال" the hint also shows the letter after it,
  /// since the article alone says little.
  String get firstLetter {
    final m = _firstLetter.firstMatch(core);
    return m == null ? '' : m.group(0)!;
  }

  /// The core after [firstLetter].
  String get rest => core.substring(firstLetter.length);
}

// Arabic letters (hamza to yaa, alef wasla and extended letters).
const _letters = r'ء-غف-يٱ-ۓ';
// Harakat, shadda, sukun, tanween and the dagger alef.
const _marks = r'ً-ٰٟ';

final _wordParts = RegExp(
  '^([^$_letters]*)([$_letters][$_letters$_marksـ]*)?(.*)\$',
  dotAll: true,
);
final _firstLetter = RegExp(
  '^(?:[\u0627\u0671][$_marks]*\u0644[$_marks]*)?[$_letters][$_marks]*',
);

/// Splits a matn into words on whitespace, keeping punctuation apart.
List<MatnWord> splitMatn(String matn) => [
  for (final token in matn.split(RegExp(r'\s+')))
    if (token.isNotEmpty) _splitToken(token),
];

MatnWord _splitToken(String token) {
  final m = _wordParts.firstMatch(token)!;
  final core = m.group(2) ?? '';
  if (core.isEmpty) return MatnWord(prefix: token, core: '');
  return MatnWord(prefix: m.group(1)!, core: core, suffix: m.group(3)!);
}

/// How much of the matn is hidden while memorizing.
enum HideLevel {
  none(0),
  third(1 / 3),
  twoThirds(2 / 3),
  all(1);

  const HideLevel(this.fraction);

  final double fraction;
}

/// Picks which words to hide: [level] of the hideable words, chosen at random
/// with [seed] so the same seed always hides the same words.
Set<int> pickHidden(List<MatnWord> words, HideLevel level, int seed) {
  final hideable = [
    for (var i = 0; i < words.length; i++)
      if (words[i].isHideable) i,
  ];
  final count = (hideable.length * level.fraction).round();
  if (count >= hideable.length) return hideable.toSet();
  hideable.shuffle(Random(seed));
  return hideable.take(count).toSet();
}
