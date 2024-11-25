import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';


class ApiService {

  late final Dio _dio;
  final SecureStorage _secureStorage = SecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;


  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiUrl,
      connectTimeout: Duration(milliseconds: 5000),
      receiveTimeout: Duration(milliseconds: 3000),
    ));
    _dio.interceptors.add(
      InterceptorsWrapper(

        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();

          // Exclure les requêtes `login` et `register`
          if (token != null && !options.path.contains('/login') && !options.path.contains('/register')) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          return handler.next(options); // Passer au prochain intercepteur ou à la requête
        },

        onError: (DioException e,ErrorInterceptorHandler handler) async {
          if (e.response?.statusCode == 401) {
            // If a 401 response is received, refresh the access token
            await refreshToken();

          }

          return handler.next(e);
        },
      ),
    );
  }

  Future<String?> refreshToken() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      final Response response = await _dio.post('/auth/token', data: {'refreshToken': refreshToken});

      // if (response.statusCode == 403) {
      //   throw Exception('Invalid refresh token');
      // }

      if (response.statusCode == 200 && response.data != null) {
        final String newAccessToken = response.data['accessToken'];
        return newAccessToken;

      } else {
        // return response.data['msg'];
        return "problème de connexion";
      }
    } catch (e) {
      throw Exception('Failed to refresh token: $e');
    }

  }

   // Fonction pour login
  Future<User> login(String username, String password) async {
    try {
      final Response response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data['error'] == null) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];

        await _secureStorage.storeTokens(accessToken, refreshToken);
        final User? user = await getUser();
        if (user != null) {
          return user;
        }
        throw Exception('Failed to get user');
      }
      throw Exception('${response.statusCode} ${response.data['error']}');
    } catch (e) {
      logger.e('Failed to login: $e');
      throw Exception('$e');
    }
  }


  // Fonction pour s'inscrire
  Future<User> register(String username, String password) async {
    try {
      final Response response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 201 && response.data != null) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];

        await _secureStorage.storeTokens(accessToken, refreshToken);
        final User? user = await getUser();
        if (user != null) {
          return user;
        }
        throw Exception('Failed to get user');
      }
      throw Exception('${response.statusCode} ${response.data['error']}');
    } catch (e) {
      logger.e('Failed to register: $e');
      throw Exception('$e');
    }
  }


  // Fonction pour récupérer les données utilisateur
  Future<User?> getUser() async {
    try {
      final Response response = await _dio.get('/users/me');
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data);
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data?['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get user data: $e');
      return null;
    }
  }

  // Fonction pour ajouter un ami
  Future<bool> addFriend(String friendUsername) async {
    try {
      final Response response = await _dio.post('/users/add-friend', data: {
        'friendUsername': friendUsername,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        return true; // Renvoie les données si tout va bien
      } 
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to add friend: $e'); 
      return false; // Renvoie une exception si quelque chose ne va pas
    }
  }


  // Fonction pour récupérer la liste des amis
  Future<Map<String, dynamic>> getFriends() async {
    try {
      final Response response = await _dio.get('/users/friends');

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {};
    } catch (e) {
      logger.e('Failed to get friends: $e');
      return {};
    }
  }


  //get menus from the API
  Future<List<Menu>> getMenus() async {
    try {
      final Response response = await _dio.get('/ru/menus');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> rawMenuData = response.data;
        return rawMenuData.map((menu) => Menu.fromJson(menu)).toList();
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return [];

    } catch (e) {
      logger.e('Failed to get menus: $e');
      return [];
    }     

  }

  Future<bool> logout() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }
      final Response response = await _dio.post('/auth/logout',data: {refreshToken: refreshToken});
      await _secureStorage.clearTokens();
      if (response.statusCode != 200) {
        logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
        return false;
      }
      return true;
    } catch (e) {
      logger.e('Failed to logout: $e');
      return false;
    }
  }

  //update user profile (all fields)
  Future<bool> updateUser(Map<String, dynamic> user) async {
    try {
      final Response response = await _dio.put('/users/update', data: user);
      if (response.statusCode == 200) {
        logger.i('User updated: ${user['username']}');
        return true;
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false; 
    } catch (e) {
      logger.e('Failed to update user: $e');
      return false;
    }
  }

  //update user password (requires user id also requires the old password for verification)
  Future<bool> updatePassword(String oldPassword, String newPassword, String userId) async {
    try {
      final Response response = await _dio.put('/users/password', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'id': userId,
      });
      if (response.statusCode == 200) {
        logger.i('Password updated');
        return true;
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to update password: $e');
      return false;
    }
  }

  //update user status
  Future<bool> updateStatus(String status, String id) async {
    try {
      final Response response = await _dio.put('/users/status', data: {
        'status': status,
        'id': id,
      });
      if (response.statusCode == 200) {
        logger.i('Status updated: $status');
        return true;
      }
      logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to update status: $e');
      return false;
    }
  }

  //update username (requires user id)
  Future<bool> updateUsername(String username, String id) async {
    try {
      final Response response = await _dio.put('/users/username', data: {
        'username': username,
        'id': id,
      });
      if (response.statusCode == 200) {
        logger.i('Username updated: $username');
        return true;
      }
      logger.e('Invalid response from server in updateUsername(): ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to update username: $e');
      return false;
    }
  }

  //update user profile picture (requires user id) //TODO: implement



}

