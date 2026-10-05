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

  /// Traduit les erreurs connues du backend pour l'utilisateur.
  static const Map<String, String> _frenchErrors = {
    'Invalid credentials': 'Identifiant ou mot de passe incorrect',
    'User already exists': 'Ce nom d\'utilisateur est déjà pris',
    'Restaurant not found': 'Restaurant introuvable',
    'Username or password field is missing': 'Remplis les deux champs',
    'Too many attempts, please try again later.':
        'Trop de tentatives, réessaie dans quelques minutes',
  };

  /// Erreur de formulaire ({error, errorField}) à partir d'une réponse
  /// d'erreur du backend : `{error: "msg"}` ou `{error: {message, field}}`.
  /// Renvoie null si la réponse n'est pas exploitable (réseau, 5xx...).
  static Map<String, dynamic>? formErrorFrom(Response? response) {
    final data = response?.data;
    final status = response?.statusCode ?? 0;
    if (data is! Map || status < 400 || status >= 500) return null;
    final error = data['error'];
    String? message;
    String? field;
    if (error is Map) {
      message = error['message']?.toString();
      field = error['field']?.toString();
    } else if (error != null) {
      message = error.toString();
    }
    if (message == null) return null;
    if (message.startsWith('Invalid length for username')) {
      field = 'username';
    } else if (message.startsWith('Invalid length for password')) {
      field = 'password';
    }
    return {
      'error': _frenchErrors[message] ?? message,
      'success': false,
      'errorField': field ?? 'username',
    };
  }

  Future<Map<String, dynamic>> _authenticate(
      String path, Map<String, dynamic> body) async {
    try {
      final Response response = await _dio.post(path, data: body);
      final String accessToken = response.data['accessToken'];
      final String refreshToken = response.data['refreshToken'];
      await _secureStorage.storeTokens(accessToken, refreshToken);
      final User? user = await _userService.getUser();
      if (user != null) {
        return {'user': user, 'success': true};
      }
      throw Exception('Failed to get user');
    } on DioException catch (e) {
      final formError = formErrorFrom(e.response);
      if (formError != null) return formError;
      logger.e('Auth request $path failed: $e');
      throw Exception('Auth request failed: $e');
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) {
    return _authenticate('/auth/login', {
      'username': username,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> register(String username, String password,
      {String? restaurantId}) {
    return _authenticate('/auth/register', {
      'username': username,
      'password': password,
      if (restaurantId != null) 'restaurantId': restaurantId,
    });
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
