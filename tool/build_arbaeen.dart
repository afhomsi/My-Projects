// Builds assets/hadith/arbaeen.json from the hand-typed parts in tool/matn/.
//
// Run from the repo root: dart run tool/build_arbaeen.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final parts =
      Directory('tool/matn')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final ahadith = <Map<String, dynamic>>[];
  for (final file in parts) {
    final list = jsonDecode(file.readAsStringSync()) as List<dynamic>;
    ahadith.addAll(list.cast<Map<String, dynamic>>());
  }
  ahadith.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));

  final numbers = ahadith.map((h) => h['number']).toList();
  final expected = List.generate(42, (i) => i + 1);
  if (numbers.join(',') != expected.join(',')) {
    stderr.writeln('Expected ahadith 1..42, got: $numbers');
    exit(1);
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
