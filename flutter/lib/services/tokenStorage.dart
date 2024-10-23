import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokenstorage {
  final _secureStorage = const FlutterSecureStorage();


  Future<void> storeTokens(String accessToken, String refreshToken) async {

    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);

  }

  Future<Map<String, String?>> getTokens() async {
    
    var accessToken = await _secureStorage.read(key: 'accessToken');
    var refreshToken = await _secureStorage.read(key: 'refreshToken');

    return {'accessToken': accessToken, 'refreshToken': refreshToken};
    
    
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');

  }

}