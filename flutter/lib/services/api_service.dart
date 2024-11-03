import 'package:logger/logger.dart';
import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';


class ApiService {

  late final Dio dio = Dio();

  static String? baseUrl = Config.apiUrl ;
  static final logger = Logger();

  // // Singleton pattern
  // static final ApiService _instance = ApiService._internal();
  
  // factory ApiService() {
  //   return _instance;
  // }

  ApiService() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e,ErrorInterceptorHandler handler) async {
          if (e.response?.statusCode == 401) {
            // If a 401 response is received, refresh the access token
            // String newAccessToken = await refreshToken();

            // // Update the request header with the new access token
            // e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

            // Repeat the request with the updated header
            return handler.resolve(await dio.fetch(e.requestOptions));
          }
          return handler.next(e);
        },
      ),
    );
  }

//   import 'package:dio/dio.dart';
// import 'package:flutter_secure_storage.dart';

// class ApiService {
//   late final Dio _dio;
//   final FlutterSecureStorage _storage;
  
//   // Singleton pattern
//   static final ApiService _instance = ApiService._internal();
  
//   factory ApiService() {
//     return _instance;
//   }
  
//   ApiService._internal() : _storage = FlutterSecureStorage() {
//     _dio = Dio(BaseOptions(
//       baseUrl: 'votre_url_base',
//       connectTimeout: const Duration(seconds: 5),
//       receiveTimeout: const Duration(seconds: 3),
//     ));
    
//     _dio.interceptors.add(TokenInterceptor(dio: _dio, storage: _storage));
//   }
  
//   // Exemples de méthodes d'API
//   Future<Map<String, dynamic>> getUserProfile() async {
//     try {
//       final response = await _dio.get('/user/profile');
//       return response.data;
//     } catch (e) {
//       // Gérer les erreurs de manière appropriée
//       rethrow;
//     }
//   }
  
//   Future<List<Map<String, dynamic>>> getPosts() async {
//     try {
//       final response = await _dio.get('/posts');
//       return List<Map<String, dynamic>>.from(response.data);
//     } catch (e) {
//       rethrow;
//     }
//   }
  
//   Future<Map<String, dynamic>> createPost(Map<String, dynamic> postData) async {
//     try {
//       final response = await _dio.post('/posts', data: postData);
//       return response.data;
//     } catch (e) {
//       rethrow;
//     }
//   }
  
//   // Méthodes de gestion du token
//   Future<void> setTokens({
//     required String accessToken,
//     required String refreshToken,
//   }) async {
//     await _storage.write(key: 'access_token', value: accessToken);
//     await _storage.write(key: 'refresh_token', value: refreshToken);
//   }
  
//   Future<void> clearTokens() async {
//     await _storage.delete(key: 'access_token');
//     await _storage.delete(key: 'refresh_token');
//   }
// }

// // L'intercepteur qu'on a créé précédemment
// class TokenInterceptor extends Interceptor {
//   // ... (même code que précédemment)
// }
  


  // Future<void> refreshToken() async {
  //   try {
  //     final response = await dio.post('$baseUrl/auth/token', options: Options(
  //       headers: {
  //         'Authorization ': 'Bearer $accessToken',
  //       },
  // }

   // Fonction pour login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await dio.post('$baseUrl/auth/login', data: {
        'username': username,
        'password': password,
      });

      

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }


  // Fonction pour s'inscrire
  Future<Map<String, dynamic>> register(String username, String password) async {
    try {
      final response = await dio.post('$baseUrl/auth/register', data: {
        'username': username,
        'password': password,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }


  // Fonction pour récupérer les données utilisateur
  Future<Map<String, dynamic>> getUser(String token) async {
    try {
      final response = await dio.get('$baseUrl/users/me', options: Options(
        headers: {
          'Authorization': 'Bearer $token',  // Ajout de l'Access Token
        },
      ));

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }


  // Fonction pour mettre à jour le statut de l'utilisateur
  Future<bool> updateStatus(String token, String status) async {
    try {
      final response = await dio.put('$baseUrl/users/status', data: {
        'status': status,
      }, options: Options(
        headers: {
          'Authorization': 'Bearer $token',  // Ajout de l'Access Token
        },
      ));

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        return true; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to update user status: $e');
    }
  }

  // Fonction pour ajouter un ami
  Future<bool> addFriend(String token, String friendUsername) async {
    try {
      final response = await dio.post('$baseUrl/users/add-friend', data: {
        'friendUsername': friendUsername,
      }, options: Options(
        headers: {
          'Authorization': 'Bearer $token',  // Ajout de l'Access Token
        },
      ));

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        return true; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to add friend: $e');
    }
  }


  // Fonction pour récupérer la liste des amis
  Future<Map<String, dynamic>> getFriends(String token) async {
    try {
      final response = await dio.get('$baseUrl/users/friends', options: Options(
        headers: {
          'Authorization': 'Bearer $token',  // Ajout de l'Access Token
        },
      ));

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to get friends: $e');
    }
  }


  //get menus from the API
  Future<List<dynamic>> getMenus(String token) async {
    try {
      final response = await dio.get('$baseUrl/ru/menus', options: Options(
        headers: { 'Authorization': 'Bearer $token'},
      ));

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return response.data; // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to get menus: $e');
    }
  }
}




