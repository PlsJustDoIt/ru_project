import 'package:logger/logger.dart';
import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/secure_storage.dart';


class ApiService {

  late final Dio _dio;
  static final _logger = Logger();
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

  Future<void> refreshToken() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      final Response response = await _dio.post('/auth/token', data: {'refreshToken': refreshToken,});

      if (response.statusCode == 200 && response.data != null) {
        final String newAccessToken = response.data['accessToken'];
        final String newRefreshToken = response.data['refreshToken'];

        await SecureStorage().storeTokens(newAccessToken, newRefreshToken);
      } else {
        throw Exception('Invalid response from server');
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
      if (response.statusCode == 200 && response.data != null) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];

        await _secureStorage.storeTokens(accessToken, refreshToken);
        final User? user = await getUser();
        if (user != null) {
          return user;
        } else {
          throw Exception('Failed to get user data');
        }
        
      }

      throw Exception('Invalid response from server');
    

    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }


  // Fonction pour s'inscrire
  Future<User> register(String username, String password) async {
    try {
      final response = await _dio.post('/auth/register', data: {
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
        } else {
          throw Exception('Failed to get user data');
        }
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }


  // Fonction pour récupérer les données utilisateur
  Future<User?> getUser() async {
    try {
      final response = await _dio.get('/users/me');

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data); // Renvoie les données si tout va bien
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }


  // Fonction pour mettre à jour le statut de l'utilisateur
  Future<bool> updateStatus(String status) async {
    try {
      final response = await _dio.put('/users/status', data: {
        'status': status,
      });

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
  Future<bool> addFriend(String friendUsername) async {
    try {
      final response = await _dio.post('/users/add-friend', data: {
        'friendUsername': friendUsername,
      });

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
  Future<Map<String, dynamic>> getFriends() async {
    try {
      final response = await _dio.get('/users/friends');

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
  Future<List<Menu>> getMenus() async {
    try {
      final response = await _dio.get('/ru/menus');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> rawMenuData = response.data;
        return rawMenuData.map((menu) => Menu.fromJson(menu)).toList();
      } else {
        throw Exception('Invalid response from server');
      }

    } catch (e) {
      throw Exception('Failed to get menus: $e');
    }

      // Vérifie si la réponse contient des données valides
    //   if (response.statusCode == 200 && response.data != null) {
    //     List<Menu> menus;
    //     final List<Map<String, dynamic>> rawMenuData = List<Map<String, dynamic>>.from(response.data);

    //     if (rawMenuData.isEmpty) { //ok
    //       menus = []; 
    //     } else {
    //       menus = rawMenuData.map((menu) => Menu.fromJson(menu)).toList();
    //     }

    //     return menus;
        
    //   } else {
    //     throw Exception('Invalid response from server');
    //   }
    // } catch (e) {
    //   throw Exception('Failed to get menus: $e');
    // }

     

  }

  Future<bool> logout() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token found');
      }
      final response = await _dio.get('/auth/logout',data: {refreshToken: refreshToken});
      await _secureStorage.clearTokens();
      if (response.statusCode != 200) {
        throw Exception('Invalid response from server');
      }
      return true;
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }



}




