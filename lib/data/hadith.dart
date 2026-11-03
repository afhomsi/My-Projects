/// One commentary (sharh) on a hadith.
class Sharh {
  const Sharh({required this.author, required this.text, required this.source});

  factory Sharh.fromJson(Map<String, dynamic> json) => Sharh(
    author: json['author'] as String,
    text: json['text'] as String,
    source: json['source'] as String,
  );

  final String author;
  final String text;
  final String source;
}

/// One hadith of the Forty, as written by an-Nawawi.
class Hadith {
  const Hadith({
    required this.number,
    required this.title,
    required this.narrator,
    required this.matn,
    required this.source,
    this.shuruh = const [],
  });

  factory Hadith.fromJson(Map<String, dynamic> json) => Hadith(
    number: json['number'] as int,
    title: json['title'] as String,
    narrator: json['narrator'] as String,
    matn: json['matn'] as String,
    source: json['source'] as String,
    shuruh: [
      for (final s in (json['shuruh'] as List<dynamic>? ?? const []))
        Sharh.fromJson(s as Map<String, dynamic>),
    ],
  );

  final int number;
  final String title;
  final String narrator;

  /// The full text with tashkeel, including the opening chain ("عن ...").
  final String matn;

  /// The takhreej as an-Nawawi wrote it, e.g. "رواه البخاري ومسلم".
  final String source;
  final List<Sharh> shuruh;
}

/// The whole book: metadata plus the 42 ahadith in order.
class Book {
  const Book({
    required this.title,
    required this.author,
    required this.isDraft,
    required this.ahadith,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    title: json['title'] as String,
    author: json['author'] as String,
    isDraft: json['status'] == 'draft',
    ahadith: [
      for (final h in json['ahadith'] as List<dynamic>)
        Hadith.fromJson(h as Map<String, dynamic>),
    ],
  );

  final String title;
  final String author;

  /// True until the matn has been checked by hand against a printed edition.
  final bool isDraft;
  final List<Hadith> ahadith;
}
