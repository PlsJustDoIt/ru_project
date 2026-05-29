import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Config {
  static final String env = kReleaseMode ? "production" : "development";
  static final String apiUrl = env == "production"
      ? "https://86.219.194.18:5000/api"
      : "http://localhost:5000/api";

  static final String serverUrl = env == "production"
      ? "https://86.219.194.18:5000"
      : "http://localhost:5000";

  static Future<void> init() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
  }

  static String appVersion = '';
}
