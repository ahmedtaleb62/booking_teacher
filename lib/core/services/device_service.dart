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
}
