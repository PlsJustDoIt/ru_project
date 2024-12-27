import 'package:flutter/foundation.dart';

class Config {
  static final String apiUrl = kReleaseMode
      ? "http://86.219.194.18:5000/api"
      : "http://localhost:5000/api";

  static final String serverUrl =
      kReleaseMode ? "http://86.219.194.18:5000" : "http://localhost:5000";
}
