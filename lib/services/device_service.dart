import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id; // unique hardware ID per device
  }
}
