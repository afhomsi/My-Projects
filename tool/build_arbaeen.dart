// Builds assets/hadith/arbaeen.json from the hand-typed parts in tool/matn/.
//
// The short sharh in tool/sharh/ is merged into each hadith's "shuruh".
//
// Run from the repo root: dart run tool/build_arbaeen.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final ahadith = _readParts('tool/matn');
  ahadith.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

  final numbers = ahadith.map((h) => h['number']).toList();
  final expected = List.generate(42, (i) => i + 1);
  if (numbers.join(',') != expected.join(',')) {
    stderr.writeln('Expected ahadith 1..42, got: $numbers');
    exit(1);
  }

  final sharh = _readParts('tool/sharh');
  final sharhNumbers = sharh.map((s) => s['number']).toList()..sort();
  if (sharhNumbers.join(',') != expected.join(',')) {
    stderr.writeln('Expected a short sharh for 1..42, got: $sharhNumbers');
    exit(1);
  }
  for (final h in ahadith) {
    final short = sharh.firstWhere((s) => s['number'] == h['number']);
    h['shuruh'] = [
      {
        'author': shortSharhAuthor,
        'text': short['text'],
        'source': shortSharhSource,
        'reviewed': ?short['reviewed'],
      },
    ];
  }

  final unchecked = [
    for (final h in ahadith)
      if (h['checked'] == null) h['number'],
  ];
  final book = {
    'title': 'الأربعون النووية',
    'author': 'الإمام أبو زكريا يحيى بن شرف النووي (ت ٦٧٦هـ)',
    'status': unchecked.isEmpty ? 'checked' : 'draft',
    'note': unchecked.isEmpty
        ? 'Every hadith was checked word by word against a printed edition.'
        : 'Not yet checked against a printed edition: ${unchecked.join(', ')}.',
    'ahadith': ahadith,
  };
  const encoder = JsonEncoder.withIndent('  ');
  File('assets/hadith/arbaeen.json')
      .writeAsStringSync('${encoder.convert(book)}\n');
  stdout.writeln(
    'Wrote ${ahadith.length} ahadith to assets/hadith/arbaeen.json',
  );
}

/// Who wrote the short sharh, as shown in the app.
const shortSharhAuthor = 'شرح مختصر من إعداد التطبيق';

/// Where the short sharh comes from, as shown in the app.
const shortSharhSource =
    'صياغة جديدة لمعانٍ مشهورة عند شُرّاح الأربعين المتقدمين، '
    'دون نقل نص من شرح مطبوع.';

List<Map<String, dynamic>> _readParts(String dir) {
  final files =
      Directory(dir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      ...(jsonDecode(file.readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>(),
  ];
}
