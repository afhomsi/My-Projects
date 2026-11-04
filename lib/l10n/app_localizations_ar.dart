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
  String get sharhTitle => 'الشرح المختصر';

  @override
  String get sharhComingSoon => 'الشرح المختصر سيضاف بعد توثيق مصدره وحقوقه.';

  @override
  String get sharhDraftNotice => 'مسودة: لم يراجع هذا الشرح بعد طالب علم مختص.';

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

  @override
  String get planTitle => 'خطة الحفظ';

  @override
  String get memorizeAction => 'احفظ وسمّع';

  @override
  String memorizeTitle(String number) {
    return 'تسميع الحديث $number';
  }

  @override
  String get hideLabel => 'أخفِ من الكلمات:';

  @override
  String get hideNone => 'لا شيء';

  @override
  String get hideThird => 'الثلث';

  @override
  String get hideTwoThirds => 'الثلثين';

  @override
  String get hideAll => 'الكل';

  @override
  String get memorizeHelp => 'اقرأ الحديث من حفظك، والمس الكلمة المخفية لتظهر.';

  @override
  String get firstLetterHint => 'أظهر أول حرف';

  @override
  String get reshuffle => 'أخفِ كلمات أخرى';

  @override
  String get revealNextWord => 'أظهر الكلمة التالية';

  @override
  String get gradeQuestion => 'كيف كان تسميعك؟';

  @override
  String get gradeAgain => 'لم أحفظه';

  @override
  String get gradeHard => 'بصعوبة';

  @override
  String get gradeGood => 'أتقنته';

  @override
  String nextReviewIn(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'بعد $n يومًا',
      few: 'بعد $n أيام',
      two: 'بعد يومين',
      one: 'غدًا',
    );
    return 'المراجعة القادمة $_temp0';
  }

  @override
  String planProgress(String started, String total, String memorized) {
    return 'بدأت $started من $total · أتقنت $memorized';
  }

  @override
  String get memorizedMeaning =>
      'يعد الحديث متقنًا حين تصل مراجعته إلى مرة كل أسبوعين أو أكثر.';

  @override
  String get newHadithTitle => 'الحديث الجديد';

  @override
  String get startMemorizing => 'ابدأ حفظه اليوم';

  @override
  String newHadithIn(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'يبدأ بعد $n يومًا',
      few: 'يبدأ بعد $n أيام',
      two: 'يبدأ بعد يومين',
      one: 'يبدأ غدًا',
    );
    return '$_temp0';
  }

  @override
  String get allStarted => 'بدأت حفظ الأحاديث كلها، واصل المراجعة.';

  @override
  String reviewTodayTitle(String count) {
    return 'مراجعة اليوم ($count)';
  }

  @override
  String get noReviewToday => 'لا مراجعة اليوم.';

  @override
  String overdueBy(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر $n يومًا',
      few: 'متأخر $n أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا',
    );
    return '$_temp0';
  }

  @override
  String get paceTitle => 'حديث جديد كل';

  @override
  String paceDays(int days, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$n يومًا',
      few: '$n أيام',
      two: 'يومين',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String get paceWeek => 'أسبوع';

  @override
  String get listenAction => 'استمع';

  @override
  String get stopAction => 'أوقف';

  @override
  String repeatLabel(String count) {
    return 'التكرار: $count';
  }

  @override
  String repeatTimes(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$n مرة',
      few: '$n مرات',
      one: 'مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get repeatEndless => 'بلا توقف';

  @override
  String repeatRound(String round, String total) {
    return 'المرة $round من $total';
  }

  @override
  String repeatRoundEndless(String round) {
    return 'المرة $round';
  }

  @override
  String get deviceVoiceNotice =>
      'صوت الجهاز مؤقت حتى يتوفر تسجيل مأذون، وقد يخطئ في التشكيل.';

  @override
  String get voiceUnavailable =>
      'لا يوجد صوت عربي على هذا الجهاز. ثبّته من إعدادات تحويل النص إلى كلام.';

  @override
  String get reciteAction => 'سمّع بصوتك';

  @override
  String reciteTitle(String number) {
    return 'التسميع بالصوت: الحديث $number';
  }

  @override
  String get reciteHelp =>
      'اضغط على الميكروفون واقرأ الحديث من حفظك. تظهر كل كلمة حين تقولها، ويظهر الخطأ بالأحمر.';

  @override
  String get reciteStart => 'ابدأ التسميع';

  @override
  String get reciteContinue => 'تابع';

  @override
  String get reciteStop => 'أوقف';

  @override
  String get reciteRestart => 'من البداية';

  @override
  String get reciteShowText => 'أظهر النص';

  @override
  String reciteHeard(String text) {
    return 'سمعت: $text';
  }

  @override
  String reciteProgress(String done, String total) {
    return 'قرأت $done من $total';
  }

  @override
  String get reciteMistakes => 'الأخطاء';

  @override
  String mistakeWrong(String heard, String expected) {
    return 'سمعت «$heard» والصواب «$expected»';
  }

  @override
  String mistakeSkippedWord(String expected) {
    return 'نسيت كلمة «$expected»';
  }

  @override
  String mistakeSkippedPart(String expected) {
    return 'نسيت جملة: «$expected»';
  }

  @override
  String mistakeExtra(String heard, String expected) {
    return 'زدت «$heard» قبل «$expected»';
  }

  @override
  String mistakeExtraAtEnd(String heard) {
    return 'زدت بعد النهاية: «$heard»';
  }

  @override
  String mistakeHarakat(String heard, String expected) {
    return 'خطأ في الحركة: سمعت «$heard» والصواب «$expected»';
  }

  @override
  String reciteDone(int count, String n) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سمّعت الحديث كاملًا، وفيه $n خطأ.',
      few: 'سمّعت الحديث كاملًا، وفيه $n أخطاء.',
      two: 'سمّعت الحديث كاملًا، وفيه خطآن.',
      one: 'سمّعت الحديث كاملًا، وفيه خطأ واحد.',
      zero: 'أحسنت! سمّعت الحديث كاملًا دون خطأ.',
    );
    return '$_temp0';
  }

  @override
  String get recitePrivacyDevice =>
      'يُتعرَّف على صوتك في هاتفك، ولا يُرسل إلى أي مكان.';

  @override
  String get recitePrivacyOnline =>
      'سمحت بالتعرف عبر الإنترنت: يُرسل صوتك إلى خدمة التعرف على الكلام في جهازك.';

  @override
  String get recitePrivacyWeb =>
      'في المتصفح يُرسل صوتك إلى خدمة التعرف على الكلام في المتصفح.';

  @override
  String get reciteDeviceOnly => 'على الهاتف فقط';

  @override
  String get reciteAllowOnline => 'اسمح بالتعرف عبر الإنترنت';

  @override
  String get reciteErrorOffline =>
      'لا يستطيع هاتفك التعرف على العربية دون إنترنت. ثبّت اللغة العربية للتعرف على الكلام دون اتصال من إعدادات الهاتف، أو اسمح بالتعرف عبر الإنترنت.';

  @override
  String get reciteErrorNetwork =>
      'التعرف على الصوت يحتاج إلى اتصال بالإنترنت.';

  @override
  String get reciteErrorPermission =>
      'لم يُسمح باستخدام الميكروفون. اسمح به من إعدادات الهاتف ثم حاول.';

  @override
  String get reciteErrorNoMic => 'لم يُعثر على ميكروفون.';

  @override
  String get reciteErrorUnavailable =>
      'لا يمكن التعرف على الصوت على هذا الجهاز، أو لم يُسمح باستخدام الميكروفون.';

  @override
  String get reciteErrorOther => 'حدث خطأ في الاستماع. حاول مرة أخرى.';
}
