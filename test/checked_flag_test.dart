import 'package:arbaeen/data/hadith.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _hadith(int number, {String? checked}) => {
  'number': number,
  'title': 't',
  'narrator': 'n',
  'matn': 'm',
  'source': 's',
  'checked': ?checked,
};

void main() {
  test('a hadith without "checked" is a draft', () {
    final h = Hadith.fromJson(_hadith(1));
    expect(h.isChecked, isFalse);
    expect(h.checkedAgainst, isNull);
  });

  test('a hadith with "checked" names its edition', () {
    final h = Hadith.fromJson(_hadith(1, checked: 'edition'));
    expect(h.isChecked, isTrue);
    expect(h.checkedAgainst, 'edition');
  });

  test('the book is a draft until every hadith is checked', () {
    Book book(List<Map<String, dynamic>> ahadith) =>
        Book.fromJson({'title': 'b', 'author': 'a', 'ahadith': ahadith});

    expect(book([_hadith(1, checked: 'e'), _hadith(2)]).isDraft, isTrue);
    expect(
      book([_hadith(1, checked: 'e'), _hadith(2, checked: 'e')]).isDraft,
      isFalse,
    );
  });

  test('a sharh is a draft until it names its reviewer', () {
    const fields = {'author': 'a', 'text': 't', 'source': 's'};
    expect(Sharh.fromJson(fields).isReviewed, isFalse);
    final reviewed = Sharh.fromJson({...fields, 'reviewed': 'r'});
    expect(reviewed.isReviewed, isTrue);
    expect(reviewed.reviewedBy, 'r');
  });
}
