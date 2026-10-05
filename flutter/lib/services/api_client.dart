import 'package:dio/dio.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';

/// Routes d'auth pour lesquelles un 401/403 ne doit PAS déclencher de refresh :
/// identifiants invalides (login/register) ou refresh lui-même en échec.
const _noRefreshPaths = ['/auth/login', '/auth/register', '/auth/token', '/auth/logout'];

class ApiClient {
  late final Dio _dio;
  final SecureStorage secureStorage;

  /// Appelé quand la session ne peut plus être rafraîchie (refresh token
  /// expiré/révoqué) : l'appli nettoie l'état et revient à l'accueil.
  void Function()? onSessionExpired;

  /// Refresh en cours, partagé : plusieurs requêtes qui expirent en même temps
  /// ne déclenchent qu'un seul appel à /auth/token.
  Future<String?>? _pendingRefresh;

  ApiClient({required this.secureStorage, this.onSessionExpired}) {
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

  /// Le backend renvoie 401 sans token et 403 « Invalid or expired token » si
  /// le token est expiré. Les autres 403 (droits insuffisants) ne justifient
  /// pas un refresh.
  static bool isExpiredSession(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return true;
    if (status != 403) return false;
    final data = e.response?.data;
    return data is Map && data['error'] == 'Invalid or expired token';
  }

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          final path = e.requestOptions.path;
          final alreadyRetried = e.requestOptions.extra['retried'] == true;
          if (!isExpiredSession(e) ||
              alreadyRetried ||
              _noRefreshPaths.any(path.contains)) {
            logger.i('API error ${e.response?.statusCode} on $path: ${e.message}');
            return handler.next(e);
          }

          final newToken = await refreshToken();
          if (newToken == null) {
            return handler.next(e);
          }
          try {
            // Réessayer une seule fois avec le nouveau token.
            final requestOptions = e.requestOptions
              ..headers['Authorization'] = 'Bearer $newToken'
              ..extra['retried'] = true;
            final response = await _dio.fetch(requestOptions);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
        onRequest: (options, handler) async {
          if (options.path.contains('/uploads')) {
            options.headers['Content-Type'] = 'multipart/form-data';
          }

          if (!options.path.contains('/login') &&
              !options.path.contains('/register') &&
              !options.headers.containsKey('Authorization')) {
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

  /// Rafraîchit l'access token. Renvoie null si impossible ; si le serveur a
  /// explicitement refusé le refresh token, la session est close via
  /// [onSessionExpired]. Une simple coupure réseau, elle, ne déconnecte pas.
  Future<String?> refreshToken() {
    return _pendingRefresh ??=
        _doRefresh().whenComplete(() => _pendingRefresh = null);
  }

  Future<String?> _doRefresh() async {
    final String? refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null) {
      // Invité ou session déjà fermée : rien à rafraîchir.
      return null;
    }
    try {
      final Response response =
          await _dio.post('/auth/token', data: {'refreshToken': refreshToken});
      final newAccessToken = response.data?['accessToken'];
      if (response.statusCode == 200 && newAccessToken is String) {
        await secureStorage.storeAccessToken(newAccessToken);
        return newAccessToken;
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        logger.w('Refresh token refusé : fin de session');
        onSessionExpired?.call();
      } else {
        logger.e('Failed to refresh token: $e');
      }
      return null;
    }
  }

  //TODO : a voir si ya mieux
  String getImageNetworkUrl(String avatarUrl) {
    return '${Config.apiUrl}/$avatarUrl';
  }
}
