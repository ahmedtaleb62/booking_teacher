import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class AppErrors {
  AppErrors._();

  /// Converts any exception to a user-friendly Arabic message.
  static String friendly(Object e, AppLocalizations l) {
    final raw = e.toString().toLowerCase();

    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('reach') ||
        raw.contains('offline')) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من شبكتك وحاول مجدداً.';
    }
    if (raw.contains('timeout')) {
      return 'انتهى وقت الانتظار. يرجى المحاولة مجدداً.';
    }
    if (raw.contains('permission') || raw.contains('forbidden') || raw.contains('403')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    }
    if (raw.contains('not found') || raw.contains('404')) {
      return 'البيانات المطلوبة غير موجودة.';
    }
    if (raw.contains('duplicate') || raw.contains('unique') || raw.contains('already')) {
      return 'هذه البيانات موجودة مسبقاً.';
    }
    if (raw.contains('storage') || raw.contains('upload') || raw.contains('image')) {
      return 'حدث خطأ أثناء رفع الصورة. تأكد أن حجمها لا يتجاوز 5 ميغابايت وحاول مجدداً.';
    }
    if (raw.contains('payment') || raw.contains('proof')) {
      return 'حدث خطأ في إرسال إثبات الدفع. حاول مجدداً.';
    }
    if (raw.contains('session')) {
      return 'حدث خطأ في الجلسة. حاول مجدداً أو تواصل مع الدعم.';
    }
    if (raw.contains('auth') || raw.contains('token') || raw.contains('jwt') || raw.contains('unauthorized')) {
      return 'انتهت صلاحية جلستك. سجّل دخولك مجدداً.';
    }
    if (raw.contains('server') || raw.contains('500') || raw.contains('502') || raw.contains('503')) {
      return 'خطأ في الخادم. يرجى المحاولة بعد قليل.';
    }
    return 'حدث خطأ غير متوقع. حاول مجدداً أو تواصل مع الدعم.';
  }

  /// Shows a snackbar with a friendly error message.
  static void showSnackBar(Object e, AppLocalizations l, ScaffoldMessengerState messenger) {
    messenger.showSnackBar(SnackBar(
      content: Text(friendly(e, l)),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }
}
