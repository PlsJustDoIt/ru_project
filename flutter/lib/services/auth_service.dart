import 'package:dio/dio.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/user_service.dart';

class AuthService {
  final Dio _dio;
  final SecureStorage _secureStorage;
  final UserService _userService;

  AuthService({
    required Dio dio,
    required SecureStorage secureStorage,
    required UserService userService,
  })  : _dio = dio,
        _secureStorage = secureStorage,
        _userService = userService;

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final Response response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      if (response.statusCode == 200) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];

        await _secureStorage.storeAccessToken(accessToken);
        await _secureStorage.storeRefreshToken(refreshToken);
        final User? user = await _userService.getUser();
        if (user != null) {
          return {'user': user, 'success': true};
        }
        return {
          'error': 'Failed to get user',
          'success': false,
          'errorField': 'username'
        };
      }
      if (response.data['error']['field'] != null) {
        return {
          'error': response.data['error']['message'],
          'success': false,
          'errorField': response.data['error']['field']
        };
      }
      throw Exception('Failed to login: ${response.data['error']['message']}');
    } catch (e) {
      logger.e('Failed to login: $e');
      throw Exception('Failed to login: $e');
    }
  }

  Future<Map<String, dynamic>> register(
      String username, String password) async {
    try {
      final Response response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });

      if (response.statusCode == 201 && response.data != null) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];
        await _secureStorage.storeAccessToken(accessToken);
        await _secureStorage.storeRefreshToken(refreshToken);
        final User? user = await _userService.getUser();
        if (user != null) {
          return {'user': user, 'success': true};
        }
        throw Exception('Failed to get user');
      }
      if (response.data['error']['field'] == null) {
        throw Exception(
            'Failed to register: ${response.data['error']['message']}');
      }
      return {
        'error': response.data['error']['message'],
        'success': false,
        'errorField': response.data['error']['field']
      };
    } catch (e) {
      logger.e('Failed to register: $e');
      throw Exception('Failed to register: $e');
    }
  }

  Future<bool> logout() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }
      final Response response =
          await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Failed to logout: $e');
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      final Response response =
          await _dio.delete('/auth/delete-account', data: {
        'refreshToken': refreshToken,
      });
      if (response.statusCode == 200) {
        logger.i('Account deleted');
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to delete account: $e');
      return false;
    }
  }
}
