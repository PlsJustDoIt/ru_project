import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/menu.dart';
import '../models/user.dart';
import 'package:logger/logger.dart';
import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


class ApiService {

  static Dio dio = Dio();

  static String? baseUrl = config.apiUrl ;
  static final logger = Logger();


  // static Future<dynamic> login(String username, String password) async {
  //   try {

  //     final response = await http.post(
  //       Uri.parse('$baseUrl/auth/login'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'username': username, 'password': password}),
  //     );
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body)['token'];
  //     } else {
  //       final errorResponse = jsonDecode(response.body);
  //       throw Exception(errorResponse['msg'] ?? 'Erreur de connexion');
  //     }
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return e;
  //   }
  // }

   // Fonction pour login
  static Future<Map<String, dynamic>> login(String username, String password) async {
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

  // static Future<String?> register(String username, String password) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/auth/register'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({'username': username, 'password': password}),
  //     );

  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body)['token'];
  //     } else {
  //       final errorResponse = jsonDecode(response.body);
  //       throw Exception(errorResponse['msg'] ?? 'Erreur d\'inscription');
  //     }
  //   } catch (e) {
  //     logger.e('Erreur d\'inscription: $e');
  //     return null;
  //   }
  // }

  // Fonction pour s'inscrire
  static Future<Map<String, dynamic>> register(String username, String password) async {
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



  // static Future<Map<String, dynamic>?> getUser(String token) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/users/me'),
  //       headers: {'x-auth-token': token},
  //     );
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       return null;
  //     }
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return null;
  //   }

  // }

  // Fonction pour récupérer les données utilisateur
  static Future<Map<String, dynamic>> getUser(String token) async {
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

  // static Future<bool> updateStatus(String token, String status) async {
  //   try {
  //     final response = await http.put(
  //       Uri.parse('$baseUrl/users/status'),
  //       headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
  //       body: jsonEncode({'status': status}),
  //     );
  //     return response.statusCode == 200;
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return false;
  //   }
  // }

  // Fonction pour mettre à jour le statut de l'utilisateur
  static Future<bool> updateStatus(String token, String status) async {
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

  // static Future<bool> addFriend(String token, String friendUsername) async {
  //   try {
  //     final response = await http.post(
  //       Uri.parse('$baseUrl/users/add-friend'),
  //       headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
  //       body: jsonEncode({'friendUsername': friendUsername}),
  //     );
  //     return response.statusCode == 200;
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return false;
  //   }
  // }

  // Fonction pour ajouter un ami
  static Future<bool> addFriend(String token, String friendUsername) async {
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

  
  // static Future<Map<String, dynamic>?> getFriends(String token) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/users/friends'),
  //       headers: {'x-auth-token': token},
  //     );
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       return null;
  //     }
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return null;
  //   }
  // }

  // Fonction pour récupérer la liste des amis
  static Future<Map<String, dynamic>> getFriends(String token) async {
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

  // //get menus from the API
  // static Future<dynamic> getMenus(String token) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/ru/menus'),
  //       headers: {'x-auth-token': token},
  //     );
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     } else {
  //       return null;
  //     }
  //   } catch (e) {
  //     logger.e('Erreur de connexion: $e');
  //     return null;
  //   }
  // }

  //get menus from the API
  static Future<Map<String,dynamic>> getMenus(String token) async {
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


  //get menus from the API (way better version)
  static Future<List<Menu>?> getMenusALT(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ru/menus'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Menu>.from(data.map((x) => Menu.fromJson(x)));
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return null;
    }
  }
}




