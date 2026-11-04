import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأربعون النووية'**
  String get appTitle;

  /// No description provided for @indexTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفهرس'**
  String get indexTitle;

  /// No description provided for @hadithNumber.
  ///
  /// In ar, this message translates to:
  /// **'الحديث {number}'**
  String hadithNumber(String number);

  /// No description provided for @narratorLabel.
  ///
  /// In ar, this message translates to:
  /// **'الراوي: {name}'**
  String narratorLabel(String name);

  /// No description provided for @sourceLabel.
  ///
  /// In ar, this message translates to:
  /// **'التخريج'**
  String get sourceLabel;

  /// No description provided for @sharhTitle.
  ///
  /// In ar, this message translates to:
  /// **'الشرح المختصر'**
  String get sharhTitle;

  /// No description provided for @sharhComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'الشرح المختصر سيضاف بعد توثيق مصدره وحقوقه.'**
  String get sharhComingSoon;

  /// No description provided for @sharhDraftNotice.
  ///
  /// In ar, this message translates to:
  /// **'مسودة: لم يراجع هذا الشرح بعد طالب علم مختص.'**
  String get sharhDraftNotice;

  /// No description provided for @previous.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @draftNotice.
  ///
  /// In ar, this message translates to:
  /// **'النص مسودة لم تراجع بعد على نسخة مطبوعة.'**
  String get draftNotice;

  /// No description provided for @loadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تحميل الكتاب.'**
  String get loadError;

  /// No description provided for @ahadithCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} حديثًا'**
  String ahadithCount(String count);

  /// No description provided for @planTitle.
  ///
  /// In ar, this message translates to:
  /// **'خطة الحفظ'**
  String get planTitle;

  /// No description provided for @memorizeAction.
  ///
  /// In ar, this message translates to:
  /// **'احفظ وسمّع'**
  String get memorizeAction;

  /// No description provided for @memorizeTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسميع الحديث {number}'**
  String memorizeTitle(String number);

  /// No description provided for @hideLabel.
  ///
  /// In ar, this message translates to:
  /// **'أخفِ من الكلمات:'**
  String get hideLabel;

  /// No description provided for @hideNone.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء'**
  String get hideNone;

  /// No description provided for @hideThird.
  ///
  /// In ar, this message translates to:
  /// **'الثلث'**
  String get hideThird;

  /// No description provided for @hideTwoThirds.
  ///
  /// In ar, this message translates to:
  /// **'الثلثين'**
  String get hideTwoThirds;

  /// No description provided for @hideAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get hideAll;

  /// No description provided for @memorizeHelp.
  ///
  /// In ar, this message translates to:
  /// **'اقرأ الحديث من حفظك، والمس الكلمة المخفية لتظهر.'**
  String get memorizeHelp;

  /// No description provided for @firstLetterHint.
  ///
  /// In ar, this message translates to:
  /// **'أظهر أول حرف'**
  String get firstLetterHint;

  /// No description provided for @reshuffle.
  ///
  /// In ar, this message translates to:
  /// **'أخفِ كلمات أخرى'**
  String get reshuffle;

  /// No description provided for @revealNextWord.
  ///
  /// In ar, this message translates to:
  /// **'أظهر الكلمة التالية'**
  String get revealNextWord;

  /// No description provided for @gradeQuestion.
  ///
  /// In ar, this message translates to:
  /// **'كيف كان تسميعك؟'**
  String get gradeQuestion;

  /// No description provided for @gradeAgain.
  ///
  /// In ar, this message translates to:
  /// **'لم أحفظه'**
  String get gradeAgain;

  /// No description provided for @gradeHard.
  ///
  /// In ar, this message translates to:
  /// **'بصعوبة'**
  String get gradeHard;

  /// No description provided for @gradeGood.
  ///
  /// In ar, this message translates to:
  /// **'أتقنته'**
  String get gradeGood;

  /// No description provided for @nextReviewIn.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة القادمة {days, plural, =1{غدًا} =2{بعد يومين} few{بعد {n} أيام} other{بعد {n} يومًا}}'**
  String nextReviewIn(int days, String n);

  /// No description provided for @planProgress.
  ///
  /// In ar, this message translates to:
  /// **'بدأت {started} من {total} · أتقنت {memorized}'**
  String planProgress(String started, String total, String memorized);

  /// No description provided for @memorizedMeaning.
  ///
  /// In ar, this message translates to:
  /// **'يعد الحديث متقنًا حين تصل مراجعته إلى مرة كل أسبوعين أو أكثر.'**
  String get memorizedMeaning;

  /// No description provided for @newHadithTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحديث الجديد'**
  String get newHadithTitle;

  /// No description provided for @startMemorizing.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ حفظه اليوم'**
  String get startMemorizing;

  /// No description provided for @newHadithIn.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يبدأ غدًا} =2{يبدأ بعد يومين} few{يبدأ بعد {n} أيام} other{يبدأ بعد {n} يومًا}}'**
  String newHadithIn(int days, String n);

  /// No description provided for @allStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت حفظ الأحاديث كلها، واصل المراجعة.'**
  String get allStarted;

  /// No description provided for @reviewTodayTitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة اليوم ({count})'**
  String reviewTodayTitle(String count);

  /// No description provided for @noReviewToday.
  ///
  /// In ar, this message translates to:
  /// **'لا مراجعة اليوم.'**
  String get noReviewToday;

  /// No description provided for @overdueBy.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{متأخر يومًا} =2{متأخر يومين} few{متأخر {n} أيام} other{متأخر {n} يومًا}}'**
  String overdueBy(int days, String n);

  /// No description provided for @paceTitle.
  ///
  /// In ar, this message translates to:
  /// **'حديث جديد كل'**
  String get paceTitle;

  /// No description provided for @paceDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{يوم} =2{يومين} few{{n} أيام} other{{n} يومًا}}'**
  String paceDays(int days, String n);

  /// No description provided for @paceWeek.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get paceWeek;

  /// No description provided for @listenAction.
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get listenAction;

  /// No description provided for @stopAction.
  ///
  /// In ar, this message translates to:
  /// **'أوقف'**
  String get stopAction;

  /// No description provided for @repeatLabel.
  ///
  /// In ar, this message translates to:
  /// **'التكرار: {count}'**
  String repeatLabel(String count);

  /// No description provided for @repeatTimes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} few{{n} مرات} other{{n} مرة}}'**
  String repeatTimes(int count, String n);

  /// No description provided for @repeatEndless.
  ///
  /// In ar, this message translates to:
  /// **'بلا توقف'**
  String get repeatEndless;

  /// No description provided for @repeatRound.
  ///
  /// In ar, this message translates to:
  /// **'المرة {round} من {total}'**
  String repeatRound(String round, String total);

  /// No description provided for @repeatRoundEndless.
  ///
  /// In ar, this message translates to:
  /// **'المرة {round}'**
  String repeatRoundEndless(String round);

  /// No description provided for @voiceUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'تعذر تشغيل التسجيل.'**
  String get voiceUnavailable;

  /// No description provided for @reciteAction.
  ///
  /// In ar, this message translates to:
  /// **'سمّع بصوتك'**
  String get reciteAction;

  /// No description provided for @reciteTitle.
  ///
  /// In ar, this message translates to:
  /// **'التسميع بالصوت: الحديث {number}'**
  String reciteTitle(String number);

  /// No description provided for @reciteHelp.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الميكروفون واقرأ الحديث من حفظك. تظهر كل كلمة حين تقولها، ويظهر الخطأ بالأحمر.'**
  String get reciteHelp;

  /// No description provided for @reciteStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ التسميع'**
  String get reciteStart;

  /// No description provided for @reciteContinue.
  ///
  /// In ar, this message translates to:
  /// **'تابع'**
  String get reciteContinue;

  /// No description provided for @reciteStop.
  ///
  /// In ar, this message translates to:
  /// **'أوقف'**
  String get reciteStop;

  /// No description provided for @reciteRestart.
  ///
  /// In ar, this message translates to:
  /// **'من البداية'**
  String get reciteRestart;

  /// No description provided for @reciteShowText.
  ///
  /// In ar, this message translates to:
  /// **'أظهر النص'**
  String get reciteShowText;

  /// No description provided for @reciteHeard.
  ///
  /// In ar, this message translates to:
  /// **'سمعت: {text}'**
  String reciteHeard(String text);

  /// No description provided for @reciteProgress.
  ///
  /// In ar, this message translates to:
  /// **'قرأت {done} من {total}'**
  String reciteProgress(String done, String total);

  /// No description provided for @reciteMistakes.
  ///
  /// In ar, this message translates to:
  /// **'الأخطاء'**
  String get reciteMistakes;

  /// No description provided for @mistakeWrong.
  ///
  /// In ar, this message translates to:
  /// **'سمعت «{heard}» والصواب «{expected}»'**
  String mistakeWrong(String heard, String expected);

  /// No description provided for @mistakeSkippedWord.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة «{expected}»'**
  String mistakeSkippedWord(String expected);

  /// No description provided for @mistakeSkippedPart.
  ///
  /// In ar, this message translates to:
  /// **'نسيت جملة: «{expected}»'**
  String mistakeSkippedPart(String expected);

  /// No description provided for @mistakeExtra.
  ///
  /// In ar, this message translates to:
  /// **'زدت «{heard}» قبل «{expected}»'**
  String mistakeExtra(String heard, String expected);

  /// No description provided for @mistakeExtraAtEnd.
  ///
  /// In ar, this message translates to:
  /// **'زدت بعد النهاية: «{heard}»'**
  String mistakeExtraAtEnd(String heard);

  /// No description provided for @mistakeHarakat.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الحركة: سمعت «{heard}» والصواب «{expected}»'**
  String mistakeHarakat(String heard, String expected);

  /// No description provided for @reciteDone.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{أحسنت! سمّعت الحديث كاملًا دون خطأ.} =1{سمّعت الحديث كاملًا، وفيه خطأ واحد.} =2{سمّعت الحديث كاملًا، وفيه خطآن.} few{سمّعت الحديث كاملًا، وفيه {n} أخطاء.} other{سمّعت الحديث كاملًا، وفيه {n} خطأ.}}'**
  String reciteDone(int count, String n);

  /// No description provided for @recitePrivacyDevice.
  ///
  /// In ar, this message translates to:
  /// **'يُتعرَّف على صوتك في هاتفك، ولا يُرسل إلى أي مكان.'**
  String get recitePrivacyDevice;

  /// No description provided for @recitePrivacyOnline.
  ///
  /// In ar, this message translates to:
  /// **'سمحت بالتعرف عبر الإنترنت: يُرسل صوتك إلى خدمة التعرف على الكلام في جهازك.'**
  String get recitePrivacyOnline;

  /// No description provided for @recitePrivacyWeb.
  ///
  /// In ar, this message translates to:
  /// **'في المتصفح يُرسل صوتك إلى خدمة التعرف على الكلام في المتصفح.'**
  String get recitePrivacyWeb;

  /// No description provided for @reciteDeviceOnly.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف فقط'**
  String get reciteDeviceOnly;

  /// No description provided for @reciteAllowOnline.
  ///
  /// In ar, this message translates to:
  /// **'اسمح بالتعرف عبر الإنترنت'**
  String get reciteAllowOnline;

  /// No description provided for @reciteErrorOffline.
  ///
  /// In ar, this message translates to:
  /// **'لا يستطيع هاتفك التعرف على العربية دون إنترنت. ثبّت اللغة العربية للتعرف على الكلام دون اتصال من إعدادات الهاتف، أو اسمح بالتعرف عبر الإنترنت.'**
  String get reciteErrorOffline;

  /// No description provided for @reciteErrorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'التعرف على الصوت يحتاج إلى اتصال بالإنترنت.'**
  String get reciteErrorNetwork;

  /// No description provided for @reciteErrorPermission.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسمح باستخدام الميكروفون. اسمح به من إعدادات الهاتف ثم حاول.'**
  String get reciteErrorPermission;

  /// No description provided for @reciteErrorNoMic.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على ميكروفون.'**
  String get reciteErrorNoMic;

  /// No description provided for @reciteErrorUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التعرف على الصوت على هذا الجهاز، أو لم يُسمح باستخدام الميكروفون.'**
  String get reciteErrorUnavailable;

  /// No description provided for @reciteErrorOther.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ في الاستماع. حاول مرة أخرى.'**
  String get reciteErrorOther;

  /// No description provided for @quizAction.
  ///
  /// In ar, this message translates to:
  /// **'اختبار قصير'**
  String get quizAction;

  /// No description provided for @quizHelp.
  ///
  /// In ar, this message translates to:
  /// **'ثلاثة أسئلة من الأحاديث التي بدأت حفظها: تكمل كل حديث بصوتك من الموضع المعروض.'**
  String get quizHelp;

  /// No description provided for @quizNeedsPlan.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ حفظ حديث في الخطة ليُفتح الاختبار.'**
  String get quizNeedsPlan;

  /// No description provided for @quizTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختبار قصير'**
  String get quizTitle;

  /// No description provided for @quizQuestion.
  ///
  /// In ar, this message translates to:
  /// **'السؤال {n} من {total}'**
  String quizQuestion(String n, String total);

  /// No description provided for @quizFromStart.
  ///
  /// In ar, this message translates to:
  /// **'اقرأ الحديث من أوله:'**
  String get quizFromStart;

  /// No description provided for @quizGoOn.
  ///
  /// In ar, this message translates to:
  /// **'أكمل بعد قوله:'**
  String get quizGoOn;

  /// No description provided for @quizShowAnswer.
  ///
  /// In ar, this message translates to:
  /// **'أظهر الجواب'**
  String get quizShowAnswer;

  /// No description provided for @quizNext.
  ///
  /// In ar, this message translates to:
  /// **'السؤال التالي'**
  String get quizNext;

  /// No description provided for @quizFinish.
  ///
  /// In ar, this message translates to:
  /// **'النتيجة'**
  String get quizFinish;

  /// No description provided for @quizResultTitle.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة الاختبار'**
  String get quizResultTitle;

  /// No description provided for @quizScore.
  ///
  /// In ar, this message translates to:
  /// **'أجبت عن {right} من {total} دون خطأ'**
  String quizScore(String right, String total);

  /// No description provided for @quizMistakes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{دون خطأ} =1{خطأ واحد} =2{خطآن} few{{n} أخطاء} other{{n} خطأ}}'**
  String quizMistakes(int count, String n);

  /// No description provided for @quizGaveUp.
  ///
  /// In ar, this message translates to:
  /// **'أظهرت الجواب'**
  String get quizGaveUp;

  /// No description provided for @quizAgain.
  ///
  /// In ar, this message translates to:
  /// **'اختبار آخر'**
  String get quizAgain;

  /// No description provided for @quizDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get quizDone;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return SAr();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
