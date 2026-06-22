import 'package:flutter/material.dart';
import 'package:teacher_booking/l10n/app_localizations.dart';
import 'app_colors.dart';

enum SessionState {
  requested,
  teacherApproved,
  teacherRejected,
  awaitingPayment,
  paymentSubmitted,
  paymentRejected,
  paymentConfirmed,
  confirmedBooking,
  activeSession,
  completed,
  teacherNoShow,
  studentNoShow,
  dispute,
  cancelled,
}

extension SessionStateX on SessionState {
  String get label {
    switch (this) {
      case SessionState.requested:         return 'بانتظار الأستاذ';
      case SessionState.teacherApproved:   return 'وافق الأستاذ';
      case SessionState.teacherRejected:   return 'رُفض الطلب';
      case SessionState.awaitingPayment:   return 'بانتظار الدفع';
      case SessionState.paymentSubmitted:  return 'قيد التحقق';
      case SessionState.paymentRejected:   return 'رُفض الإثبات';
      case SessionState.paymentConfirmed:  return 'تأكيد الدفع';
      case SessionState.confirmedBooking:  return 'حجز مؤكّد';
      case SessionState.activeSession:     return 'جلسة مباشرة';
      case SessionState.completed:         return 'مكتملة';
      case SessionState.teacherNoShow:     return 'غياب الأستاذ';
      case SessionState.studentNoShow:     return 'غياب الطالب';
      case SessionState.dispute:           return 'نزاع إداري';
      case SessionState.cancelled:         return 'ملغاة';
    }
  }

  String localizedLabel(AppLocalizations l) {
    switch (this) {
      case SessionState.requested:         return l.stateRequested;
      case SessionState.teacherApproved:   return l.stateTeacherApproved;
      case SessionState.teacherRejected:   return l.stateTeacherRejected;
      case SessionState.awaitingPayment:   return l.stateAwaitingPayment;
      case SessionState.paymentSubmitted:  return l.statePaymentSubmitted;
      case SessionState.paymentRejected:   return l.statePaymentRejected;
      case SessionState.paymentConfirmed:  return l.statePaymentConfirmed;
      case SessionState.confirmedBooking:  return l.stateConfirmedBooking;
      case SessionState.activeSession:     return l.stateActiveSession;
      case SessionState.completed:         return l.stateCompleted;
      case SessionState.teacherNoShow:     return l.stateTeacherNoShow;
      case SessionState.studentNoShow:     return l.stateStudentNoShow;
      case SessionState.dispute:           return l.stateDispute;
      case SessionState.cancelled:         return l.stateCancelled;
    }
  }

  String get englishKey {
    switch (this) {
      case SessionState.requested:         return 'REQUESTED';
      case SessionState.teacherApproved:   return 'TEACHER_APPROVED';
      case SessionState.teacherRejected:   return 'TEACHER_REJECTED';
      case SessionState.awaitingPayment:   return 'AWAITING_PAYMENT';
      case SessionState.paymentSubmitted:  return 'PAYMENT_SUBMITTED';
      case SessionState.paymentRejected:   return 'PAYMENT_REJECTED';
      case SessionState.paymentConfirmed:  return 'PAYMENT_CONFIRMED';
      case SessionState.confirmedBooking:  return 'CONFIRMED_BOOKING';
      case SessionState.activeSession:     return 'ACTIVE_SESSION';
      case SessionState.completed:         return 'COMPLETED';
      case SessionState.teacherNoShow:     return 'TEACHER_NO_SHOW';
      case SessionState.studentNoShow:     return 'STUDENT_NO_SHOW';
      case SessionState.dispute:           return 'DISPUTE';
      case SessionState.cancelled:         return 'CANCELLED';
    }
  }

  Color get color {
    switch (this) {
      case SessionState.requested:         return AppColors.statusRequested;
      case SessionState.teacherApproved:   return AppColors.statusApproved;
      case SessionState.teacherRejected:   return AppColors.statusRejected;
      case SessionState.awaitingPayment:   return AppColors.statusApproved;
      case SessionState.paymentSubmitted:  return AppColors.statusPaymentSubmitted;
      case SessionState.paymentRejected:   return AppColors.statusRejected;
      case SessionState.paymentConfirmed:  return AppColors.statusConfirmed;
      case SessionState.confirmedBooking:  return AppColors.statusConfirmed;
      case SessionState.activeSession:     return AppColors.statusActive;
      case SessionState.completed:         return AppColors.statusCompleted;
      case SessionState.teacherNoShow:     return AppColors.statusNoShow;
      case SessionState.studentNoShow:     return AppColors.statusNoShow;
      case SessionState.dispute:           return AppColors.statusDispute;
      case SessionState.cancelled:         return AppColors.statusRejected;
    }
  }

  Color get bgColor {
    switch (this) {
      case SessionState.requested:         return AppColors.statusRequestedBg;
      case SessionState.teacherApproved:   return AppColors.statusApprovedBg;
      case SessionState.teacherRejected:   return AppColors.statusRejectedBg;
      case SessionState.awaitingPayment:   return AppColors.statusApprovedBg;
      case SessionState.paymentSubmitted:  return AppColors.statusPaymentSubmittedBg;
      case SessionState.paymentRejected:   return AppColors.statusRejectedBg;
      case SessionState.paymentConfirmed:  return AppColors.statusConfirmedBg;
      case SessionState.confirmedBooking:  return AppColors.statusConfirmedBg;
      case SessionState.activeSession:     return AppColors.statusActiveBg;
      case SessionState.completed:         return AppColors.statusCompletedBg;
      case SessionState.teacherNoShow:     return AppColors.statusRejectedBg;
      case SessionState.studentNoShow:     return AppColors.statusRejectedBg;
      case SessionState.dispute:           return AppColors.statusDisputeBg;
      case SessionState.cancelled:         return AppColors.statusRejectedBg;
    }
  }

  bool get canStudentCancel {
    return this == SessionState.requested ||
        this == SessionState.teacherApproved ||
        this == SessionState.awaitingPayment ||
        this == SessionState.paymentRejected; // student can cancel instead of retrying
  }

  bool get isTerminal {
    return this == SessionState.completed ||
        this == SessionState.teacherRejected ||
        this == SessionState.cancelled ||
        this == SessionState.teacherNoShow ||
        this == SessionState.studentNoShow ||
        this == SessionState.dispute;
  }

  static SessionState fromString(String s) {
    return SessionState.values.firstWhere(
      (e) => e.englishKey == s,
      orElse: () => SessionState.requested,
    );
  }
}
