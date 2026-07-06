import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Prevents screenshots and screen recording while the lesson player is open.
/// Android only — the UITextField layer trick on iOS causes a black screen crash
/// on iOS 16+ and has no reliable replacement via public APIs.
class ScreenSecureService {
  static const _channel = MethodChannel('com.hessati/secure');

  static Future<void> enable() async {
    if (kIsWeb || Platform.isIOS || Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    if (kIsWeb || Platform.isIOS || Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
