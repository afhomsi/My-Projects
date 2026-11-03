// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class SAr extends S {
  SAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'الأربعون النووية';

  @override
  String get indexTitle => 'الفهرس';

  @override
  String hadithNumber(String number) {
    return 'الحديث $number';
  }

  @override
  String narratorLabel(String name) {
    return 'الراوي: $name';
  }

  @override
  String get sourceLabel => 'التخريج';

  @override
  String get sharhTitle => 'الشرح';

  @override
  String get sharhComingSoon => 'الشرح المختصر سيضاف بعد توثيق مصدره وحقوقه.';

  @override
  String get previous => 'السابق';

  @override
  String get next => 'التالي';

  @override
  String get draftNotice => 'النص مسودة لم تراجع بعد على نسخة مطبوعة.';

  @override
  String get loadError => 'تعذر تحميل الكتاب.';

  @override
  String ahadithCount(String count) {
    return '$count حديثًا';
  }
}
