import 'package:url_launcher/url_launcher.dart';

/// Opens WhatsApp with a chat to [phone] (any formatting — digits are
/// extracted). No-op if the number is empty or WhatsApp can't be launched.
Future<void> openWhatsApp(String phone) async {
  final number = phone.replaceAll(RegExp(r'\D'), '');
  if (number.isEmpty) return;
  final uri = Uri.parse('https://wa.me/$number');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
