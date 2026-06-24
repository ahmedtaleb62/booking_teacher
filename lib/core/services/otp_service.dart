import 'dart:convert';
import 'package:http/http.dart' as http;

class OtpService {
  // ── ضع مفاتيحك هنا ─────────────────────────────────────────────────────────
  static const _validationKey = 'c3u4baltUaXNxf8W';
  static const _token         = 'wqQF52vS6gIgdVeOJPCuIlItBapVlnX2';
  // ───────────────────────────────────────────────────────────────────────────

  static const _baseUrl = 'https://chinguisoft.com/api/sms/validation';

  /// Sends an OTP SMS to [phone].
  /// Returns the OTP code string on success.
  /// Throws a human-readable Arabic message on failure.
  static Future<String> sendOtp(String phone, {String lang = 'ar'}) async {
    final url = Uri.parse('$_baseUrl/$_validationKey');

    late http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Validation-token': _token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': phone, 'lang': lang}),
      );
    } catch (_) {
      throw 'تعذّر الاتصال بخادم الرسائل — تحقق من الاتصال بالإنترنت';
    }

    if (response.statusCode != 200) {
      throw 'فشل إرسال رمز التحقق (${response.statusCode})';
    }

    // Try to parse the OTP code from the response
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        final code = data['code']?.toString()
            ?? data['otp']?.toString()
            ?? data['validation_code']?.toString()
            ?? data['sms_code']?.toString()
            ?? data['pin']?.toString()
            ?? data['token']?.toString();
        if (code != null && code.isNotEmpty) return code;
      }
    } catch (_) {}

    throw 'تعذّر استخراج رمز التحقق — الاستجابة: ${response.body}';
  }

  /// Converts a phone number to a synthetic Supabase-compatible email.
  /// e.g. "44800028" → "44800028@hessati.app"
  static String phoneToEmail(String phone) {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    return '$clean@hessati.app';
  }
}
