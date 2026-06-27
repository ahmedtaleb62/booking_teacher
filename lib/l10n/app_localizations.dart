import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr')
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'حصتي'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In ar, this message translates to:
  /// **'منصة الدروس الخصوصية المباشرة'**
  String get splashTagline;

  /// No description provided for @commonRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get commonBack;

  /// No description provided for @commonSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get commonSend;

  /// No description provided for @commonCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get commonCopied;

  /// No description provided for @commonLoading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get commonError;

  /// No description provided for @commonErrorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال، تحقق من الإنترنت'**
  String get commonErrorNetwork;

  /// No description provided for @commonErrorLoading.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل'**
  String get commonErrorLoading;

  /// No description provided for @commonNoData.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات'**
  String get commonNoData;

  /// No description provided for @commonYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get commonNo;

  /// No description provided for @commonSearch.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get commonSearch;

  /// No description provided for @commonEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get commonEdit;

  /// No description provided for @commonDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get commonDelete;

  /// No description provided for @authWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك'**
  String get authWelcome;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك للمتابعة'**
  String get authLoginSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get authPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get authForgotPassword;

  /// No description provided for @authLoginBtn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authLoginBtn;

  /// No description provided for @authNoAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟  '**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ حساباً'**
  String get authCreateAccount;

  /// No description provided for @authRegisterTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب جديد'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'انضم لمنصة حصتي'**
  String get authRegisterSubtitle;

  /// No description provided for @authAccountType.
  ///
  /// In ar, this message translates to:
  /// **'نوع الحساب'**
  String get authAccountType;

  /// No description provided for @authStudent.
  ///
  /// In ar, this message translates to:
  /// **'طالب'**
  String get authStudent;

  /// No description provided for @authTeacher.
  ///
  /// In ar, this message translates to:
  /// **'أستاذ'**
  String get authTeacher;

  /// No description provided for @authFullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get authFullName;

  /// No description provided for @authFullNameHint.
  ///
  /// In ar, this message translates to:
  /// **'سيدنا أحمد'**
  String get authFullNameHint;

  /// No description provided for @authRegisterBtn.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get authRegisterBtn;

  /// No description provided for @authHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟  '**
  String get authHaveAccount;

  /// No description provided for @authLoginLink.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get authLoginLink;

  /// No description provided for @authPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get authPhone;

  /// No description provided for @authPhoneHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك'**
  String get authPhoneHint;

  /// No description provided for @authValidPhone.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم الهاتف'**
  String get authValidPhone;

  /// No description provided for @authValidPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير صحيح'**
  String get authValidPhoneInvalid;

  /// No description provided for @authSendOtp.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رمز التحقق'**
  String get authSendOtp;

  /// No description provided for @authForgotTitle.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get authForgotTitle;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك وسنرسل لك رمز التحقق'**
  String get authForgotSubtitle;

  /// No description provided for @authValidEmail.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الإلكتروني'**
  String get authValidEmail;

  /// No description provided for @authValidEmailFormat.
  ///
  /// In ar, this message translates to:
  /// **'بريد إلكتروني غير صحيح'**
  String get authValidEmailFormat;

  /// No description provided for @authValidPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور 6 أحرف على الأقل'**
  String get authValidPassword;

  /// No description provided for @authValidName.
  ///
  /// In ar, this message translates to:
  /// **'أدخل اسمك الكامل'**
  String get authValidName;

  /// No description provided for @authErrInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة'**
  String get authErrInvalidCredentials;

  /// No description provided for @authErrEmailNotConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تأكيد البريد الإلكتروني، تحقق من صندوق الوارد'**
  String get authErrEmailNotConfirmed;

  /// No description provided for @authErrUserNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب بهذا البريد الإلكتروني'**
  String get authErrUserNotFound;

  /// No description provided for @authErrRateLimit.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة'**
  String get authErrRateLimit;

  /// No description provided for @authErrNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالخادم، تحقق من الإنترنت'**
  String get authErrNetwork;

  /// No description provided for @authErrServer.
  ///
  /// In ar, this message translates to:
  /// **'خطأ في الخادم، أعد المحاولة لاحقاً'**
  String get authErrServer;

  /// No description provided for @authErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ، حاول مرة أخرى'**
  String get authErrGeneral;

  /// No description provided for @authErrEmailExists.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد الإلكتروني مسجّل مسبقاً، سجّل دخولك بدلاً من ذلك'**
  String get authErrEmailExists;

  /// No description provided for @authErrEmailFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة'**
  String get authErrEmailFormat;

  /// No description provided for @authErrUnexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع، حاول مرة أخرى'**
  String get authErrUnexpected;

  /// No description provided for @authErrCheckEmail.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من بريدك الإلكتروني لتأكيد الحساب'**
  String get authErrCheckEmail;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتشف الأساتذة'**
  String get homeTitle;

  /// No description provided for @homeSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن مادة أو أستاذ...'**
  String get homeSearchHint;

  /// No description provided for @homeAllSubjects.
  ///
  /// In ar, this message translates to:
  /// **'كل المواد'**
  String get homeAllSubjects;

  /// No description provided for @homeNoTeachers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أساتذة متاحون حالياً'**
  String get homeNoTeachers;

  /// No description provided for @homeAvailableNow.
  ///
  /// In ar, this message translates to:
  /// **'متاح الآن'**
  String get homeAvailableNow;

  /// No description provided for @sessionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'جلساتي'**
  String get sessionsTitle;

  /// No description provided for @sessionsTabActive.
  ///
  /// In ar, this message translates to:
  /// **'الجارية'**
  String get sessionsTabActive;

  /// No description provided for @sessionsTabPending.
  ///
  /// In ar, this message translates to:
  /// **'المعلّقة'**
  String get sessionsTabPending;

  /// No description provided for @sessionsTabEnded.
  ///
  /// In ar, this message translates to:
  /// **'المنتهية'**
  String get sessionsTabEnded;

  /// No description provided for @sessionsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات هنا'**
  String get sessionsEmpty;

  /// No description provided for @sessionsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن أستاذ وابدأ رحلتك التعليمية'**
  String get sessionsEmptyHint;

  /// No description provided for @sessionsEnterNow.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الجلسة الآن'**
  String get sessionsEnterNow;

  /// No description provided for @sessionsCompletePayment.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الدفع الآن'**
  String get sessionsCompletePayment;

  /// No description provided for @sessionsProofRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض الإثبات — أعد الرفع'**
  String get sessionsProofRejected;

  /// No description provided for @sessionStatusTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة الجلسة'**
  String get sessionStatusTitle;

  /// No description provided for @sessionNextStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة التالية'**
  String get sessionNextStep;

  /// No description provided for @sessionResponsible.
  ///
  /// In ar, this message translates to:
  /// **'المسؤول الآن'**
  String get sessionResponsible;

  /// No description provided for @sessionHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الجلسة'**
  String get sessionHistory;

  /// No description provided for @sessionSubject.
  ///
  /// In ar, this message translates to:
  /// **'المادة'**
  String get sessionSubject;

  /// No description provided for @sessionLevel.
  ///
  /// In ar, this message translates to:
  /// **'المستوى'**
  String get sessionLevel;

  /// No description provided for @sessionDate.
  ///
  /// In ar, this message translates to:
  /// **'الموعد'**
  String get sessionDate;

  /// No description provided for @sessionDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get sessionDuration;

  /// No description provided for @sessionPrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get sessionPrice;

  /// No description provided for @sessionMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{n} دقيقة'**
  String sessionMinutes(int n);

  /// No description provided for @sessionOugiya.
  ///
  /// In ar, this message translates to:
  /// **'{n} أوقية'**
  String sessionOugiya(String n);

  /// No description provided for @stateRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلب حجز جديد'**
  String get stateRequested;

  /// No description provided for @stateTeacherApproved.
  ///
  /// In ar, this message translates to:
  /// **'وافق الأستاذ'**
  String get stateTeacherApproved;

  /// No description provided for @stateTeacherRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفض الأستاذ'**
  String get stateTeacherRejected;

  /// No description provided for @stateAwaitingPayment.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار الدفع'**
  String get stateAwaitingPayment;

  /// No description provided for @statePaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع مُرسَل'**
  String get statePaymentSubmitted;

  /// No description provided for @statePaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع'**
  String get statePaymentRejected;

  /// No description provided for @statePaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفع'**
  String get statePaymentConfirmed;

  /// No description provided for @stateConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'الحجز مؤكد'**
  String get stateConfirmedBooking;

  /// No description provided for @stateActiveSession.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة جارية'**
  String get stateActiveSession;

  /// No description provided for @stateCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get stateCompleted;

  /// No description provided for @stateTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الأستاذ'**
  String get stateTeacherNoShow;

  /// No description provided for @stateStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الطالب'**
  String get stateStudentNoShow;

  /// No description provided for @stateDispute.
  ///
  /// In ar, this message translates to:
  /// **'نزاع إداري'**
  String get stateDispute;

  /// No description provided for @stateCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get stateCancelled;

  /// No description provided for @subRequested.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار رد الأستاذ'**
  String get subRequested;

  /// No description provided for @subTeacherApproved.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن إتمام الدفع'**
  String get subTeacherApproved;

  /// No description provided for @subTeacherRejected.
  ///
  /// In ar, this message translates to:
  /// **'عذراً، رفض الأستاذ طلبك'**
  String get subTeacherRejected;

  /// No description provided for @subAwaitingPayment.
  ///
  /// In ar, this message translates to:
  /// **'أرسل إثبات الدفع للمتابعة'**
  String get subAwaitingPayment;

  /// No description provided for @subPaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة تراجع إثباتك'**
  String get subPaymentSubmitted;

  /// No description provided for @subPaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'أعد رفع صورة تحويل واضحة'**
  String get subPaymentRejected;

  /// No description provided for @subPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة تؤكد حجزك'**
  String get subPaymentConfirmed;

  /// No description provided for @subConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'موعدك محجوز — استعد!'**
  String get subConfirmedBooking;

  /// No description provided for @subActiveSession.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة تسير الآن'**
  String get subActiveSession;

  /// No description provided for @subCompleted.
  ///
  /// In ar, this message translates to:
  /// **'شكراً، نتمنى لك التوفيق!'**
  String get subCompleted;

  /// No description provided for @subTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'سيُعاد المبلغ أو تُعاد الجدولة'**
  String get subTeacherNoShow;

  /// No description provided for @subStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'ستصلك أرباح الجلسة وفق السياسة'**
  String get subStudentNoShow;

  /// No description provided for @subDispute.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة تبحث في الأمر'**
  String get subDispute;

  /// No description provided for @subCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الجلسة'**
  String get subCancelled;

  /// No description provided for @respTeacher.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ — الرد على طلبك'**
  String get respTeacher;

  /// No description provided for @respStudent.
  ///
  /// In ar, this message translates to:
  /// **'أنت — إكمال الدفع'**
  String get respStudent;

  /// No description provided for @respAdmin.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة — مراجعة الإثبات'**
  String get respAdmin;

  /// No description provided for @respAdminConfirm.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة — تأكيد الجلسة'**
  String get respAdminConfirm;

  /// No description provided for @respBoth.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ والطالب — الانضمام'**
  String get respBoth;

  /// No description provided for @respDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل'**
  String get respDone;

  /// No description provided for @respNone.
  ///
  /// In ar, this message translates to:
  /// **'—'**
  String get respNone;

  /// No description provided for @nextWaitTeacher.
  ///
  /// In ar, this message translates to:
  /// **'انتظر رد الأستاذ'**
  String get nextWaitTeacher;

  /// No description provided for @nextCompletePayment.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الدفع الآن'**
  String get nextCompletePayment;

  /// No description provided for @nextWaitAdmin.
  ///
  /// In ar, this message translates to:
  /// **'انتظر مراجعة الإدارة'**
  String get nextWaitAdmin;

  /// No description provided for @nextRetryPayment.
  ///
  /// In ar, this message translates to:
  /// **'أعد رفع الإثبات'**
  String get nextRetryPayment;

  /// No description provided for @nextWaitAdminConfirm.
  ///
  /// In ar, this message translates to:
  /// **'انتظر تأكيد الجلسة'**
  String get nextWaitAdminConfirm;

  /// No description provided for @nextEnterSession.
  ///
  /// In ar, this message translates to:
  /// **'ادخل الجلسة'**
  String get nextEnterSession;

  /// No description provided for @nextRateTeacher.
  ///
  /// In ar, this message translates to:
  /// **'قيّم الأستاذ'**
  String get nextRateTeacher;

  /// No description provided for @nextRated.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت ✓'**
  String get nextRated;

  /// No description provided for @nextFindTeacher.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن أستاذ آخر'**
  String get nextFindTeacher;

  /// No description provided for @nextReschedule.
  ///
  /// In ar, this message translates to:
  /// **'أعد جدولة الجلسة'**
  String get nextReschedule;

  /// No description provided for @nextWaitDecision.
  ///
  /// In ar, this message translates to:
  /// **'انتظر قرار الإدارة'**
  String get nextWaitDecision;

  /// No description provided for @actionCancelRequest.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get actionCancelRequest;

  /// No description provided for @actionCompletePayment.
  ///
  /// In ar, this message translates to:
  /// **'إكمال الدفع'**
  String get actionCompletePayment;

  /// No description provided for @actionRetryPayment.
  ///
  /// In ar, this message translates to:
  /// **'إعادة رفع إثبات الدفع'**
  String get actionRetryPayment;

  /// No description provided for @actionEnterSession.
  ///
  /// In ar, this message translates to:
  /// **'دخول الجلسة'**
  String get actionEnterSession;

  /// No description provided for @actionEnterIn10.
  ///
  /// In ar, this message translates to:
  /// **'الدخول متاح قبل الموعد بـ 10 د'**
  String get actionEnterIn10;

  /// No description provided for @actionRateTeacher.
  ///
  /// In ar, this message translates to:
  /// **'تقييم الأستاذ'**
  String get actionRateTeacher;

  /// No description provided for @actionReschedule.
  ///
  /// In ar, this message translates to:
  /// **'إعادة جدولة الجلسة'**
  String get actionReschedule;

  /// No description provided for @actionFindTeacher.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن أستاذ آخر'**
  String get actionFindTeacher;

  /// No description provided for @actionThankRating.
  ///
  /// In ar, this message translates to:
  /// **'شكراً على تقييمك 🌟'**
  String get actionThankRating;

  /// No description provided for @dialogCancelTitle.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get dialogCancelTitle;

  /// No description provided for @dialogCancelContent.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد إلغاء هذا الطلب؟ لا يمكن التراجع.'**
  String get dialogCancelContent;

  /// No description provided for @dialogCancelConfirm.
  ///
  /// In ar, this message translates to:
  /// **'نعم، إلغاء'**
  String get dialogCancelConfirm;

  /// No description provided for @dialogBack.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get dialogBack;

  /// No description provided for @dialogRatingTitle.
  ///
  /// In ar, this message translates to:
  /// **'قيّم الأستاذ'**
  String get dialogRatingTitle;

  /// No description provided for @dialogRatingCommentHint.
  ///
  /// In ar, this message translates to:
  /// **'شارك تجربتك مع الأستاذ...'**
  String get dialogRatingCommentHint;

  /// No description provided for @dialogRatingSend.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get dialogRatingSend;

  /// No description provided for @paymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get paymentTitle;

  /// No description provided for @paymentProofSentTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال إثبات الدفع'**
  String get paymentProofSentTitle;

  /// No description provided for @paymentProofSentBody.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة ستراجع إثباتك خلال ساعة وتؤكد الحجز.'**
  String get paymentProofSentBody;

  /// No description provided for @paymentAwaitingInstruction.
  ///
  /// In ar, this message translates to:
  /// **'أرسل المبلغ عبر إحدى وسائل الدفع أدناه ثم ارفع صورة إثبات الدفع.'**
  String get paymentAwaitingInstruction;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المطلوب'**
  String get paymentAmountLabel;

  /// No description provided for @paymentChooseMethod.
  ///
  /// In ar, this message translates to:
  /// **'اختر وسيلة الدفع'**
  String get paymentChooseMethod;

  /// No description provided for @paymentAccountName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المستفيد'**
  String get paymentAccountName;

  /// No description provided for @paymentHolder.
  ///
  /// In ar, this message translates to:
  /// **'المحفظة / الرقم'**
  String get paymentHolder;

  /// No description provided for @paymentProofSection.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع'**
  String get paymentProofSection;

  /// No description provided for @paymentProofHint.
  ///
  /// In ar, this message translates to:
  /// **'ارفع صورة لقطة التحويل'**
  String get paymentProofHint;

  /// No description provided for @paymentProofHintSub.
  ///
  /// In ar, this message translates to:
  /// **'PNG · JPG حتى 5MB'**
  String get paymentProofHintSub;

  /// No description provided for @paymentWarning.
  ///
  /// In ar, this message translates to:
  /// **'لا تدفع إلا للأرقام المعروضة أعلاه. لا تبعث المبلغ لأي رقم آخر.'**
  String get paymentWarning;

  /// No description provided for @paymentSubmitBtn.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت الدفع — تأكيد'**
  String get paymentSubmitBtn;

  /// No description provided for @paymentErrNoProof.
  ///
  /// In ar, this message translates to:
  /// **'ارفع صورة إثبات الدفع أولاً'**
  String get paymentErrNoProof;

  /// No description provided for @paymentRejectedBanner.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع — أعد رفع صورة واضحة للتحويل'**
  String get paymentRejectedBanner;

  /// No description provided for @paymentDeadlineExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الدفع'**
  String get paymentDeadlineExpired;

  /// No description provided for @paymentDeadlineExpiredAction.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة إتمام الدفع — لا يمكن المتابعة. تواصل مع الدعم إن كان لديك استفسار.'**
  String get paymentDeadlineExpiredAction;

  /// No description provided for @liveConnectError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال'**
  String get liveConnectError;

  /// No description provided for @liveWaitingTeacher.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار الأستاذ لبدء الجلسة…'**
  String get liveWaitingTeacher;

  /// No description provided for @liveOver15min.
  ///
  /// In ar, this message translates to:
  /// **'تجاوزت 15 دقيقة — الأستاذ لم يبدأ'**
  String get liveOver15min;

  /// No description provided for @liveReportNoShow.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن غياب الأستاذ'**
  String get liveReportNoShow;

  /// No description provided for @liveRescheduleHint.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك إعادة الجدولة بنفس المبلغ المدفوع'**
  String get liveRescheduleHint;

  /// No description provided for @liveLeave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get liveLeave;

  /// No description provided for @liveLeaveTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الجلسة'**
  String get liveLeaveTitle;

  /// No description provided for @liveLeaveContent.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد مغادرة الجلسة؟ يمكنك العودة لاحقاً.'**
  String get liveLeaveContent;

  /// No description provided for @liveLeaveConfirm.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get liveLeaveConfirm;

  /// No description provided for @liveNoShowTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإبلاغ عن غياب الأستاذ'**
  String get liveNoShowTitle;

  /// No description provided for @liveNoShowContent.
  ///
  /// In ar, this message translates to:
  /// **'سيُسجَّل غياب الأستاذ ويمكنك إعادة الجدولة بنفس الدفعة. هل تريد المتابعة؟'**
  String get liveNoShowContent;

  /// No description provided for @liveConfirmNoShow.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الغياب'**
  String get liveConfirmNoShow;

  /// No description provided for @liveSessionNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة غير موجودة'**
  String get liveSessionNotFound;

  /// No description provided for @teacherDashboardTitle.
  ///
  /// In ar, this message translates to:
  /// **'لوحة التحكم'**
  String get teacherDashboardTitle;

  /// No description provided for @teacherRequestsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطلبات'**
  String get teacherRequestsTitle;

  /// No description provided for @teacherSessionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات'**
  String get teacherSessionsTitle;

  /// No description provided for @teacherEarningsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأرباح'**
  String get teacherEarningsTitle;

  /// No description provided for @teacherNotifTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get teacherNotifTitle;

  /// No description provided for @teacherProfileTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملفي'**
  String get teacherProfileTitle;

  /// No description provided for @teacherReviewRequestTitle.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الطلب'**
  String get teacherReviewRequestTitle;

  /// No description provided for @teacherAvailableToggle.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get teacherAvailableToggle;

  /// No description provided for @teacherAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get teacherAvailable;

  /// No description provided for @teacherUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get teacherUnavailable;

  /// No description provided for @teacherResponseTime.
  ///
  /// In ar, this message translates to:
  /// **'يُفضَّل الرد خلال 24 ساعة'**
  String get teacherResponseTime;

  /// No description provided for @teacherTodaySessions.
  ///
  /// In ar, this message translates to:
  /// **'جلسات اليوم'**
  String get teacherTodaySessions;

  /// No description provided for @teacherPendingRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات معلّقة'**
  String get teacherPendingRequests;

  /// No description provided for @teacherWeekEarnings.
  ///
  /// In ar, this message translates to:
  /// **'أرباح الأسبوع'**
  String get teacherWeekEarnings;

  /// No description provided for @teacherTotalBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد الإجمالي'**
  String get teacherTotalBalance;

  /// No description provided for @teacherTabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get teacherTabToday;

  /// No description provided for @teacherTabUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get teacherTabUpcoming;

  /// No description provided for @teacherTabCompleted.
  ///
  /// In ar, this message translates to:
  /// **'المنتهية'**
  String get teacherTabCompleted;

  /// No description provided for @teacherNoSessions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات'**
  String get teacherNoSessions;

  /// No description provided for @teacherNoRequests.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات جديدة'**
  String get teacherNoRequests;

  /// No description provided for @teacherActiveNow.
  ///
  /// In ar, this message translates to:
  /// **'جارية الآن'**
  String get teacherActiveNow;

  /// No description provided for @teacherBackToSession.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى الجلسة'**
  String get teacherBackToSession;

  /// No description provided for @teacherNoPending.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات معلّقة'**
  String get teacherNoPending;

  /// No description provided for @teacherEnterSession.
  ///
  /// In ar, this message translates to:
  /// **'دخول الجلسة'**
  String get teacherEnterSession;

  /// No description provided for @teacherRejectBtn.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get teacherRejectBtn;

  /// No description provided for @teacherApproveBtn.
  ///
  /// In ar, this message translates to:
  /// **'قبول الطلب'**
  String get teacherApproveBtn;

  /// No description provided for @teacherRejectDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'رفض الطلب'**
  String get teacherRejectDialogTitle;

  /// No description provided for @teacherRejectDialogBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إشعار الطالب بالرفض.'**
  String get teacherRejectDialogBody;

  /// No description provided for @teacherRejectReasonHint.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سبب الرفض'**
  String get teacherRejectReasonHint;

  /// No description provided for @teacherRejectReasonRequired.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب — سيُرسَل للطالب لمساعدته على الفهم'**
  String get teacherRejectReasonRequired;

  /// No description provided for @teacherNetEarning.
  ///
  /// In ar, this message translates to:
  /// **'صافي ربحك'**
  String get teacherNetEarning;

  /// No description provided for @teacherCommissionNote.
  ///
  /// In ar, this message translates to:
  /// **'من {total} − عمولة 15%'**
  String teacherCommissionNote(String total);

  /// No description provided for @teacherStillPending.
  ///
  /// In ar, this message translates to:
  /// **'أنت — الرد على الطلب خلال 24 ساعة'**
  String get teacherStillPending;

  /// No description provided for @teacherNowResponsible.
  ///
  /// In ar, this message translates to:
  /// **'المسؤول الآن'**
  String get teacherNowResponsible;

  /// No description provided for @teacherRequestProcessed.
  ///
  /// In ar, this message translates to:
  /// **'تمت معالجة هذا الطلب'**
  String get teacherRequestProcessed;

  /// No description provided for @teacherRequestRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض هذا الطلب'**
  String get teacherRequestRejected;

  /// No description provided for @teacherRequestCancelledByStudent.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الجلسة من قِبل الطالب'**
  String get teacherRequestCancelledByStudent;

  /// No description provided for @teacherSubjectLabel.
  ///
  /// In ar, this message translates to:
  /// **'المادة'**
  String get teacherSubjectLabel;

  /// No description provided for @teacherLevelLabel.
  ///
  /// In ar, this message translates to:
  /// **'المستوى الدراسي'**
  String get teacherLevelLabel;

  /// No description provided for @teacherDateLabel.
  ///
  /// In ar, this message translates to:
  /// **'الموعد المطلوب'**
  String get teacherDateLabel;

  /// No description provided for @teacherDurationLabel.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get teacherDurationLabel;

  /// No description provided for @teacherStudentNote.
  ///
  /// In ar, this message translates to:
  /// **'وصف الطلب'**
  String get teacherStudentNote;

  /// No description provided for @teacherStudentLabel.
  ///
  /// In ar, this message translates to:
  /// **'طالب'**
  String get teacherStudentLabel;

  /// No description provided for @teacherEarningsBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد المتراكم'**
  String get teacherEarningsBalance;

  /// No description provided for @teacherEarningsWithdraw.
  ///
  /// In ar, this message translates to:
  /// **'سحب الأرباح'**
  String get teacherEarningsWithdraw;

  /// No description provided for @teacherEarningsWithdrawContact.
  ///
  /// In ar, this message translates to:
  /// **'للسحب تواصل مع الإدارة: 42740370'**
  String get teacherEarningsWithdrawContact;

  /// No description provided for @teacherEarningsWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get teacherEarningsWeek;

  /// No description provided for @teacherEarningsMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get teacherEarningsMonth;

  /// No description provided for @teacherEarningsFromSessions.
  ///
  /// In ar, this message translates to:
  /// **'من الجلسات'**
  String get teacherEarningsFromSessions;

  /// No description provided for @teacherEarningsFromCourses.
  ///
  /// In ar, this message translates to:
  /// **'من الاشتراكات'**
  String get teacherEarningsFromCourses;

  /// No description provided for @teacherLedgerTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجل المدفوعات'**
  String get teacherLedgerTitle;

  /// No description provided for @teacherLedgerEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد معاملات بعد'**
  String get teacherLedgerEmpty;

  /// No description provided for @teacherLedgerPayout.
  ///
  /// In ar, this message translates to:
  /// **'تسوية — مستحقات مدفوعة'**
  String get teacherLedgerPayout;

  /// No description provided for @teacherStatusRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get teacherStatusRequested;

  /// No description provided for @teacherStatusApproved.
  ///
  /// In ar, this message translates to:
  /// **'قبلت الطلب'**
  String get teacherStatusApproved;

  /// No description provided for @teacherStatusRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفضت الطلب'**
  String get teacherStatusRejected;

  /// No description provided for @teacherStatusPaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع قيد المراجعة'**
  String get teacherStatusPaymentSubmitted;

  /// No description provided for @teacherStatusPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'الدفع مؤكد — الحجز مُثبَّت'**
  String get teacherStatusPaymentConfirmed;

  /// No description provided for @teacherStatusConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مؤكدة'**
  String get teacherStatusConfirmedBooking;

  /// No description provided for @teacherStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة جارية الآن'**
  String get teacherStatusActive;

  /// No description provided for @teacherStatusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مكتملة'**
  String get teacherStatusCompleted;

  /// No description provided for @teacherStatusNoShow.
  ///
  /// In ar, this message translates to:
  /// **'سُجِّل غيابك في هذه الجلسة'**
  String get teacherStatusNoShow;

  /// No description provided for @teacherStatusStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'لم يحضر الطالب. ستصلك أرباح الجلسة كاملةً وفق سياسة المنصة.'**
  String get teacherStatusStudentNoShow;

  /// No description provided for @teacherStatusDispute.
  ///
  /// In ar, this message translates to:
  /// **'هذه الجلسة قيد النزاع الإداري'**
  String get teacherStatusDispute;

  /// No description provided for @teacherStatusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ألغى الطالب الجلسة'**
  String get teacherStatusCancelled;

  /// No description provided for @teacherStatusProcessed.
  ///
  /// In ar, this message translates to:
  /// **'تم التعامل مع هذه الجلسة'**
  String get teacherStatusProcessed;

  /// No description provided for @teacherEnterSessionBtn.
  ///
  /// In ar, this message translates to:
  /// **'دخول الجلسة'**
  String get teacherEnterSessionBtn;

  /// No description provided for @teacherSessionEntryNote.
  ///
  /// In ar, this message translates to:
  /// **'الدخول متاح قبل الموعد بـ 10 د'**
  String get teacherSessionEntryNote;

  /// No description provided for @coursesMyCourses.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكاتي'**
  String get coursesMyCourses;

  /// No description provided for @coursesTabActive.
  ///
  /// In ar, this message translates to:
  /// **'الفعّالة'**
  String get coursesTabActive;

  /// No description provided for @coursesTabPending.
  ///
  /// In ar, this message translates to:
  /// **'المعلّقة'**
  String get coursesTabPending;

  /// No description provided for @coursesTabExpired.
  ///
  /// In ar, this message translates to:
  /// **'المنتهية'**
  String get coursesTabExpired;

  /// No description provided for @coursesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد اشتراكات بعد'**
  String get coursesEmpty;

  /// No description provided for @coursesEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'تصفح الكورسات وابدأ رحلتك التعليمية'**
  String get coursesEmptyHint;

  /// No description provided for @coursesBrowse.
  ///
  /// In ar, this message translates to:
  /// **'تصفح الكورسات'**
  String get coursesBrowse;

  /// No description provided for @coursesProgress.
  ///
  /// In ar, this message translates to:
  /// **'التقدم'**
  String get coursesProgress;

  /// No description provided for @coursesExpiry.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في'**
  String get coursesExpiry;

  /// No description provided for @coursesResubscribe.
  ///
  /// In ar, this message translates to:
  /// **'تجديد الاشتراك'**
  String get coursesResubscribe;

  /// No description provided for @coursesSubPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد الموافقة'**
  String get coursesSubPending;

  /// No description provided for @coursesSubRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get coursesSubRejected;

  /// No description provided for @courseLesson.
  ///
  /// In ar, this message translates to:
  /// **'درس'**
  String get courseLesson;

  /// No description provided for @courseLessons.
  ///
  /// In ar, this message translates to:
  /// **'دروس'**
  String get courseLessons;

  /// No description provided for @profileTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملفي الشخصي'**
  String get profileTitle;

  /// No description provided for @profileEditProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get profileEditProfile;

  /// No description provided for @profileChangePassword.
  ///
  /// In ar, this message translates to:
  /// **'تغيير كلمة المرور'**
  String get profileChangePassword;

  /// No description provided for @profilePaymentHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل المدفوعات'**
  String get profilePaymentHistory;

  /// No description provided for @profileMyRatings.
  ///
  /// In ar, this message translates to:
  /// **'تقييماتي'**
  String get profileMyRatings;

  /// No description provided for @profileHelpCenter.
  ///
  /// In ar, this message translates to:
  /// **'مركز المساعدة'**
  String get profileHelpCenter;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileTerms.
  ///
  /// In ar, this message translates to:
  /// **'الشروط والأحكام'**
  String get profileTerms;

  /// No description provided for @profileLogout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد تسجيل الخروج؟'**
  String get profileLogoutConfirm;

  /// No description provided for @profileVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار'**
  String get profileVersion;

  /// No description provided for @notifTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifTitle;

  /// No description provided for @notifEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إشعارات'**
  String get notifEmpty;

  /// No description provided for @notifMarkAll.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل كمقروء'**
  String get notifMarkAll;

  /// No description provided for @notifTypeSessionRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلب حجز جديد'**
  String get notifTypeSessionRequested;

  /// No description provided for @notifTypeTeacherApproved.
  ///
  /// In ar, this message translates to:
  /// **'وافق الأستاذ على طلبك'**
  String get notifTypeTeacherApproved;

  /// No description provided for @notifTypeTeacherRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض طلبك'**
  String get notifTypeTeacherRejected;

  /// No description provided for @notifTypePaymentRequired.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الدفع'**
  String get notifTypePaymentRequired;

  /// No description provided for @notifTypePaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الدفع'**
  String get notifTypePaymentConfirmed;

  /// No description provided for @notifTypeSessionConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد الحجز'**
  String get notifTypeSessionConfirmed;

  /// No description provided for @notifTypeSessionStarting.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة تبدأ قريباً'**
  String get notifTypeSessionStarting;

  /// No description provided for @notifTypeTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الأستاذ'**
  String get notifTypeTeacherNoShow;

  /// No description provided for @notifTypeStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الطالب'**
  String get notifTypeStudentNoShow;

  /// No description provided for @notifTypeSessionCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت جلستك'**
  String get notifTypeSessionCompleted;

  /// No description provided for @notifTypeDisputeOpened.
  ///
  /// In ar, this message translates to:
  /// **'نزاع مفتوح'**
  String get notifTypeDisputeOpened;

  /// No description provided for @notifTypeRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'تم إعادة الجدولة'**
  String get notifTypeRescheduled;

  /// No description provided for @notifTypeSubPending.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك قيد المراجعة'**
  String get notifTypeSubPending;

  /// No description provided for @notifTypeSubActive.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك مُفعَّل'**
  String get notifTypeSubActive;

  /// No description provided for @notifTypeSubRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض اشتراكك'**
  String get notifTypeSubRejected;

  /// No description provided for @langArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get langArabic;

  /// No description provided for @langFrench.
  ///
  /// In ar, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// No description provided for @langSwitcher.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get langSwitcher;

  /// No description provided for @sessionNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة غير موجودة'**
  String get sessionNotFound;

  /// No description provided for @sessionLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الجلسة'**
  String get sessionLoadError;

  /// No description provided for @sessionListLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الجلسات'**
  String get sessionListLoadError;

  /// No description provided for @notifLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الإشعارات'**
  String get notifLoadError;

  /// No description provided for @paymentRejectedTitle.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع'**
  String get paymentRejectedTitle;

  /// No description provided for @paymentFakeProofLabel.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع مزيف — يرجى رفع إثبات حقيقي'**
  String get paymentFakeProofLabel;

  /// No description provided for @paymentFakeInstruction.
  ///
  /// In ar, this message translates to:
  /// **'يرجى رفع صورة إثبات دفع صحيحة خلال المهلة المحددة.'**
  String get paymentFakeInstruction;

  /// No description provided for @paymentAmountInstruction.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسوية المبلغ كاملاً وإعادة رفع الإثبات خلال المهلة.'**
  String get paymentAmountInstruction;

  /// No description provided for @paymentDeadlineExpiredMsg.
  ///
  /// In ar, this message translates to:
  /// **'انتهت المهلة — سيُلغى الطلب تلقائياً'**
  String get paymentDeadlineExpiredMsg;

  /// No description provided for @paymentDeadlineContactSupport.
  ///
  /// In ar, this message translates to:
  /// **'سيُلغى الطلب تلقائياً — تواصل مع الدعم إن احتجت مساعدة'**
  String get paymentDeadlineContactSupport;

  /// No description provided for @paymentRemainingTime.
  ///
  /// In ar, this message translates to:
  /// **'المهلة المتبقية: {time}'**
  String paymentRemainingTime(String time);

  /// No description provided for @paymentTimeLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي: {time}'**
  String paymentTimeLabel(String time);

  /// No description provided for @paymentDeadlineLabel.
  ///
  /// In ar, this message translates to:
  /// **'مهلة إكمال الدفع'**
  String get paymentDeadlineLabel;

  /// No description provided for @paymentConfirmedTitle.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إعداد الحجز…'**
  String get paymentConfirmedTitle;

  /// No description provided for @paymentConfirmedInfo.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد دفعتك. سيتم تثبيت موعد جلستك تلقائياً خلال لحظات وستصل إشعاراً بذلك.'**
  String get paymentConfirmedInfo;

  /// No description provided for @actionCancelFinal.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الجلسة نهائياً'**
  String get actionCancelFinal;

  /// No description provided for @dialogCancelConfirmText2.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد؟ سيتم إلغاء الطلب نهائياً.'**
  String get dialogCancelConfirmText2;

  /// No description provided for @dialogBack2.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get dialogBack2;

  /// No description provided for @dialogRatingCommentOptional.
  ///
  /// In ar, this message translates to:
  /// **'تعليق اختياري…'**
  String get dialogRatingCommentOptional;

  /// No description provided for @ratingThanksSnackbar.
  ///
  /// In ar, this message translates to:
  /// **'شكراً على تقييمك!'**
  String get ratingThanksSnackbar;

  /// No description provided for @sessionRatingThanks.
  ///
  /// In ar, this message translates to:
  /// **'شكراً على تقييمك للأستاذ.'**
  String get sessionRatingThanks;

  /// No description provided for @sessionTeacherRejectedInfo.
  ///
  /// In ar, this message translates to:
  /// **'رفض الأستاذ الطلب. يمكنك البحث عن أستاذ آخر.'**
  String get sessionTeacherRejectedInfo;

  /// No description provided for @sessionReturnSearch.
  ///
  /// In ar, this message translates to:
  /// **'العودة للبحث'**
  String get sessionReturnSearch;

  /// No description provided for @sessionCancelledInfo.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء هذه الجلسة.'**
  String get sessionCancelledInfo;

  /// No description provided for @sessionNewSession.
  ///
  /// In ar, this message translates to:
  /// **'حجز جلسة جديدة'**
  String get sessionNewSession;

  /// No description provided for @sessionStudentAbsentInfo.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل غيابك عن هذه الجلسة.'**
  String get sessionStudentAbsentInfo;

  /// No description provided for @sessionDisputeTitle.
  ///
  /// In ar, this message translates to:
  /// **'نزاع مفتوح'**
  String get sessionDisputeTitle;

  /// No description provided for @sessionDisputeInfo.
  ///
  /// In ar, this message translates to:
  /// **'فتح الأستاذ نزاعاً على هذه الجلسة. الإدارة تراجع الحالة وستتواصل معك في أقرب وقت.'**
  String get sessionDisputeInfo;

  /// No description provided for @sessionDisputeNextStep.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة التالية: انتظر قرار الإدارة — لا إجراء منك حالياً.'**
  String get sessionDisputeNextStep;

  /// No description provided for @sessionTeacherNoShowInfo.
  ///
  /// In ar, this message translates to:
  /// **'تم رصد غياب الأستاذ. يمكنك إعادة الجدولة بنفس الدفعة.'**
  String get sessionTeacherNoShowInfo;

  /// No description provided for @sessionRescheduledSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تمت إعادة الجدولة بنجاح'**
  String get sessionRescheduledSuccess;

  /// No description provided for @sessionStartDate.
  ///
  /// In ar, this message translates to:
  /// **'تبدأ الجلسة {date}'**
  String sessionStartDate(String date);

  /// No description provided for @respTeacherReview.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ — مراجعة الطلب'**
  String get respTeacherReview;

  /// No description provided for @respStudentRetry.
  ///
  /// In ar, this message translates to:
  /// **'الطالب — إعادة الإثبات'**
  String get respStudentRetry;

  /// No description provided for @respNoneWaiting.
  ///
  /// In ar, this message translates to:
  /// **'لا أحد — بانتظار الموعد'**
  String get respNoneWaiting;

  /// No description provided for @respBothJoin.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ والطالب'**
  String get respBothJoin;

  /// No description provided for @respCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get respCompleted;

  /// No description provided for @respAdminDispute.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة — حل النزاع'**
  String get respAdminDispute;

  /// No description provided for @timeNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get timeNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} دقيقة'**
  String timeMinutesAgo(int n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} ساعة'**
  String timeHoursAgo(int n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} يوم'**
  String timeDaysAgo(int n);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {n} أسبوع'**
  String timeWeeksAgo(int n);

  /// No description provided for @timeToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get timeToday;

  /// No description provided for @daySun.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get daySun;

  /// No description provided for @dayMon.
  ///
  /// In ar, this message translates to:
  /// **'الإثنين'**
  String get dayMon;

  /// No description provided for @dayTue.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get dayTue;

  /// No description provided for @dayWed.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get dayWed;

  /// No description provided for @dayThu.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get dayThu;

  /// No description provided for @dayFri.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get dayFri;

  /// No description provided for @daySat.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get daySat;

  /// No description provided for @timePM.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get timePM;

  /// No description provided for @timeAM.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get timeAM;

  /// No description provided for @greetingMorning.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير،'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In ar, this message translates to:
  /// **'مساء الخير،'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In ar, this message translates to:
  /// **'مساء النور،'**
  String get greetingEvening;

  /// No description provided for @homeTeachersTab.
  ///
  /// In ar, this message translates to:
  /// **'أساتذة'**
  String get homeTeachersTab;

  /// No description provided for @homeCoursesTab.
  ///
  /// In ar, this message translates to:
  /// **'دروس'**
  String get homeCoursesTab;

  /// No description provided for @homePackagesTab.
  ///
  /// In ar, this message translates to:
  /// **'باقات'**
  String get homePackagesTab;

  /// No description provided for @homeDetails.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get homeDetails;

  /// No description provided for @homeNoCoursesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دروس متاحة حالياً'**
  String get homeNoCoursesAvailable;

  /// No description provided for @homeNoPackagesAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد باقات متاحة حالياً'**
  String get homeNoPackagesAvailable;

  /// No description provided for @homeLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل'**
  String get homeLoadError;

  /// No description provided for @homeLessonCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} درس'**
  String homeLessonCount(int n);

  /// No description provided for @homeHoursAbbrev.
  ///
  /// In ar, this message translates to:
  /// **'{n} س'**
  String homeHoursAbbrev(String n);

  /// No description provided for @homePricePerMonth.
  ///
  /// In ar, this message translates to:
  /// **'{price} أوق/شهر'**
  String homePricePerMonth(String price);

  /// No description provided for @homePricePerYear.
  ///
  /// In ar, this message translates to:
  /// **'{price} أوق/سنة'**
  String homePricePerYear(String price);

  /// No description provided for @homeOriginalPrice.
  ///
  /// In ar, this message translates to:
  /// **'{price} أوقية'**
  String homeOriginalPrice(String price);

  /// No description provided for @homeOugiyaPerMonth.
  ///
  /// In ar, this message translates to:
  /// **'أوقية/شهر'**
  String get homeOugiyaPerMonth;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navSessions.
  ///
  /// In ar, this message translates to:
  /// **'جلساتي'**
  String get navSessions;

  /// No description provided for @navCourses.
  ///
  /// In ar, this message translates to:
  /// **'دروسي'**
  String get navCourses;

  /// No description provided for @navProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get navProfile;

  /// No description provided for @dashWelcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً،'**
  String get dashWelcome;

  /// No description provided for @dashTeacherFallback.
  ///
  /// In ar, this message translates to:
  /// **'أستاذ'**
  String get dashTeacherFallback;

  /// No description provided for @dashAvailableLabel.
  ///
  /// In ar, this message translates to:
  /// **'متاح للحجز'**
  String get dashAvailableLabel;

  /// No description provided for @dashUnavailableLabel.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get dashUnavailableLabel;

  /// No description provided for @dashWeekEarnings.
  ///
  /// In ar, this message translates to:
  /// **'أرباح هذا الأسبوع'**
  String get dashWeekEarnings;

  /// No description provided for @dashCompletedNote.
  ///
  /// In ar, this message translates to:
  /// **'{n} جلسة مكتملة · بعد عمولة 15%'**
  String dashCompletedNote(int n);

  /// No description provided for @dashNewRequests.
  ///
  /// In ar, this message translates to:
  /// **'طلبات جديدة'**
  String get dashNewRequests;

  /// No description provided for @dashAwaitingBadge.
  ///
  /// In ar, this message translates to:
  /// **'{n} بانتظارك'**
  String dashAwaitingBadge(String n);

  /// No description provided for @dashUpcomingSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات القادمة'**
  String get dashUpcomingSessions;

  /// No description provided for @dashNoUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات قادمة'**
  String get dashNoUpcoming;

  /// No description provided for @dashNewBadge.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get dashNewBadge;

  /// No description provided for @dashReviewBtn.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة وقبول'**
  String get dashReviewBtn;

  /// No description provided for @dashConfirmedBadge.
  ///
  /// In ar, this message translates to:
  /// **'مؤكّد'**
  String get dashConfirmedBadge;

  /// No description provided for @dashLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البيانات'**
  String get dashLoadError;

  /// No description provided for @dashToggleError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تغيير الحالة'**
  String get dashToggleError;

  /// No description provided for @dashStatNew.
  ///
  /// In ar, this message translates to:
  /// **'طلب جديد'**
  String get dashStatNew;

  /// No description provided for @dashStatToday.
  ///
  /// In ar, this message translates to:
  /// **'جلسات اليوم'**
  String get dashStatToday;

  /// No description provided for @dashStatAttendance.
  ///
  /// In ar, this message translates to:
  /// **'الحضور'**
  String get dashStatAttendance;

  /// No description provided for @dashInMinutes.
  ///
  /// In ar, this message translates to:
  /// **'بعد {n} دقيقة'**
  String dashInMinutes(int n);

  /// No description provided for @dashInHours.
  ///
  /// In ar, this message translates to:
  /// **'بعد {n} ساعة'**
  String dashInHours(int n);

  /// No description provided for @dashMinutesShort.
  ///
  /// In ar, this message translates to:
  /// **'{n} د'**
  String dashMinutesShort(int n);

  /// No description provided for @dashMorningLabel.
  ///
  /// In ar, this message translates to:
  /// **'صباحاً'**
  String get dashMorningLabel;

  /// No description provided for @dashEveningLabel.
  ///
  /// In ar, this message translates to:
  /// **'مساءً'**
  String get dashEveningLabel;

  /// No description provided for @dashOugiya.
  ///
  /// In ar, this message translates to:
  /// **'أوقية'**
  String get dashOugiya;

  /// No description provided for @reqTabNew.
  ///
  /// In ar, this message translates to:
  /// **'جديدة'**
  String get reqTabNew;

  /// No description provided for @reqTabInProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get reqTabInProgress;

  /// No description provided for @reqTabRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوضة'**
  String get reqTabRejected;

  /// No description provided for @reqEmptyNew.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات جديدة'**
  String get reqEmptyNew;

  /// No description provided for @reqEmptyInProgress.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات نشطة'**
  String get reqEmptyInProgress;

  /// No description provided for @reqEmptyRejected.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طلبات مرفوضة'**
  String get reqEmptyRejected;

  /// No description provided for @reqRejectedBadge.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get reqRejectedBadge;

  /// No description provided for @reqRejectedReason.
  ///
  /// In ar, this message translates to:
  /// **'السبب: {reason}'**
  String reqRejectedReason(String reason);

  /// No description provided for @sessTabToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get sessTabToday;

  /// No description provided for @sessTabUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'القادمة'**
  String get sessTabUpcoming;

  /// No description provided for @sessTabCompleted.
  ///
  /// In ar, this message translates to:
  /// **'المكتملة'**
  String get sessTabCompleted;

  /// No description provided for @sessEmptyToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات اليوم'**
  String get sessEmptyToday;

  /// No description provided for @sessEmptyUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات قادمة'**
  String get sessEmptyUpcoming;

  /// No description provided for @sessEmptyCompleted.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد جلسات مكتملة'**
  String get sessEmptyCompleted;

  /// No description provided for @sessActiveNowBadge.
  ///
  /// In ar, this message translates to:
  /// **'جلسة نشطة الآن'**
  String get sessActiveNowBadge;

  /// No description provided for @sessEarningAmount.
  ///
  /// In ar, this message translates to:
  /// **'+{amount} أوقية'**
  String sessEarningAmount(String amount);

  /// No description provided for @stateBadgeAwaitingPay.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الدفع'**
  String get stateBadgeAwaitingPay;

  /// No description provided for @stateBadgeSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار تأكيد'**
  String get stateBadgeSubmitted;

  /// No description provided for @stateBadgeConfirmedPay.
  ///
  /// In ar, this message translates to:
  /// **'دفع مؤكّد'**
  String get stateBadgeConfirmedPay;

  /// No description provided for @stateBadgeConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'مؤكّد'**
  String get stateBadgeConfirmed;

  /// No description provided for @stateBadgeActive.
  ///
  /// In ar, this message translates to:
  /// **'جارية الآن'**
  String get stateBadgeActive;

  /// No description provided for @stateBadgeTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الأستاذ'**
  String get stateBadgeTeacherNoShow;

  /// No description provided for @stateBadgeStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'غياب الطالب'**
  String get stateBadgeStudentNoShow;

  /// No description provided for @stateBadgeDispute.
  ///
  /// In ar, this message translates to:
  /// **'نزاع إداري'**
  String get stateBadgeDispute;

  /// No description provided for @stateBadgeCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get stateBadgeCompleted;

  /// No description provided for @stateBadgeCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get stateBadgeCancelled;

  /// No description provided for @stateBadgeRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوضة'**
  String get stateBadgeRejected;

  /// No description provided for @stateBadgeStudentAbsent.
  ///
  /// In ar, this message translates to:
  /// **'غياب طالب'**
  String get stateBadgeStudentAbsent;

  /// No description provided for @stateBadgeMyAbsence.
  ///
  /// In ar, this message translates to:
  /// **'غيابك'**
  String get stateBadgeMyAbsence;

  /// No description provided for @earningsCommissionText.
  ///
  /// In ar, this message translates to:
  /// **'تخصم المنصة عمولة 15% من كل جلسة ودرس مؤكّد تلقائياً.'**
  String get earningsCommissionText;

  /// No description provided for @earningsCourseDesc.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك في دورة'**
  String get earningsCourseDesc;

  /// No description provided for @earningsSessionDesc.
  ///
  /// In ar, this message translates to:
  /// **'جلسة {subject}'**
  String earningsSessionDesc(String subject);

  /// No description provided for @earningsSessionDescWithStudent.
  ///
  /// In ar, this message translates to:
  /// **'جلسة {subject} · {student}'**
  String earningsSessionDescWithStudent(String subject, String student);

  /// No description provided for @teacherSessionStatusTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة الطلب'**
  String get teacherSessionStatusTitle;

  /// No description provided for @teacherSubAwaitingPayment.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار أن يُكمل الطالب الدفع.'**
  String get teacherSubAwaitingPayment;

  /// No description provided for @teacherSubPaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة تراجع إثبات الدفع. لا إجراء منك.'**
  String get teacherSubPaymentSubmitted;

  /// No description provided for @teacherSubPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تأكّد الدفع. الجلسة ستُفتح عند موعدها.'**
  String get teacherSubPaymentConfirmed;

  /// No description provided for @teacherPaymentConfirmedWaiting.
  ///
  /// In ar, this message translates to:
  /// **'تأكّد الدفع — يجاري النظام إعداد الحجز تلقائياً. ستصل إشعاراً بمجرد تأكيد الجلسة.'**
  String get teacherPaymentConfirmedWaiting;

  /// No description provided for @teacherSubConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'الحجز مؤكّد — جلستك جاهزة. ابدأ عند الموعد.'**
  String get teacherSubConfirmedBooking;

  /// No description provided for @teacherSubActiveSession.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة جارية الآن — ادخل للانضمام.'**
  String get teacherSubActiveSession;

  /// No description provided for @teacherSubCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الجلسة. تحقق من الأرباح.'**
  String get teacherSubCompleted;

  /// No description provided for @teacherSubDispute.
  ///
  /// In ar, this message translates to:
  /// **'تم فتح نزاع. الإدارة تراجع الحالة.'**
  String get teacherSubDispute;

  /// No description provided for @teacherSubRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفضت هذا الطلب.'**
  String get teacherSubRejected;

  /// No description provided for @stepRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب'**
  String get stepRequest;

  /// No description provided for @stepApproval.
  ///
  /// In ar, this message translates to:
  /// **'موافقة'**
  String get stepApproval;

  /// No description provided for @stepPayment.
  ///
  /// In ar, this message translates to:
  /// **'دفع'**
  String get stepPayment;

  /// No description provided for @stepConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'مؤكّد'**
  String get stepConfirmed;

  /// No description provided for @stepActive.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get stepActive;

  /// No description provided for @stepCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get stepCompleted;

  /// No description provided for @sessionAmountLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get sessionAmountLabel;

  /// No description provided for @teacherMarkNoShow.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل غياب الطالب'**
  String get teacherMarkNoShow;

  /// No description provided for @teacherStudentAlreadyJoined.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه: الطالب انضم للجلسة مسبقاً. تأكّد من عدم وجود مشكلة تقنية قبل تسجيل الغياب.'**
  String get teacherStudentAlreadyJoined;

  /// No description provided for @teacherStartSession.
  ///
  /// In ar, this message translates to:
  /// **'بدء الجلسة الآن'**
  String get teacherStartSession;

  /// No description provided for @teacherCantAttend.
  ///
  /// In ar, this message translates to:
  /// **'لا أستطيع الحضور — فتح نزاع'**
  String get teacherCantAttend;

  /// No description provided for @teacherOpenDispute.
  ///
  /// In ar, this message translates to:
  /// **'فتح نزاع'**
  String get teacherOpenDispute;

  /// No description provided for @teacherDisputeDialogContent.
  ///
  /// In ar, this message translates to:
  /// **'الدفع مؤكّد — لا يمكن الإلغاء المباشر.\nسيُفتح نزاع وتراجعه الإدارة.'**
  String get teacherDisputeDialogContent;

  /// No description provided for @teacherCancelSessionContent.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إلغاء هذه الجلسة؟'**
  String get teacherCancelSessionContent;

  /// No description provided for @teacherProcessingMsg.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ المعالجة…'**
  String get teacherProcessingMsg;

  /// No description provided for @teacherCancellingMsg.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإلغاء…'**
  String get teacherCancellingMsg;

  /// No description provided for @teacherDisputingMsg.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ فتح النزاع…'**
  String get teacherDisputingMsg;

  /// No description provided for @teacherCancelSession.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الجلسة'**
  String get teacherCancelSession;

  /// No description provided for @teacherLoadRequestError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الطلب'**
  String get teacherLoadRequestError;

  /// No description provided for @teacherRequestNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الطلب غير موجود'**
  String get teacherRequestNotFound;

  /// No description provided for @commonReject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get commonReject;

  /// No description provided for @profileUserFallback.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get profileUserFallback;

  /// No description provided for @profileTotalSessions.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الجلسات'**
  String get profileTotalSessions;

  /// No description provided for @profileCompletedStat.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get profileCompletedStat;

  /// No description provided for @profileTotalPayment.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدفع'**
  String get profileTotalPayment;

  /// No description provided for @profileSectionAccount.
  ///
  /// In ar, this message translates to:
  /// **'الحساب والملف الشخصي'**
  String get profileSectionAccount;

  /// No description provided for @profileSectionSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات والمدفوعات'**
  String get profileSectionSessions;

  /// No description provided for @profileSectionSupport.
  ///
  /// In ar, this message translates to:
  /// **'الدعم'**
  String get profileSectionSupport;

  /// No description provided for @profileNotifSettings.
  ///
  /// In ar, this message translates to:
  /// **'إعدادات الإشعارات'**
  String get profileNotifSettings;

  /// No description provided for @profileSessionHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الجلسات'**
  String get profileSessionHistory;

  /// No description provided for @profileLogoutBtn.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get profileLogoutBtn;

  /// No description provided for @profileDeleteAccountBtn.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب نهائياً'**
  String get profileDeleteAccountBtn;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get profileDeleteTitle;

  /// No description provided for @profileDeleteContent.
  ///
  /// In ar, this message translates to:
  /// **'هذا الإجراء لا يمكن التراجع عنه.\nسيتم حذف جميع بياناتك بشكل نهائي.'**
  String get profileDeleteContent;

  /// No description provided for @profileDeleteFinalTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف النهائي'**
  String get profileDeleteFinalTitle;

  /// No description provided for @profileDeleteTypeHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب \"{phrase}\" للتأكيد:'**
  String profileDeleteTypeHint(String phrase);

  /// No description provided for @profileDeletePhrase.
  ///
  /// In ar, this message translates to:
  /// **'احذف حسابي'**
  String get profileDeletePhrase;

  /// No description provided for @profileAvatarUploadError.
  ///
  /// In ar, this message translates to:
  /// **'فشل رفع الصورة'**
  String get profileAvatarUploadError;

  /// No description provided for @profileDeleteAccountError.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف الحساب'**
  String get profileDeleteAccountError;

  /// No description provided for @coursesActiveCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} نشط'**
  String coursesActiveCount(int n);

  /// No description provided for @coursesLessonProgress.
  ///
  /// In ar, this message translates to:
  /// **'{completed}/{total} درس'**
  String coursesLessonProgress(int completed, int total);

  /// No description provided for @coursesPendingInfo.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع قيد المراجعة — خلال 24 ساعة'**
  String get coursesPendingInfo;

  /// No description provided for @coursesRejectedLabel.
  ///
  /// In ar, this message translates to:
  /// **'رُفض الاشتراك'**
  String get coursesRejectedLabel;

  /// No description provided for @coursesResub.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الاشتراك'**
  String get coursesResub;

  /// No description provided for @coursesExpiresOn.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}'**
  String coursesExpiresOn(String date);

  /// No description provided for @rescheduleTitle.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الجدولة'**
  String get rescheduleTitle;

  /// No description provided for @rescheduleNoShowBanner.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ لم يحضر — سيتم إنشاء جلسة جديدة مؤكّدة مباشرةً بدون دفع إضافي.'**
  String get rescheduleNoShowBanner;

  /// No description provided for @rescheduleSamePriceBanner.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إنشاء جلسة جديدة بنفس المبلغ ({amount} أوقية) وتحتاج موافقة الأستاذ.'**
  String rescheduleSamePriceBanner(String amount);

  /// No description provided for @reschedulePickDay.
  ///
  /// In ar, this message translates to:
  /// **'اختر يوماً جديداً'**
  String get reschedulePickDay;

  /// No description provided for @reschedulePickTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر وقتاً'**
  String get reschedulePickTime;

  /// No description provided for @rescheduleErrSelectTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر اليوم والوقت'**
  String get rescheduleErrSelectTime;

  /// No description provided for @rescheduleErrDoubleBooked.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت محجوز مسبقاً، اختر وقتاً آخر'**
  String get rescheduleErrDoubleBooked;

  /// No description provided for @rescheduleSubmitBtn.
  ///
  /// In ar, this message translates to:
  /// **'إرسال طلب إعادة الجدولة'**
  String get rescheduleSubmitBtn;

  /// No description provided for @helpContactTab.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا'**
  String get helpContactTab;

  /// No description provided for @helpTermsTab.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get helpTermsTab;

  /// No description provided for @helpHeroTitle.
  ///
  /// In ar, this message translates to:
  /// **'نحن هنا لمساعدتك'**
  String get helpHeroTitle;

  /// No description provided for @helpHeroSub.
  ///
  /// In ar, this message translates to:
  /// **'تواصل معنا في أي وقت وسنرد عليك في أقرب وقت ممكن'**
  String get helpHeroSub;

  /// No description provided for @helpCallUs.
  ///
  /// In ar, this message translates to:
  /// **'اتصل بنا'**
  String get helpCallUs;

  /// No description provided for @helpEmailUs.
  ///
  /// In ar, this message translates to:
  /// **'راسلنا عبر البريد'**
  String get helpEmailUs;

  /// No description provided for @helpCopied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخ {label}'**
  String helpCopied(String label);

  /// No description provided for @helpFaqTitle.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة شائعة'**
  String get helpFaqTitle;

  /// No description provided for @faqQ1.
  ///
  /// In ar, this message translates to:
  /// **'كيف أحجز جلسة مع أستاذ؟'**
  String get faqQ1;

  /// No description provided for @faqA1.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن الأستاذ المناسب في الصفحة الرئيسية، اضغط على اسمه لعرض ملفه الشخصي، ثم اضغط \"احجز جلسة\" وحدد التاريخ والوقت المناسب.'**
  String get faqA1;

  /// No description provided for @faqQ2.
  ///
  /// In ar, this message translates to:
  /// **'ما هي طرق الدفع المتاحة؟'**
  String get faqQ2;

  /// No description provided for @faqA2.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الدفع عبر التحويل المصرفي. بعد إرسال الطلب يُرسل لك رقم الحساب ويُطلب منك رفع إيصال الدفع.'**
  String get faqA2;

  /// No description provided for @faqQ3.
  ///
  /// In ar, this message translates to:
  /// **'ماذا يحدث إذا تغيّب الأستاذ؟'**
  String get faqQ3;

  /// No description provided for @faqA3.
  ///
  /// In ar, this message translates to:
  /// **'في حال واجهتَ أي مشكلة مع الأستاذ يُرجى التواصل معنا فوراً عبر الهاتف أو البريد الإلكتروني وسنعمل على حلّها.'**
  String get faqA3;

  /// No description provided for @faqQ4.
  ///
  /// In ar, this message translates to:
  /// **'كيف أُقيّم الأستاذ؟'**
  String get faqQ4;

  /// No description provided for @faqA4.
  ///
  /// In ar, this message translates to:
  /// **'بعد انتهاء الجلسة ستظهر لك نافذة لتقييم تجربتك مع الأستاذ من 1 إلى 5 نجوم مع إمكانية كتابة تعليق.'**
  String get faqA4;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In ar, this message translates to:
  /// **'# سياسة الخصوصية\n\nآخر تحديث: يناير 2025\n\n## مقدمة\n\nنحن في حصتي نلتزم بحماية خصوصيتك. توضّح هذه السياسة كيفية جمع معلوماتك واستخدامها وحمايتها عند استخدامك لتطبيقنا.\n\n## المعلومات التي نجمعها\n\nنجمع المعلومات التي تقدّمها مباشرةً عند إنشاء حساب، مثل: الاسم، عنوان البريد الإلكتروني، رقم الهاتف، وصورة الملف الشخصي. كما نجمع بيانات استخدام التطبيق مثل الجلسات المحجوزة والمدفوعات.\n\n## كيف نستخدم معلوماتك\n\nنستخدم بياناتك لتشغيل الخدمة وتحسينها، وتيسير التواصل بين الطلاب والأساتذة، ومعالجة المدفوعات، وإرسال إشعارات تتعلق بالجلسات.\n\n## مشاركة المعلومات\n\nلا نبيع بياناتك لأطراف خارجية. قد نشارك معلوماتك مع مزودي الخدمة الضروريين لتشغيل المنصة (مثل خدمات الدفع) فقط وفق اتفاقيات سرية صارمة.\n\n## حماية البيانات\n\nنستخدم تشفيراً من الدرجة الأولى لحماية بياناتك. يُخزَّن كل شيء بشكل آمن على خوادم معتمدة.\n\n## حقوقك\n\nيحق لك في أي وقت: الاطلاع على بياناتك، تصحيحها، أو طلب حذفها. تواصل معنا عبر: ahmedelkentawi@gmail.com\n\n## التواصل معنا\n\nلأي استفسار حول سياسة الخصوصية يُرجى التواصل على: 42740370 أو عبر البريد الإلكتروني: ahmedelkentawi@gmail.com'**
  String get privacyPolicyContent;

  /// No description provided for @termsContent.
  ///
  /// In ar, this message translates to:
  /// **'# شروط الاستخدام\n\nآخر تحديث: يناير 2025\n\n## قبول الشروط\n\nباستخدامك لتطبيق حصتي فإنك توافق على هذه الشروط كاملةً. إن لم توافق، يُرجى التوقف عن استخدام التطبيق.\n\n## الخدمة\n\nحصتي منصة تربط الطلاب بالأساتذة لحجز جلسات تعليمية خاصة. نحن وسيط ولسنا طرفاً في العقد بين الطالب والأستاذ.\n\n## حساب المستخدم\n\nأنت مسؤول عن الحفاظ على سرية بيانات دخولك. يجب أن تكون المعلومات المقدمة صحيحة وحديثة. يحق لنا تعليق الحسابات المخالفة للشروط.\n\n## الجلسات والمدفوعات\n\nتُعقد الجلسات وفق المواعيد المتفق عليها. يجب إتمام الدفع قبل تأكيد الجلسة. في حال الإلغاء قبل 24 ساعة يمكن استرداد المبلغ وفق سياسة الاسترداد.\n\n## سلوك المستخدم\n\nيُحظر استخدام التطبيق لأي غرض غير قانوني أو مسيء. يُحظر مشاركة محتوى الجلسات دون إذن. يُحظر انتحال شخصية الآخرين.\n\n## إخلاء المسؤولية\n\nنسعى لتقديم أفضل خدمة ممكنة، لكننا لا نضمن عدم الانقطاع. جودة التعليم تعتمد على الأستاذ وحصتي ليست مسؤولة عن النتائج التعليمية.\n\n## التعديلات\n\nنحتفظ بحق تعديل هذه الشروط في أي وقت. سيُبلَّغ المستخدمون بالتغييرات الجوهرية عبر الإشعارات داخل التطبيق.\n\n## التواصل معنا\n\nلأي استفسار: هاتف 42740370 أو البريد الإلكتروني: ahmedelkentawi@gmail.com'**
  String get termsContent;

  /// No description provided for @courseSubscribersCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} مشترك'**
  String courseSubscribersCount(String n);

  /// No description provided for @courseRatingCount.
  ///
  /// In ar, this message translates to:
  /// **'({n} تقييم)'**
  String courseRatingCount(int n);

  /// No description provided for @courseLessonsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدروس'**
  String get courseLessonsTitle;

  /// No description provided for @courseNoLessons.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دروس متاحة بعد'**
  String get courseNoLessons;

  /// No description provided for @courseLockedCount.
  ///
  /// In ar, this message translates to:
  /// **'{n} درس متاح للمشتركين'**
  String courseLockedCount(int n);

  /// No description provided for @courseLockedBody.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن للوصول إلى جميع الدروس والمحتوى'**
  String get courseLockedBody;

  /// No description provided for @courseSubscribeNow.
  ///
  /// In ar, this message translates to:
  /// **'اشترك الآن'**
  String get courseSubscribeNow;

  /// No description provided for @courseFreeLabel.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get courseFreeLabel;

  /// No description provided for @coursePriceYearly.
  ///
  /// In ar, this message translates to:
  /// **'{n} أوقية/سنة'**
  String coursePriceYearly(String n);

  /// No description provided for @courseSubscribedLabel.
  ///
  /// In ar, this message translates to:
  /// **'مشترك'**
  String get courseSubscribedLabel;

  /// No description provided for @coursePendingLabel.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get coursePendingLabel;

  /// No description provided for @courseSubPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب اشتراكك قيد المراجعة'**
  String get courseSubPendingTitle;

  /// No description provided for @courseSubPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم تفعيل اشتراكك خلال 24 ساعة بعد تأكيد الدفع من الإدارة.'**
  String get courseSubPendingBody;

  /// No description provided for @courseLessonLockedTitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا الدرس للمشتركين فقط'**
  String get courseLessonLockedTitle;

  /// No description provided for @courseLessonLockedBody.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في \"{title}\" للوصول إلى جميع الدروس'**
  String courseLessonLockedBody(String title);

  /// No description provided for @lessonQuizFallback.
  ///
  /// In ar, this message translates to:
  /// **'تمرين'**
  String get lessonQuizFallback;

  /// No description provided for @lessonDone.
  ///
  /// In ar, this message translates to:
  /// **'تم الانتهاء ✓'**
  String get lessonDone;

  /// No description provided for @lessonQuizDoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'تم الانتهاء من التمرين'**
  String get lessonQuizDoneLabel;

  /// No description provided for @lessonAnswerAll.
  ///
  /// In ar, this message translates to:
  /// **'أجب على جميع الأسئلة ({answered}/{total})'**
  String lessonAnswerAll(int answered, int total);

  /// No description provided for @lessonSubmitAnswers.
  ///
  /// In ar, this message translates to:
  /// **'تسليم الإجابات'**
  String get lessonSubmitAnswers;

  /// No description provided for @lessonQuizPassed.
  ///
  /// In ar, this message translates to:
  /// **'أحسنت! اجتزت التمرين'**
  String get lessonQuizPassed;

  /// No description provided for @lessonQuizFailed.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك المحاولة مجدداً'**
  String get lessonQuizFailed;

  /// No description provided for @lessonQuizScore.
  ///
  /// In ar, this message translates to:
  /// **'نتيجتك: {correct}/{total} صحيح ({pct}%)'**
  String lessonQuizScore(int correct, int total, int pct);

  /// No description provided for @lessonNoVideo.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد فيديو متاح لهذا الدرس'**
  String get lessonNoVideo;

  /// No description provided for @lessonVideoHint.
  ///
  /// In ar, this message translates to:
  /// **'شاهد الدرس كاملاً ثم اضغط \"تم الانتهاء\" لتسجيل تقدّمك'**
  String get lessonVideoHint;

  /// No description provided for @lessonFreePreview.
  ///
  /// In ar, this message translates to:
  /// **'هذا درس مجاني للمعاينة'**
  String get lessonFreePreview;

  /// No description provided for @lessonVideoDoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'تم الانتهاء من الدرس'**
  String get lessonVideoDoneLabel;

  /// No description provided for @lessonSubscribeToAccess.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في الدورة للوصول لجميع الدروس'**
  String get lessonSubscribeToAccess;

  /// No description provided for @lessonBackToList.
  ///
  /// In ar, this message translates to:
  /// **'العودة لقائمة الدروس'**
  String get lessonBackToList;

  /// No description provided for @lessonRatingTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف كان الدرس؟'**
  String get lessonRatingTitle;

  /// No description provided for @lessonRatingSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'قيّم هذه الدورة لمساعدة الطلاب الآخرين'**
  String get lessonRatingSubtitle;

  /// No description provided for @lessonRatingLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقاً'**
  String get lessonRatingLater;

  /// No description provided for @lessonRatingSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get lessonRatingSubmit;

  /// No description provided for @requestSentTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة الطلب'**
  String get requestSentTitle;

  /// No description provided for @requestSentBadge.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الموافقة'**
  String get requestSentBadge;

  /// No description provided for @requestSentHeadline.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلبك'**
  String get requestSentHeadline;

  /// No description provided for @requestSentBody.
  ///
  /// In ar, this message translates to:
  /// **'سيراجع الأستاذ طلبك ويردّ عادةً خلال ساعتين. سنُعلمك فور الموافقة لتنتقل إلى الدفع.'**
  String get requestSentBody;

  /// No description provided for @requestSentCancelBtn.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الطلب'**
  String get requestSentCancelBtn;

  /// No description provided for @requestSentTrackBtn.
  ///
  /// In ar, this message translates to:
  /// **'تتبّع الحالة'**
  String get requestSentTrackBtn;

  /// No description provided for @requestSentCancelConfirm.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'**
  String get requestSentCancelConfirm;

  /// No description provided for @requestSentCancelYes.
  ///
  /// In ar, this message translates to:
  /// **'نعم، إلغاء'**
  String get requestSentCancelYes;

  /// No description provided for @paymentSubmittedTitle.
  ///
  /// In ar, this message translates to:
  /// **'حالة الدفع'**
  String get paymentSubmittedTitle;

  /// No description provided for @paymentSubmittedBadge.
  ///
  /// In ar, this message translates to:
  /// **'قيد التحقق'**
  String get paymentSubmittedBadge;

  /// No description provided for @paymentSubmittedHeadline.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة تتحقق من دفعتك'**
  String get paymentSubmittedHeadline;

  /// No description provided for @paymentSubmittedBody.
  ///
  /// In ar, this message translates to:
  /// **'استلمنا إثبات التحويل. يراجعه فريق الإدارة ويؤكّده عادةً خلال 30 دقيقة. سيتحوّل الحجز إلى «مؤكّد» تلقائياً.'**
  String get paymentSubmittedBody;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوسيلة'**
  String get paymentMethodLabel;

  /// No description provided for @paymentReferenceLabel.
  ///
  /// In ar, this message translates to:
  /// **'المرجع'**
  String get paymentReferenceLabel;

  /// No description provided for @paymentSubmittedResponsibleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة — تأكيد الدفع'**
  String get paymentSubmittedResponsibleAdmin;

  /// No description provided for @paymentSubmittedViewDetails.
  ///
  /// In ar, this message translates to:
  /// **'عرض تفاصيل الجلسة'**
  String get paymentSubmittedViewDetails;

  /// No description provided for @filterTitle.
  ///
  /// In ar, this message translates to:
  /// **'تصفية النتائج'**
  String get filterTitle;

  /// No description provided for @filterReset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين'**
  String get filterReset;

  /// No description provided for @filterSubject.
  ///
  /// In ar, this message translates to:
  /// **'المادة الدراسية'**
  String get filterSubject;

  /// No description provided for @filterLevel.
  ///
  /// In ar, this message translates to:
  /// **'المستوى الدراسي'**
  String get filterLevel;

  /// No description provided for @filterPriceRange.
  ///
  /// In ar, this message translates to:
  /// **'نطاق السعر (أوقية/ساعة)'**
  String get filterPriceRange;

  /// No description provided for @filterOnlineOnly.
  ///
  /// In ar, this message translates to:
  /// **'المتاحون الآن فقط'**
  String get filterOnlineOnly;

  /// No description provided for @filterShowResults.
  ///
  /// In ar, this message translates to:
  /// **'عرض النتائج'**
  String get filterShowResults;

  /// No description provided for @subscriptionTitle.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراك'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionErrNoProof.
  ///
  /// In ar, this message translates to:
  /// **'يرجى رفع صورة إثبات الدفع أولاً'**
  String get subscriptionErrNoProof;

  /// No description provided for @subscriptionErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String subscriptionErrGeneral(String error);

  /// No description provided for @subscriptionChoosePlan.
  ///
  /// In ar, this message translates to:
  /// **'اختر الخطة'**
  String get subscriptionChoosePlan;

  /// No description provided for @subscriptionPlanMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get subscriptionPlanMonthly;

  /// No description provided for @subscriptionPerMonthLabel.
  ///
  /// In ar, this message translates to:
  /// **'كل شهر'**
  String get subscriptionPerMonthLabel;

  /// No description provided for @subscriptionPlanYearly.
  ///
  /// In ar, this message translates to:
  /// **'سنوي'**
  String get subscriptionPlanYearly;

  /// No description provided for @subscriptionSavePct.
  ///
  /// In ar, this message translates to:
  /// **'وفّر {pct}%'**
  String subscriptionSavePct(int pct);

  /// No description provided for @subscriptionTypePackage.
  ///
  /// In ar, this message translates to:
  /// **'باقة'**
  String get subscriptionTypePackage;

  /// No description provided for @subscriptionTypeCourse.
  ///
  /// In ar, this message translates to:
  /// **'درس'**
  String get subscriptionTypeCourse;

  /// No description provided for @subscriptionNoMethods.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد طرق دفع متاحة حالياً'**
  String get subscriptionNoMethods;

  /// No description provided for @subscriptionPaymentMethodLabel.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get subscriptionPaymentMethodLabel;

  /// No description provided for @subscriptionAccountNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الحساب: {number}'**
  String subscriptionAccountNumber(String number);

  /// No description provided for @subscriptionHolder.
  ///
  /// In ar, this message translates to:
  /// **'المستفيد: {holder}'**
  String subscriptionHolder(String holder);

  /// No description provided for @subscriptionProofTitle.
  ///
  /// In ar, this message translates to:
  /// **'إثبات الدفع'**
  String get subscriptionProofTitle;

  /// No description provided for @subscriptionProofHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لرفع صورة إثبات الدفع'**
  String get subscriptionProofHint;

  /// No description provided for @subscriptionPerYear.
  ///
  /// In ar, this message translates to:
  /// **'أوقية/سنة'**
  String get subscriptionPerYear;

  /// No description provided for @subscriptionPerMonth.
  ///
  /// In ar, this message translates to:
  /// **'أوقية/شهر'**
  String get subscriptionPerMonth;

  /// No description provided for @subscriptionConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الاشتراك'**
  String get subscriptionConfirm;

  /// No description provided for @subscriptionSubmitting.
  ///
  /// In ar, this message translates to:
  /// **'جاري الإرسال...'**
  String get subscriptionSubmitting;

  /// No description provided for @subscriptionReviewNote.
  ///
  /// In ar, this message translates to:
  /// **'سيُراجَع إثبات الدفع من قِبل الإدارة خلال 24 ساعة'**
  String get subscriptionReviewNote;

  /// No description provided for @subPendingActivatedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تفعيل اشتراكك!'**
  String get subPendingActivatedTitle;

  /// No description provided for @subPendingActivatedBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن الوصول لجميع محتوى الدورة.'**
  String get subPendingActivatedBody;

  /// No description provided for @subPendingRedirecting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التوجيه لدروسك...'**
  String get subPendingRedirecting;

  /// No description provided for @subPendingTitle.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك قيد المراجعة'**
  String get subPendingTitle;

  /// No description provided for @subPendingRejectedBody.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قبول إثبات الدفع. يرجى مراجعة الإدارة أو إعادة المحاولة بصورة صحيحة.'**
  String get subPendingRejectedBody;

  /// No description provided for @subPendingPendingBody.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام إثبات دفعك وسيتم تفعيل اشتراكك خلال 24 ساعة بعد مراجعة الإدارة.'**
  String get subPendingPendingBody;

  /// No description provided for @subPendingStep1.
  ///
  /// In ar, this message translates to:
  /// **'رُفع إثبات الدفع بنجاح'**
  String get subPendingStep1;

  /// No description provided for @subPendingStep2.
  ///
  /// In ar, this message translates to:
  /// **'مراجعة الإدارة (حتى 24 ساعة)'**
  String get subPendingStep2;

  /// No description provided for @subPendingStep3.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل الاشتراك والوصول للمحتوى'**
  String get subPendingStep3;

  /// No description provided for @subPendingBackCourses.
  ///
  /// In ar, this message translates to:
  /// **'العودة لدروسي'**
  String get subPendingBackCourses;

  /// No description provided for @subPendingViewCourses.
  ///
  /// In ar, this message translates to:
  /// **'عرض دروسي'**
  String get subPendingViewCourses;

  /// No description provided for @subPendingBackHome.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get subPendingBackHome;

  /// No description provided for @payHistTotalPaid.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المدفوع'**
  String get payHistTotalPaid;

  /// No description provided for @payHistTotalTransactions.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي المعاملات'**
  String get payHistTotalTransactions;

  /// No description provided for @payHistStatPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get payHistStatPending;

  /// No description provided for @payHistStatRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get payHistStatRejected;

  /// No description provided for @payHistFilterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get payHistFilterAll;

  /// No description provided for @payHistFilterSessions.
  ///
  /// In ar, this message translates to:
  /// **'الجلسات'**
  String get payHistFilterSessions;

  /// No description provided for @payHistFilterSubscriptions.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات'**
  String get payHistFilterSubscriptions;

  /// No description provided for @payHistTypeSession.
  ///
  /// In ar, this message translates to:
  /// **'جلسة'**
  String get payHistTypeSession;

  /// No description provided for @payHistTypeSubscription.
  ///
  /// In ar, this message translates to:
  /// **'اشتراك'**
  String get payHistTypeSubscription;

  /// No description provided for @payHistViewSession.
  ///
  /// In ar, this message translates to:
  /// **'عرض تفاصيل الجلسة'**
  String get payHistViewSession;

  /// No description provided for @payHistViewCourse.
  ///
  /// In ar, this message translates to:
  /// **'عرض الدورة'**
  String get payHistViewCourse;

  /// No description provided for @payHistEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات بعد'**
  String get payHistEmpty;

  /// No description provided for @payHistEmptyAll.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر هنا جميع مدفوعاتك للجلسات والاشتراكات'**
  String get payHistEmptyAll;

  /// No description provided for @payHistEmptySessions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات جلسات'**
  String get payHistEmptySessions;

  /// No description provided for @payHistEmptySubscriptions.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مدفوعات اشتراكات'**
  String get payHistEmptySubscriptions;

  /// No description provided for @payHistLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل سجل المدفوعات'**
  String get payHistLoadError;

  /// No description provided for @payHistRejectFake.
  ///
  /// In ar, this message translates to:
  /// **'الوصل مزيف — مرفوض نهائياً'**
  String get payHistRejectFake;

  /// No description provided for @payHistRejectIncompleteRefund.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير مكتمل — سيُسترد مبلغك'**
  String get payHistRejectIncompleteRefund;

  /// No description provided for @payHistRejectIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير مكتمل'**
  String get payHistRejectIncomplete;

  /// No description provided for @payHistStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get payHistStatusPending;

  /// No description provided for @payHistStatusConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم القبول'**
  String get payHistStatusConfirmed;

  /// No description provided for @payHistStatusRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get payHistStatusRejected;

  /// No description provided for @payHistStatusWaiting.
  ///
  /// In ar, this message translates to:
  /// **'قيد الانتظار'**
  String get payHistStatusWaiting;

  /// No description provided for @payHistStatusActive.
  ///
  /// In ar, this message translates to:
  /// **'مقبول — نشط'**
  String get payHistStatusActive;

  /// No description provided for @payHistStatusExpired.
  ///
  /// In ar, this message translates to:
  /// **'منتهي'**
  String get payHistStatusExpired;

  /// No description provided for @timeYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get timeYesterday;

  /// No description provided for @packageTypeLabel.
  ///
  /// In ar, this message translates to:
  /// **'باقة'**
  String get packageTypeLabel;

  /// No description provided for @packageCoursesStatLabel.
  ///
  /// In ar, this message translates to:
  /// **'دروس'**
  String get packageCoursesStatLabel;

  /// No description provided for @packageLessonsStatLabel.
  ///
  /// In ar, this message translates to:
  /// **'حصة'**
  String get packageLessonsStatLabel;

  /// No description provided for @packageNoCourses.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد دروس في هذه الباقة بعد'**
  String get packageNoCourses;

  /// No description provided for @packageCoursesTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدروس المشمولة'**
  String get packageCoursesTitle;

  /// No description provided for @packageSubscribeBtn.
  ///
  /// In ar, this message translates to:
  /// **'اشترك في الباقة'**
  String get packageSubscribeBtn;

  /// No description provided for @editProfileUploadError.
  ///
  /// In ar, this message translates to:
  /// **'فشل رفع الصورة: {error}'**
  String editProfileUploadError(String error);

  /// No description provided for @editProfileNameEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الاسم لا يمكن أن يكون فارغاً'**
  String get editProfileNameEmpty;

  /// No description provided for @editProfileSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ التعديلات بنجاح'**
  String get editProfileSaved;

  /// No description provided for @editProfileChangePhoto.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لتغيير الصورة'**
  String get editProfileChangePhoto;

  /// No description provided for @editProfileSaveBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get editProfileSaveBtn;

  /// No description provided for @changePassErrTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 8 أحرف على الأقل'**
  String get changePassErrTooShort;

  /// No description provided for @changePassErrMismatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمتا المرور غير متطابقتين'**
  String get changePassErrMismatch;

  /// No description provided for @changePassSuccess.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور بنجاح'**
  String get changePassSuccess;

  /// No description provided for @changePassErrFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تغيير كلمة المرور — تأكد من اتصالك أو سجّل دخولك مجدداً'**
  String get changePassErrFailed;

  /// No description provided for @changePassInfoBanner.
  ///
  /// In ar, this message translates to:
  /// **'ستحتاج إلى تسجيل الدخول مجدداً بعد تغيير كلمة المرور'**
  String get changePassInfoBanner;

  /// No description provided for @changePassNewLabel.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get changePassNewLabel;

  /// No description provided for @changePassNewHint.
  ///
  /// In ar, this message translates to:
  /// **'٨ أحرف على الأقل'**
  String get changePassNewHint;

  /// No description provided for @changePassConfirmLabel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get changePassConfirmLabel;

  /// No description provided for @changePassConfirmHint.
  ///
  /// In ar, this message translates to:
  /// **'أعد كتابة كلمة المرور'**
  String get changePassConfirmHint;

  /// No description provided for @authBackToLogin.
  ///
  /// In ar, this message translates to:
  /// **'العودة إلى تسجيل الدخول'**
  String get authBackToLogin;

  /// No description provided for @authSendOtpError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إرسال رمز التحقق — تحقق من الاتصال وحاول مجدداً'**
  String get authSendOtpError;

  /// No description provided for @resetPassTitle.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور الجديدة'**
  String get resetPassTitle;

  /// No description provided for @resetPassSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ كلمة مرور جديدة لرقم\n{phone}'**
  String resetPassSubtitle(String phone);

  /// No description provided for @resetPassErrTooShort.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 6 أحرف على الأقل'**
  String get resetPassErrTooShort;

  /// No description provided for @resetPassErrConfirmEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أدخل تأكيد كلمة المرور'**
  String get resetPassErrConfirmEmpty;

  /// No description provided for @resetPassSaveBtn.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كلمة المرور'**
  String get resetPassSaveBtn;

  /// No description provided for @resetPassSuccessTitle.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير كلمة المرور'**
  String get resetPassSuccessTitle;

  /// No description provided for @resetPassSuccessBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة'**
  String get resetPassSuccessBody;

  /// No description provided for @resetPassErrNotFound.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير مسجّل في التطبيق'**
  String get resetPassErrNotFound;

  /// No description provided for @resetPassErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'فشل تغيير كلمة المرور — حاول مجدداً'**
  String get resetPassErrGeneral;

  /// No description provided for @roomErrLoadMessages.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل الرسائل'**
  String get roomErrLoadMessages;

  /// No description provided for @roomErrStartSession.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر بدء الجلسة'**
  String get roomErrStartSession;

  /// No description provided for @roomErrStartCall.
  ///
  /// In ar, this message translates to:
  /// **'فشل بدء المكالمة'**
  String get roomErrStartCall;

  /// No description provided for @roomErrSendText.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال الرسالة'**
  String get roomErrSendText;

  /// No description provided for @roomErrSendImage.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال الصورة'**
  String get roomErrSendImage;

  /// No description provided for @roomErrSendFile.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال الملف'**
  String get roomErrSendFile;

  /// No description provided for @roomErrMicPermission.
  ///
  /// In ar, this message translates to:
  /// **'يرجى السماح للتطبيق بالوصول إلى الميكروفون'**
  String get roomErrMicPermission;

  /// No description provided for @roomErrStartRecording.
  ///
  /// In ar, this message translates to:
  /// **'فشل بدء التسجيل'**
  String get roomErrStartRecording;

  /// No description provided for @roomErrSendAudio.
  ///
  /// In ar, this message translates to:
  /// **'فشل إرسال التسجيل الصوتي'**
  String get roomErrSendAudio;

  /// No description provided for @roomErrSaveImage.
  ///
  /// In ar, this message translates to:
  /// **'فشل حفظ الصورة'**
  String get roomErrSaveImage;

  /// No description provided for @roomErrDownloadFile.
  ///
  /// In ar, this message translates to:
  /// **'فشل تحميل الملف'**
  String get roomErrDownloadFile;

  /// No description provided for @roomEditMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الرسالة'**
  String get roomEditMessage;

  /// No description provided for @roomDeleteMessage.
  ///
  /// In ar, this message translates to:
  /// **'حذف الرسالة'**
  String get roomDeleteMessage;

  /// No description provided for @roomDeleteMessageConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيتم حذف هذه الرسالة للجميع. هل تريد المتابعة؟'**
  String get roomDeleteMessageConfirm;

  /// No description provided for @roomErrDeleteMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف الرسالة'**
  String get roomErrDeleteMessage;

  /// No description provided for @roomErrEditMessage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تعديل الرسالة'**
  String get roomErrEditMessage;

  /// No description provided for @myRatingsLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل التقييمات'**
  String get myRatingsLoadError;

  /// No description provided for @myRatingsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تقييمات بعد'**
  String get myRatingsEmpty;

  /// No description provided for @myRatingsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'بعد الانتهاء من أي درس سيُطلب منك تقييمه'**
  String get myRatingsEmptyHint;

  /// No description provided for @reqSessionTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب جلسة'**
  String get reqSessionTitle;

  /// No description provided for @reqSessionChooseLevel.
  ///
  /// In ar, this message translates to:
  /// **'اختر مستواك الدراسي'**
  String get reqSessionChooseLevel;

  /// No description provided for @reqSessionErrNoSlot.
  ///
  /// In ar, this message translates to:
  /// **'يرجى اختيار وقت متاح'**
  String get reqSessionErrNoSlot;

  /// No description provided for @reqSessionErrBooked.
  ///
  /// In ar, this message translates to:
  /// **'هذا الوقت محجوز مسبقاً، اختر وقتاً آخر'**
  String get reqSessionErrBooked;

  /// No description provided for @reqSessionErrNoLevel.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تحديد مستواك الدراسي'**
  String get reqSessionErrNoLevel;

  /// No description provided for @reqSessionErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إرسال الطلب، حاول مرة أخرى'**
  String get reqSessionErrGeneral;

  /// No description provided for @reqSessionErrLoadTeacher.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل بيانات الأستاذ'**
  String get reqSessionErrLoadTeacher;

  /// No description provided for @reqSessionTeacherNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ غير موجود'**
  String get reqSessionTeacherNotFound;

  /// No description provided for @reqSessionToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get reqSessionToday;

  /// No description provided for @reqSessionUnavailableHint.
  ///
  /// In ar, this message translates to:
  /// **'الأيام الباهتة غير متاحة للأستاذ'**
  String get reqSessionUnavailableHint;

  /// No description provided for @reqSessionNoSlotsLeft.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أوقات متاحة لهذا اليوم بعد الآن'**
  String get reqSessionNoSlotsLeft;

  /// No description provided for @reqSessionTeacherUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ غير متاح هذا اليوم'**
  String get reqSessionTeacherUnavailable;

  /// No description provided for @reqSessionSelectDay.
  ///
  /// In ar, this message translates to:
  /// **'اختر اليوم'**
  String get reqSessionSelectDay;

  /// No description provided for @reqSessionDuration.
  ///
  /// In ar, this message translates to:
  /// **'المدة'**
  String get reqSessionDuration;

  /// No description provided for @reqSessionSelectTime.
  ///
  /// In ar, this message translates to:
  /// **'اختر الوقت'**
  String get reqSessionSelectTime;

  /// No description provided for @reqSessionYourLevel.
  ///
  /// In ar, this message translates to:
  /// **'مستواك الدراسي *'**
  String get reqSessionYourLevel;

  /// No description provided for @reqSessionChooseLevelHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر مستواك الدراسي…'**
  String get reqSessionChooseLevelHint;

  /// No description provided for @reqSessionNoteLabel.
  ///
  /// In ar, this message translates to:
  /// **'وصف الطلب (اختياري)'**
  String get reqSessionNoteLabel;

  /// No description provided for @reqSessionNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'صف ما تحتاج الاستعانة به…'**
  String get reqSessionNoteHint;

  /// No description provided for @reqSessionTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي المتوقع'**
  String get reqSessionTotal;

  /// No description provided for @reqSessionPaymentNote.
  ///
  /// In ar, this message translates to:
  /// **'الدفع يبدأ بعد موافقة الأستاذ. لن يُطلب منك الدفع الآن.'**
  String get reqSessionPaymentNote;

  /// No description provided for @reqSessionSubmit.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get reqSessionSubmit;

  /// No description provided for @unitMinAbbrev.
  ///
  /// In ar, this message translates to:
  /// **'د'**
  String get unitMinAbbrev;

  /// No description provided for @unitMinFull.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get unitMinFull;

  /// No description provided for @unitOugiyaPerHour.
  ///
  /// In ar, this message translates to:
  /// **'أوقية/ساعة'**
  String get unitOugiyaPerHour;

  /// No description provided for @statusOnline.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get statusOffline;

  /// No description provided for @timeAmAbbrev.
  ///
  /// In ar, this message translates to:
  /// **'ص'**
  String get timeAmAbbrev;

  /// No description provided for @timePmAbbrev.
  ///
  /// In ar, this message translates to:
  /// **'م'**
  String get timePmAbbrev;

  /// No description provided for @liveSessionErrStart.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء بدء الجلسة'**
  String get liveSessionErrStart;

  /// No description provided for @liveSessionErrEnd.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنهاء الجلسة'**
  String get liveSessionErrEnd;

  /// No description provided for @liveSessionStudentFallback.
  ///
  /// In ar, this message translates to:
  /// **'طالب'**
  String get liveSessionStudentFallback;

  /// No description provided for @liveSessionStartBtn.
  ///
  /// In ar, this message translates to:
  /// **'بدء الجلسة الآن'**
  String get liveSessionStartBtn;

  /// No description provided for @liveSessionLive.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get liveSessionLive;

  /// No description provided for @liveSessionEndBtn.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الجلسة'**
  String get liveSessionEndBtn;

  /// No description provided for @liveSessionEndTitle.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الجلسة؟'**
  String get liveSessionEndTitle;

  /// No description provided for @liveSessionEndBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إنهاء الجلسة؟ سيُعلَم الطالب.'**
  String get liveSessionEndBody;

  /// No description provided for @liveSessionEndContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get liveSessionEndContinue;

  /// No description provided for @liveSessionEndConfirm.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء'**
  String get liveSessionEndConfirm;

  /// No description provided for @noShowTitle.
  ///
  /// In ar, this message translates to:
  /// **'غياب الطالب'**
  String get noShowTitle;

  /// No description provided for @noShowHeadline.
  ///
  /// In ar, this message translates to:
  /// **'لم ينضم الطالب'**
  String get noShowHeadline;

  /// No description provided for @noShowBodyText.
  ///
  /// In ar, this message translates to:
  /// **'لم يحضر {name}. يمكنك إنهاء الجلسة وتسجيل الغياب — يُحتسب لك الأجر وفق سياسة الحضور.'**
  String noShowBodyText(String name);

  /// No description provided for @noShowWaitTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الانتظار'**
  String get noShowWaitTime;

  /// No description provided for @noShowYourEarnings.
  ///
  /// In ar, this message translates to:
  /// **'أجرك المحفوظ'**
  String get noShowYourEarnings;

  /// No description provided for @noShowWaitMore.
  ///
  /// In ar, this message translates to:
  /// **'الانتظار أكثر'**
  String get noShowWaitMore;

  /// No description provided for @noShowRecordAndEnd.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الغياب وإنهاء'**
  String get noShowRecordAndEnd;

  /// No description provided for @noShowSuccessMsg.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل غياب الطالب — أجرك محفوظ'**
  String get noShowSuccessMsg;

  /// No description provided for @noShowStudentDefault.
  ///
  /// In ar, this message translates to:
  /// **'الطالب'**
  String get noShowStudentDefault;

  /// No description provided for @noShowErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String noShowErrGeneral(String error);

  /// No description provided for @teacherRatingCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} تقييم'**
  String teacherRatingCount(int count);

  /// No description provided for @teacherRatingsEmptyHint.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر تقييمات الطلاب هنا بعد انتهاء الجلسات'**
  String get teacherRatingsEmptyHint;

  /// No description provided for @disputePrefix.
  ///
  /// In ar, this message translates to:
  /// **'نزاع #'**
  String get disputePrefix;

  /// No description provided for @disputeStatusOpen.
  ///
  /// In ar, this message translates to:
  /// **'DISPUTE · يحتاج ردّك'**
  String get disputeStatusOpen;

  /// No description provided for @disputeStatusResolved.
  ///
  /// In ar, this message translates to:
  /// **'محلول'**
  String get disputeStatusResolved;

  /// No description provided for @disputeOpenedBody.
  ///
  /// In ar, this message translates to:
  /// **'فتح الطالب نزاعاً على جلسة'**
  String get disputeOpenedBody;

  /// No description provided for @disputeResolvedBody.
  ///
  /// In ar, this message translates to:
  /// **'تم حل النزاع'**
  String get disputeResolvedBody;

  /// No description provided for @disputeDeadlineNote.
  ///
  /// In ar, this message translates to:
  /// **'قدّم ردّك وأدلتك خلال 48 ساعة، وإلا تُحسم لصالح الطالب. المبلغ مجمّد حتى القرار.'**
  String get disputeDeadlineNote;

  /// No description provided for @disputeReasonLabel.
  ///
  /// In ar, this message translates to:
  /// **'سبب النزاع'**
  String get disputeReasonLabel;

  /// No description provided for @disputeSubjectLabel.
  ///
  /// In ar, this message translates to:
  /// **'المادة'**
  String get disputeSubjectLabel;

  /// No description provided for @disputeStudentLabel.
  ///
  /// In ar, this message translates to:
  /// **'الطالب'**
  String get disputeStudentLabel;

  /// No description provided for @disputeFrozenAmtLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المجمّد'**
  String get disputeFrozenAmtLabel;

  /// No description provided for @disputeComplaintTitle.
  ///
  /// In ar, this message translates to:
  /// **'شكوى الطالب'**
  String get disputeComplaintTitle;

  /// No description provided for @disputeSentResponseTitle.
  ///
  /// In ar, this message translates to:
  /// **'ردّك المُرسَل'**
  String get disputeSentResponseTitle;

  /// No description provided for @disputeResponseHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب ردّك واشرح ما حدث من جهتك…'**
  String get disputeResponseHint;

  /// No description provided for @disputeEvidenceCount.
  ///
  /// In ar, this message translates to:
  /// **'الأدلة المرفقة ({count})'**
  String disputeEvidenceCount(int count);

  /// No description provided for @disputeImageLabel.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get disputeImageLabel;

  /// No description provided for @disputeAdminDecisionLabel.
  ///
  /// In ar, this message translates to:
  /// **'القرار النهائي بيد'**
  String get disputeAdminDecisionLabel;

  /// No description provided for @disputeAdminDecisionValue.
  ///
  /// In ar, this message translates to:
  /// **'الإدارة — بعد سماع الطرفين'**
  String get disputeAdminDecisionValue;

  /// No description provided for @disputeAttachBtn.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق دليل'**
  String get disputeAttachBtn;

  /// No description provided for @disputeSubmitBtn.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرد'**
  String get disputeSubmitBtn;

  /// No description provided for @disputeUploadErr.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر رفع الصورة: {error}'**
  String disputeUploadErr(String error);

  /// No description provided for @disputeErrEmptyResponse.
  ///
  /// In ar, this message translates to:
  /// **'يرجى كتابة ردّك أولاً'**
  String get disputeErrEmptyResponse;

  /// No description provided for @disputeResponseSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال ردّك — الإدارة ستراجعه'**
  String get disputeResponseSent;

  /// No description provided for @disputeLoadErr.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التحميل: {error}'**
  String disputeLoadErr(String error);

  /// No description provided for @disputeSubmitErr.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ: {error}'**
  String disputeSubmitErr(String error);

  /// No description provided for @availTitle.
  ///
  /// In ar, this message translates to:
  /// **'إدارة الأوقات المتاحة'**
  String get availTitle;

  /// No description provided for @availStartTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت البداية'**
  String get availStartTime;

  /// No description provided for @availEndTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت النهاية'**
  String get availEndTime;

  /// No description provided for @availErrEndBeforeStart.
  ///
  /// In ar, this message translates to:
  /// **'وقت النهاية يجب أن يكون بعد وقت البداية'**
  String get availErrEndBeforeStart;

  /// No description provided for @availErrGeneral.
  ///
  /// In ar, this message translates to:
  /// **'خطأ: {error}'**
  String availErrGeneral(String error);

  /// No description provided for @availInfoText.
  ///
  /// In ar, this message translates to:
  /// **'حدّد الأيام والساعات التي تكون متاحاً فيها. سيتمكن الطلاب من حجز جلسات في هذه الأوقات.'**
  String get availInfoText;

  /// No description provided for @availAddSlotBtn.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وقت'**
  String get availAddSlotBtn;

  /// No description provided for @availNoSlots.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أوقات محددة'**
  String get availNoSlots;

  /// No description provided for @weekdaySun.
  ///
  /// In ar, this message translates to:
  /// **'الأحد'**
  String get weekdaySun;

  /// No description provided for @weekdayMon.
  ///
  /// In ar, this message translates to:
  /// **'الاثنين'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In ar, this message translates to:
  /// **'الثلاثاء'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In ar, this message translates to:
  /// **'الأربعاء'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In ar, this message translates to:
  /// **'الخميس'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In ar, this message translates to:
  /// **'الجمعة'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In ar, this message translates to:
  /// **'السبت'**
  String get weekdaySat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In ar, this message translates to:
  /// **'الأح'**
  String get weekdayShortSun;

  /// No description provided for @weekdayShortMon.
  ///
  /// In ar, this message translates to:
  /// **'الإث'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In ar, this message translates to:
  /// **'الثل'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In ar, this message translates to:
  /// **'الأر'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In ar, this message translates to:
  /// **'الخم'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In ar, this message translates to:
  /// **'الجم'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In ar, this message translates to:
  /// **'السب'**
  String get weekdayShortSat;

  /// No description provided for @dialogCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get dialogCancel;

  /// No description provided for @dialogConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get dialogConfirm;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك كأستاذ'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In ar, this message translates to:
  /// **'أكمل ملفك الشخصي لتبدأ استقبال الطلاب. سيراجع الفريق طلبك خلال 24 ساعة.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingErrNoSubject.
  ///
  /// In ar, this message translates to:
  /// **'اختر مادة واحدة على الأقل'**
  String get onboardingErrNoSubject;

  /// No description provided for @onboardingErrMaxSubjects.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن اختيار أكثر من {max} مواد'**
  String onboardingErrMaxSubjects(int max);

  /// No description provided for @onboardingErrSave.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء الحفظ، حاول مرة أخرى'**
  String get onboardingErrSave;

  /// No description provided for @onboardingBioLabel.
  ///
  /// In ar, this message translates to:
  /// **'نبذة عنك'**
  String get onboardingBioLabel;

  /// No description provided for @onboardingBioHint.
  ///
  /// In ar, this message translates to:
  /// **'صف خبرتك وأسلوبك في التدريس…'**
  String get onboardingBioHint;

  /// No description provided for @onboardingBioTooShort.
  ///
  /// In ar, this message translates to:
  /// **'اكتب نبذة لا تقل عن 20 حرفاً'**
  String get onboardingBioTooShort;

  /// No description provided for @onboardingPriceLabel.
  ///
  /// In ar, this message translates to:
  /// **'السعر بالساعة (أوقية)'**
  String get onboardingPriceLabel;

  /// No description provided for @onboardingPriceHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: 500'**
  String get onboardingPriceHint;

  /// No description provided for @onboardingPriceRequired.
  ///
  /// In ar, this message translates to:
  /// **'أدخل السعر'**
  String get onboardingPriceRequired;

  /// No description provided for @onboardingPriceInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل سعراً صحيحاً'**
  String get onboardingPriceInvalid;

  /// No description provided for @onboardingYearsExp.
  ///
  /// In ar, this message translates to:
  /// **'سنوات الخبرة'**
  String get onboardingYearsExp;

  /// No description provided for @onboardingSubjectsLabel.
  ///
  /// In ar, this message translates to:
  /// **'المواد التي تدرّسها'**
  String get onboardingSubjectsLabel;

  /// No description provided for @onboardingSubjectsHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر مادة أو مادتين كحد أقصى ({count}/{max})'**
  String onboardingSubjectsHint(int count, int max);

  /// No description provided for @onboardingInfoNote.
  ///
  /// In ar, this message translates to:
  /// **'بعد إرسال طلبك، سيتحقق الفريق من بياناتك ويُفعّل حسابك خلال 24 ساعة.'**
  String get onboardingInfoNote;

  /// No description provided for @onboardingSubmitBtn.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب للمراجعة'**
  String get onboardingSubmitBtn;

  /// No description provided for @onboardingSkipBtn.
  ///
  /// In ar, this message translates to:
  /// **'تخطي — سأكمل لاحقاً'**
  String get onboardingSkipBtn;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountBody.
  ///
  /// In ar, this message translates to:
  /// **'هذا الإجراء لا يمكن التراجع عنه.\nسيتم حذف جميع بياناتك بشكل نهائي.'**
  String get profileDeleteAccountBody;

  /// No description provided for @profileDeleteBtn.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get profileDeleteBtn;

  /// No description provided for @profileDeleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف النهائي'**
  String get profileDeleteConfirmTitle;

  /// No description provided for @profileDeleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب \"{phrase}\" للتأكيد:'**
  String profileDeleteConfirmBody(String phrase);

  /// No description provided for @profileDeleteConfirmPhrase.
  ///
  /// In ar, this message translates to:
  /// **'احذف حسابي'**
  String get profileDeleteConfirmPhrase;

  /// No description provided for @profileDeleteAccountErr.
  ///
  /// In ar, this message translates to:
  /// **'فشل حذف الحساب: {error}'**
  String profileDeleteAccountErr(String error);

  /// No description provided for @profileDeleteAccountLink.
  ///
  /// In ar, this message translates to:
  /// **'حذف الحساب نهائياً'**
  String get profileDeleteAccountLink;

  /// No description provided for @profileLogoutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من رغبتك في تسجيل الخروج؟'**
  String get profileLogoutConfirmBody;

  /// No description provided for @profileLogoutConfirmYes.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get profileLogoutConfirmYes;

  /// No description provided for @teacherDefaultName.
  ///
  /// In ar, this message translates to:
  /// **'الأستاذ'**
  String get teacherDefaultName;

  /// No description provided for @teacherStatusApprovedActive.
  ///
  /// In ar, this message translates to:
  /// **'أستاذ موثّق · نشط'**
  String get teacherStatusApprovedActive;

  /// No description provided for @teacherStatusApprovedInactive.
  ///
  /// In ar, this message translates to:
  /// **'أستاذ موثّق · غير نشط'**
  String get teacherStatusApprovedInactive;

  /// No description provided for @teacherStatusPending.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار الاعتماد'**
  String get teacherStatusPending;

  /// No description provided for @teacherStatSessions.
  ///
  /// In ar, this message translates to:
  /// **'جلسة مكتملة'**
  String get teacherStatSessions;

  /// No description provided for @teacherStatRating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم ({count})'**
  String teacherStatRating(int count);

  /// No description provided for @teacherStatAttendance.
  ///
  /// In ar, this message translates to:
  /// **'الحضور'**
  String get teacherStatAttendance;

  /// No description provided for @profileSectionEarnings.
  ///
  /// In ar, this message translates to:
  /// **'الأرباح والمدفوعات'**
  String get profileSectionEarnings;

  /// No description provided for @teacherOnboardingMenuItem.
  ///
  /// In ar, this message translates to:
  /// **'توثيق الحساب'**
  String get teacherOnboardingMenuItem;

  /// No description provided for @teacherMenuEarnings.
  ///
  /// In ar, this message translates to:
  /// **'سجل الأرباح'**
  String get teacherMenuEarnings;

  /// No description provided for @profileMenuHelp.
  ///
  /// In ar, this message translates to:
  /// **'مركز المساعدة'**
  String get profileMenuHelp;

  /// No description provided for @profileMenuPrivacy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get profileMenuPrivacy;

  /// No description provided for @profileMenuTerms.
  ///
  /// In ar, this message translates to:
  /// **'شروط الاستخدام'**
  String get profileMenuTerms;

  /// No description provided for @teacherCompleteProfile.
  ///
  /// In ar, this message translates to:
  /// **'أكمل توثيق حسابك'**
  String get teacherCompleteProfile;

  /// No description provided for @teacherCompleteProfileHint.
  ///
  /// In ar, this message translates to:
  /// **'أضف بياناتك لتبدأ استقبال الطلاب'**
  String get teacherCompleteProfileHint;

  /// No description provided for @teacherBadgeRequired.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get teacherBadgeRequired;

  /// No description provided for @profileAppVersion.
  ///
  /// In ar, this message translates to:
  /// **'حصتي · الإصدار 1.0.0'**
  String get profileAppVersion;

  /// No description provided for @teacherVerifiedBadge.
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get teacherVerifiedBadge;

  /// No description provided for @teacherYearsExpBadge.
  ///
  /// In ar, this message translates to:
  /// **'{years} سنوات خبرة'**
  String teacherYearsExpBadge(int years);

  /// No description provided for @teacherBioLabel.
  ///
  /// In ar, this message translates to:
  /// **'نبذة'**
  String get teacherBioLabel;

  /// No description provided for @teacherSubjectsTitle.
  ///
  /// In ar, this message translates to:
  /// **'المواد'**
  String get teacherSubjectsTitle;

  /// No description provided for @teacherAvailToday.
  ///
  /// In ar, this message translates to:
  /// **'الأوقات المتاحة · اليوم'**
  String get teacherAvailToday;

  /// No description provided for @teacherAvailViewWeek.
  ///
  /// In ar, this message translates to:
  /// **'عرض الأسبوع'**
  String get teacherAvailViewWeek;

  /// No description provided for @teacherNoSlotsToday.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أوقات متاحة اليوم'**
  String get teacherNoSlotsToday;

  /// No description provided for @teacherPublicReviews.
  ///
  /// In ar, this message translates to:
  /// **'تقييمات الطلاب ({count})'**
  String teacherPublicReviews(int count);

  /// No description provided for @actionViewChat.
  ///
  /// In ar, this message translates to:
  /// **'عرض المحادثة'**
  String get actionViewChat;

  /// No description provided for @actionEnterNow.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة جارية — ادخل الآن'**
  String get actionEnterNow;

  /// No description provided for @actionRequestRefund.
  ///
  /// In ar, this message translates to:
  /// **'استرداد المبلغ'**
  String get actionRequestRefund;

  /// No description provided for @actionConfirmRequest.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الطلب'**
  String get actionConfirmRequest;

  /// No description provided for @sessionRefundPendingMsg.
  ///
  /// In ar, this message translates to:
  /// **'طلبت استرداد المبلغ — بانتظار معالجة الإدارة.'**
  String get sessionRefundPendingMsg;

  /// No description provided for @dialogRefundTitle.
  ///
  /// In ar, this message translates to:
  /// **'طلب استرداد المبلغ'**
  String get dialogRefundTitle;

  /// No description provided for @dialogRefundContent.
  ///
  /// In ar, this message translates to:
  /// **'سيتم إرسال طلبك إلى الإدارة لمعالجته.\n\nلن تتمكن من إعادة الجدولة بعد هذا الطلب.'**
  String get dialogRefundContent;

  /// No description provided for @cancelledNoPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغيت — انتهت مهلة الدفع'**
  String get cancelledNoPaymentTitle;

  /// No description provided for @cancelledNoPaymentBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يُرسَل إثبات الدفع خلال المهلة المحددة فأُلغيت الجلسة تلقائياً.'**
  String get cancelledNoPaymentBody;

  /// No description provided for @cancelledFakeProofTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغيت — إثبات دفع مزيف'**
  String get cancelledFakeProofTitle;

  /// No description provided for @cancelledFakeProofBody.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع لأنه غير صحيح وانتهت المهلة المعطاة للتصحيح.'**
  String get cancelledFakeProofBody;

  /// No description provided for @cancelledInsufficientTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغيت — مبلغ منقوص (استرداد)'**
  String get cancelledInsufficientTitle;

  /// No description provided for @cancelledInsufficientBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل المبلغ وانتهت المهلة. سيُعاد إليك المبلغ المدفوع قريباً.'**
  String get cancelledInsufficientBody;

  /// No description provided for @cancelledNoShowRefundTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغيت — استرداد مبلغك'**
  String get cancelledNoShowRefundTitle;

  /// No description provided for @cancelledNoShowRefundBody.
  ///
  /// In ar, this message translates to:
  /// **'غاب الأستاذ وطلبت الاسترداد. ستُحوَّل قيمة الجلسة إليك قريباً.'**
  String get cancelledNoShowRefundBody;

  /// No description provided for @cancelledDefaultTitle.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة ملغاة'**
  String get cancelledDefaultTitle;

  /// No description provided for @cancelledDefaultBody.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الجلسة.'**
  String get cancelledDefaultBody;

  /// No description provided for @cancelledAutoDeposit.
  ///
  /// In ar, this message translates to:
  /// **'سيُودَع المبلغ في حسابك تلقائياً'**
  String get cancelledAutoDeposit;

  /// No description provided for @evtRequested.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت الطلب'**
  String get evtRequested;

  /// No description provided for @evtTeacherApproved.
  ///
  /// In ar, this message translates to:
  /// **'وافق الأستاذ على طلبك'**
  String get evtTeacherApproved;

  /// No description provided for @evtTeacherRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفض الأستاذ الطلب'**
  String get evtTeacherRejected;

  /// No description provided for @evtAwaitingPayment.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار الدفع'**
  String get evtAwaitingPayment;

  /// No description provided for @evtPaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'رفعت إثبات الدفع'**
  String get evtPaymentSubmitted;

  /// No description provided for @evtPaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع'**
  String get evtPaymentRejected;

  /// No description provided for @evtPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'أكّدت الإدارة الدفع'**
  String get evtPaymentConfirmed;

  /// No description provided for @evtConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'تأكّد الحجز'**
  String get evtConfirmedBooking;

  /// No description provided for @evtSessionStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الجلسة'**
  String get evtSessionStarted;

  /// No description provided for @evtSessionCompleted.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة'**
  String get evtSessionCompleted;

  /// No description provided for @evtActiveSession.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مباشرة'**
  String get evtActiveSession;

  /// No description provided for @evtCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الجلسة'**
  String get evtCompleted;

  /// No description provided for @evtTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'لم يحضر الأستاذ'**
  String get evtTeacherNoShow;

  /// No description provided for @evtStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل غيابك'**
  String get evtStudentNoShow;

  /// No description provided for @evtDisputeOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح نزاع'**
  String get evtDisputeOpened;

  /// No description provided for @evtCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الجلسة'**
  String get evtCancelled;

  /// No description provided for @evtRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت الجدولة'**
  String get evtRescheduled;

  /// No description provided for @evtRefundRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلبت استرداد المبلغ'**
  String get evtRefundRequested;

  /// No description provided for @evtRefundProcessed.
  ///
  /// In ar, this message translates to:
  /// **'تم استرداد مبلغك'**
  String get evtRefundProcessed;

  /// No description provided for @evtTRequested.
  ///
  /// In ar, this message translates to:
  /// **'استقبلت طلب جلسة جديداً'**
  String get evtTRequested;

  /// No description provided for @evtTApproved.
  ///
  /// In ar, this message translates to:
  /// **'وافقت على الطلب'**
  String get evtTApproved;

  /// No description provided for @evtTRejected.
  ///
  /// In ar, this message translates to:
  /// **'رفضت الطلب'**
  String get evtTRejected;

  /// No description provided for @evtTAwaitingPayment.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار دفع الطالب'**
  String get evtTAwaitingPayment;

  /// No description provided for @evtTPaymentSubmitted.
  ///
  /// In ar, this message translates to:
  /// **'رفع الطالب إثبات الدفع'**
  String get evtTPaymentSubmitted;

  /// No description provided for @evtTPaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات دفع الطالب'**
  String get evtTPaymentRejected;

  /// No description provided for @evtTPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'أكّدت الإدارة الدفع'**
  String get evtTPaymentConfirmed;

  /// No description provided for @evtTConfirmedBooking.
  ///
  /// In ar, this message translates to:
  /// **'تأكّد الحجز — الجلسة محجوزة'**
  String get evtTConfirmedBooking;

  /// No description provided for @evtTSessionStarted.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الجلسة'**
  String get evtTSessionStarted;

  /// No description provided for @evtTSessionCompleted.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة بنجاح'**
  String get evtTSessionCompleted;

  /// No description provided for @evtTActiveSession.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة مباشرة'**
  String get evtTActiveSession;

  /// No description provided for @evtTCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الجلسة'**
  String get evtTCompleted;

  /// No description provided for @evtTTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل غيابك عن الجلسة'**
  String get evtTTeacherNoShow;

  /// No description provided for @evtTStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'سجّلت غياب الطالب'**
  String get evtTStudentNoShow;

  /// No description provided for @evtTDisputeOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح نزاع على الجلسة'**
  String get evtTDisputeOpened;

  /// No description provided for @evtTCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ألغى الطالب الجلسة'**
  String get evtTCancelled;

  /// No description provided for @evtTRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت الجدولة'**
  String get evtTRescheduled;

  /// No description provided for @evtTRefundRequested.
  ///
  /// In ar, this message translates to:
  /// **'طلب الطالب استرداد المبلغ'**
  String get evtTRefundRequested;

  /// No description provided for @evtTRefundProcessed.
  ///
  /// In ar, this message translates to:
  /// **'تم معالجة الاسترداد'**
  String get evtTRefundProcessed;

  /// No description provided for @notifBodySessionRequested.
  ///
  /// In ar, this message translates to:
  /// **'طالب جديد يريد حجز جلسة معك'**
  String get notifBodySessionRequested;

  /// No description provided for @notifBodyTeacherApproved.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن إتمام الدفع'**
  String get notifBodyTeacherApproved;

  /// No description provided for @notifBodyTeacherRejected.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك البحث عن أستاذ آخر'**
  String get notifBodyTeacherRejected;

  /// No description provided for @notifBodyPaymentRequired.
  ///
  /// In ar, this message translates to:
  /// **'أرسل إثبات الدفع لتأكيد الحجز'**
  String get notifBodyPaymentRequired;

  /// No description provided for @notifBodyPaymentConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'تم تأكيد حجزك!'**
  String get notifBodyPaymentConfirmed;

  /// No description provided for @notifBodySessionConfirmed.
  ///
  /// In ar, this message translates to:
  /// **'جلستك مؤكدة — استعد!'**
  String get notifBodySessionConfirmed;

  /// No description provided for @notifBodySessionStarting.
  ///
  /// In ar, this message translates to:
  /// **'جلستك ستبدأ قريباً'**
  String get notifBodySessionStarting;

  /// No description provided for @notifBodyTeacherNoShow.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل غياب الأستاذ'**
  String get notifBodyTeacherNoShow;

  /// No description provided for @notifBodyStudentNoShow.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل غياب الطالب'**
  String get notifBodyStudentNoShow;

  /// No description provided for @notifBodySessionCompleted.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت جلستك — قيّم الأستاذ'**
  String get notifBodySessionCompleted;

  /// No description provided for @notifBodyDisputeOpened.
  ///
  /// In ar, this message translates to:
  /// **'تم فتح نزاع — ستراجع الإدارة الأمر'**
  String get notifBodyDisputeOpened;

  /// No description provided for @notifBodyRescheduled.
  ///
  /// In ar, this message translates to:
  /// **'تم إعادة جدولة جلستك'**
  String get notifBodyRescheduled;

  /// No description provided for @notifBodySubPending.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكك قيد المراجعة وسيُفعَّل خلال 24 ساعة'**
  String get notifBodySubPending;

  /// No description provided for @notifBodySubActive.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن الوصول إلى جميع المحتوى'**
  String get notifBodySubActive;

  /// No description provided for @notifBodySubRejected.
  ///
  /// In ar, this message translates to:
  /// **'لم يُقبل إثبات الدفع — أعد المحاولة أو تواصل مع الدعم'**
  String get notifBodySubRejected;

  /// No description provided for @notifTypeSessionApproved.
  ///
  /// In ar, this message translates to:
  /// **'وافق الأستاذ على طلبك 🎉'**
  String get notifTypeSessionApproved;

  /// No description provided for @notifBodySessionApproved.
  ///
  /// In ar, this message translates to:
  /// **'أرسل إثبات الدفع لتأكيد الحجز'**
  String get notifBodySessionApproved;

  /// No description provided for @notifTypePaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض إثبات الدفع'**
  String get notifTypePaymentRejected;

  /// No description provided for @notifBodyPaymentRejected.
  ///
  /// In ar, this message translates to:
  /// **'أعِد إرسال إثبات الدفع الصحيح'**
  String get notifBodyPaymentRejected;

  /// No description provided for @notifTypeDisputeResolved.
  ///
  /// In ar, this message translates to:
  /// **'تم حل النزاع ✅'**
  String get notifTypeDisputeResolved;

  /// No description provided for @notifBodyDisputeResolved.
  ///
  /// In ar, this message translates to:
  /// **'تم حل النزاع لصالحك'**
  String get notifBodyDisputeResolved;

  /// No description provided for @notifTypeRefundProcessed.
  ///
  /// In ar, this message translates to:
  /// **'تم معالجة الاسترداد ✅'**
  String get notifTypeRefundProcessed;

  /// No description provided for @notifBodyRefundProcessed.
  ///
  /// In ar, this message translates to:
  /// **'سيُحوَّل المبلغ إليك قريباً'**
  String get notifBodyRefundProcessed;

  /// No description provided for @notifTypeSubscriptionRefunded.
  ///
  /// In ar, this message translates to:
  /// **'سيُسترد مبلغك 💰'**
  String get notifTypeSubscriptionRefunded;

  /// No description provided for @notifBodySubscriptionRefunded.
  ///
  /// In ar, this message translates to:
  /// **'تم رفض الاشتراك وسيُسترد مبلغك قريباً'**
  String get notifBodySubscriptionRefunded;

  /// No description provided for @notifTypeTeacherAccountApproved.
  ///
  /// In ar, this message translates to:
  /// **'تهانينا! تم اعتماد حسابك 🎉'**
  String get notifTypeTeacherAccountApproved;

  /// No description provided for @notifBodyTeacherAccountApproved.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك الآن استقبال طلبات الجلسات من الطلاب'**
  String get notifBodyTeacherAccountApproved;

  /// No description provided for @notifTypeTeacherAccountRejected.
  ///
  /// In ar, this message translates to:
  /// **'اعتذرنا عن طلبك'**
  String get notifTypeTeacherAccountRejected;

  /// No description provided for @notifBodyTeacherAccountRejected.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن قبول طلبك حالياً. تواصل معنا للمزيد'**
  String get notifBodyTeacherAccountRejected;

  /// No description provided for @notifTypeTeacherRevoked.
  ///
  /// In ar, this message translates to:
  /// **'تم إيقاف حسابك مؤقتاً'**
  String get notifTypeTeacherRevoked;

  /// No description provided for @notifBodyTeacherRevoked.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء اعتماد حسابك. تواصل مع الإدارة للاستفسار'**
  String get notifBodyTeacherRevoked;

  /// No description provided for @notifTypeAutoCancelled.
  ///
  /// In ar, this message translates to:
  /// **'انتهت مهلة الدفع'**
  String get notifTypeAutoCancelled;

  /// No description provided for @notifBodyAutoCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء طلبك تلقائياً لعدم إتمام الدفع في الوقت المحدد'**
  String get notifBodyAutoCancelled;

  /// No description provided for @subRejectedFakeProofNote.
  ///
  /// In ar, this message translates to:
  /// **'الوصل مزيف — يرجى الاشتراك من جديد برفع وصل دفع حقيقي'**
  String get subRejectedFakeProofNote;

  /// No description provided for @subRejectedIncompleteAmountNote.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير مكتمل — سيُعاد إليك المبلغ المدفوع تلقائياً'**
  String get subRejectedIncompleteAmountNote;

  /// No description provided for @paymentIncompleteLabel.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ غير مكتمل'**
  String get paymentIncompleteLabel;

  /// No description provided for @subCancelledNoPaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغي الاشتراك — لم يُرسَل الدفع'**
  String get subCancelledNoPaymentTitle;

  /// No description provided for @subCancelledNoPaymentBody.
  ///
  /// In ar, this message translates to:
  /// **'انتهت المهلة المحددة دون إرسال إثبات الدفع، فأُلغي الاشتراك تلقائياً.'**
  String get subCancelledNoPaymentBody;

  /// No description provided for @subCancelledFakeProofTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغي الاشتراك — إثبات مزيف'**
  String get subCancelledFakeProofTitle;

  /// No description provided for @subCancelledFakeProofBody.
  ///
  /// In ar, this message translates to:
  /// **'رُفض إثبات الدفع لأنه غير صحيح وانتهت المهلة المعطاة للتصحيح.'**
  String get subCancelledFakeProofBody;

  /// No description provided for @subCancelledInsufficientTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغي الاشتراك — مبلغ منقوص'**
  String get subCancelledInsufficientTitle;

  /// No description provided for @subCancelledInsufficientBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل المبلغ المدفوع وانتهت المهلة. سيُعاد إليك المبلغ المدفوع قريباً.'**
  String get subCancelledInsufficientBody;

  /// No description provided for @subCancelledDefaultTitle.
  ///
  /// In ar, this message translates to:
  /// **'ألغي الاشتراك'**
  String get subCancelledDefaultTitle;

  /// No description provided for @subCancelledDefaultBody.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء اشتراكك.'**
  String get subCancelledDefaultBody;

  /// No description provided for @subCancelledRefundNote.
  ///
  /// In ar, this message translates to:
  /// **'سيُودَع المبلغ المدفوع في حسابك تلقائياً'**
  String get subCancelledRefundNote;

  /// No description provided for @roomChatLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل المحادثة'**
  String get roomChatLog;

  /// No description provided for @roomOnline.
  ///
  /// In ar, this message translates to:
  /// **'متصل الآن'**
  String get roomOnline;

  /// No description provided for @roomOffline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل'**
  String get roomOffline;

  /// No description provided for @roomLeave.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة'**
  String get roomLeave;

  /// No description provided for @roomLeaveTeacherTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الجلسة؟'**
  String get roomLeaveTeacherTitle;

  /// No description provided for @roomLeaveTeacherBody.
  ///
  /// In ar, this message translates to:
  /// **'الجلسة ستستمر وتُغلق تلقائياً عند انتهاء وقتها.'**
  String get roomLeaveTeacherBody;

  /// No description provided for @roomLeaveStudentTitle.
  ///
  /// In ar, this message translates to:
  /// **'مغادرة الجلسة'**
  String get roomLeaveStudentTitle;

  /// No description provided for @roomLeaveStudentBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك العودة في أي وقت أثناء بقاء الجلسة نشطة.'**
  String get roomLeaveStudentBody;

  /// No description provided for @roomWarn5Min.
  ///
  /// In ar, this message translates to:
  /// **'تبقّى 5 دقائق على انتهاء الجلسة'**
  String get roomWarn5Min;

  /// No description provided for @roomTimeUp.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت الجلسة — جارٍ الإغلاق...'**
  String get roomTimeUp;

  /// No description provided for @roomStartSession.
  ///
  /// In ar, this message translates to:
  /// **'بدء الجلسة'**
  String get roomStartSession;

  /// No description provided for @roomStudentOnline.
  ///
  /// In ar, this message translates to:
  /// **'الطالب متصل'**
  String get roomStudentOnline;

  /// No description provided for @roomStudentOffline.
  ///
  /// In ar, this message translates to:
  /// **'الطالب غير متصل'**
  String get roomStudentOffline;

  /// No description provided for @roomNoMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل مؤمّنة — ابدأ المحادثة'**
  String get roomNoMessages;

  /// No description provided for @roomNoMessagesReadOnly.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل في هذه الجلسة'**
  String get roomNoMessagesReadOnly;

  /// No description provided for @roomTypeHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالة...'**
  String get roomTypeHint;

  /// No description provided for @roomAttachImage.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get roomAttachImage;

  /// No description provided for @roomAttachFile.
  ///
  /// In ar, this message translates to:
  /// **'ملف'**
  String get roomAttachFile;

  /// No description provided for @roomAttachAudio.
  ///
  /// In ar, this message translates to:
  /// **'صوتي'**
  String get roomAttachAudio;

  /// No description provided for @roomAttachVideo.
  ///
  /// In ar, this message translates to:
  /// **'فيديو'**
  String get roomAttachVideo;

  /// No description provided for @roomRecording.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التسجيل...'**
  String get roomRecording;

  /// No description provided for @roomStopSend.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف وإرسال'**
  String get roomStopSend;

  /// No description provided for @roomNewBooking.
  ///
  /// In ar, this message translates to:
  /// **'حجز حصة جديدة'**
  String get roomNewBooking;

  /// No description provided for @roomIncomingCall.
  ///
  /// In ar, this message translates to:
  /// **'مكالمة فيديو واردة'**
  String get roomIncomingCall;

  /// No description provided for @roomCallFromStudent.
  ///
  /// In ar, this message translates to:
  /// **'من الطالب'**
  String get roomCallFromStudent;

  /// No description provided for @roomCallFromTeacher.
  ///
  /// In ar, this message translates to:
  /// **'من الأستاذ'**
  String get roomCallFromTeacher;

  /// No description provided for @roomDeclineCall.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get roomDeclineCall;

  /// No description provided for @roomAcceptCall.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get roomAcceptCall;

  /// No description provided for @roomSaveToGallery.
  ///
  /// In ar, this message translates to:
  /// **'حفظ في المعرض'**
  String get roomSaveToGallery;

  /// No description provided for @roomViewFullSize.
  ///
  /// In ar, this message translates to:
  /// **'عرض بالحجم الكامل'**
  String get roomViewFullSize;

  /// No description provided for @roomOpenInBrowser.
  ///
  /// In ar, this message translates to:
  /// **'فتح في المتصفح'**
  String get roomOpenInBrowser;

  /// No description provided for @roomFileTapHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط للفتح أو الحفظ'**
  String get roomFileTapHint;

  /// No description provided for @roomImageSaved.
  ///
  /// In ar, this message translates to:
  /// **'✓ تم حفظ الصورة في المعرض'**
  String get roomImageSaved;

  /// No description provided for @roomDownloadingFile.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل الملف...'**
  String get roomDownloadingFile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
