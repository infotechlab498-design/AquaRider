import 'package:location/location.dart';

class DeviceLocation {
  static Future<bool> Function()? override;

  static bool _allowed(PermissionStatus permission) {
    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  /// True only when the phone location service is on and this app may use it.
  /// Does not show a system prompt.
  static Future<bool> isReady() async {
    if (override != null) return true;
    final location = Location();
    if (!await location.serviceEnabled()) return false;
    return _allowed(await location.hasPermission());
  }

  static Future<bool> ensureEnabled() async {
    final replacement = override;
    if (replacement != null) return replacement();
    final location = Location();
    var serviceOn = await location.serviceEnabled();
    if (!serviceOn) {
      serviceOn = await location.requestService();
      if (!serviceOn) return false;
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    return _allowed(permission);
  }
}
