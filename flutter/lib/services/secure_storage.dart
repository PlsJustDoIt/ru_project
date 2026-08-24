import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  final _secureStorage = const FlutterSecureStorage();

  SecureStorage._internal();

  Future<void> storeTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);
  }

  Future<void> storeAccessToken(String accessToken) async {
    await _secureStorage.write(key: "accessToken", value: accessToken);
  }

  Future<void> storeRefreshToken(String refreshToken) async {
    await _secureStorage.write(key: "refreshToken", value: refreshToken);
  }

  Future<Map<String, String?>> getTokens() async {
    var accessToken = await _secureStorage.read(key: 'accessToken');
    var refreshToken = await _secureStorage.read(key: 'refreshToken');

    return {'accessToken': accessToken, 'refreshToken': refreshToken};
  }

  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: 'accessToken');
    } catch (_) {
      return null; // DIAG: keyring indispo sous Linux/WSLg
    }
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refreshToken');
  }

  Future<void> storeGuestRestaurantId(String restaurantId) async {
    await _secureStorage.write(key: 'guestRestaurantId', value: restaurantId);
  }

  Future<String?> getGuestRestaurantId() async {
    try {
      return await _secureStorage.read(key: 'guestRestaurantId');
    } catch (_) {
      return null; // DIAG
    }
  }

  Future<void> clearGuestRestaurantId() async {
    await _secureStorage.delete(key: 'guestRestaurantId');
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');
  }
}
