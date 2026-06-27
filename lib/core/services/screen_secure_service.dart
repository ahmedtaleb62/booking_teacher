import 'package:flutter/services.dart';

/// Prevents screenshots and screen recording while the lesson player is open.
/// Android: sets FLAG_SECURE on the activity window (blocks screenshots + recording previews).
/// iOS: applies the UITextField isSecureTextEntry layer trick (content appears black).
class ScreenSecureService {
  static const _channel = MethodChannel('com.hessati/secure');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
