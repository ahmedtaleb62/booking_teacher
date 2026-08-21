import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable per-install identifier, used to lock a student account to a
/// single device. Persists across app updates but resets on reinstall/
/// clear-data — same tradeoff as any locally-stored identifier.
class DeviceService {
  static const _key = 'device_install_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_key, id);
    }
    return id;
  }

  /// Human-readable device name/model shown to admin — purely informational,
  /// never used to make the lock/mismatch decision (only device_id is).
  static Future<String> getDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final nickname = info.name;
        final model = info.utsname.machine;
        return nickname.isNotEmpty ? '$nickname ($model)' : model;
      }
    } catch (_) {}
    return 'جهاز غير معروف';
  }
}
