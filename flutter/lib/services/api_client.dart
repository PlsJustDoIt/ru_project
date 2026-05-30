import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/main.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';

class ApiClient {
  late final Dio _dio;
  final UserProvider userProvider;
  final SecureStorage secureStorage;

  ApiClient({required this.userProvider, required this.secureStorage}) {
    initializeDio();
    _initializeInterceptors();
  }

  Dio get dio => _dio;

  void initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiUrl,
      connectTimeout: const Duration(seconds: 10), // Plus généreux
      receiveTimeout: const Duration(seconds: 7), // Plus long
    ));
  }

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            logger.i(e.requestOptions.path);
            if (e.requestOptions.path == '/auth/token') {
              // Si la route /refreshToken échoue, déconnecter l'utilisateur
              userProvider.clearUserData();
              navigatorKey.currentState?.pushReplacement(
                MaterialPageRoute(builder: (context) => const WelcomeWidget()),
              );
              return handler.reject(e);
            }
            try {
              logger.e('error : ${e.response?.data}');
              final newToken = await refreshToken();
              if (newToken != null) {
                // Cloner la requête originale
                final requestOptions = e.requestOptions;
                requestOptions.headers['Authorization'] = 'Bearer $newToken';

                // Réessayer une seule fois
                final response = await _dio.fetch(requestOptions);
                return handler.resolve(response);
              }

              return handler.next(e);
            } catch (_) {
              //TODO: quand le token ne peut pas être rafraîchi erreur
              // En cas d'erreur, déconnecter
              return handler.next(e);
            }
          }

          // Pour les autres erreurs

          logger.i('Message : ${e.message}');
          logger.i('Response : ${e.response?.data}');
          return handler.next(e);
        },
        onRequest: (options, handler) async {
          if (options.path.contains('/uploads')) {
            options.headers['Content-Type'] = 'multipart/form-data';
          }

          if (!options.path.contains('/login') &&
              !options.path.contains('/register')) {
            final token = await secureStorage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<String?> refreshToken() async {
    try {
      final String? refreshToken = await secureStorage.getRefreshToken();
      if (refreshToken == null) {
        logger.e('No refresh token found locally');
        return null;
      }
      final Response response =
          await _dio.post('/auth/token', data: {'refreshToken': refreshToken});

      if (response.statusCode == 200) {
        final String newAccessToken = response.data['accessToken'];
        await secureStorage.storeAccessToken(newAccessToken);
        return newAccessToken;
      }
      logger.e(response.data['error']);

      return null;
    } catch (e) {
      logger.e('Failed to refresh token: $e');
      return null;
    }
  }

  //TODO : a voir si ya mieux
  String getImageNetworkUrl(String avatarUrl) {
    return '${Config.apiUrl}/$avatarUrl';
  }
}
