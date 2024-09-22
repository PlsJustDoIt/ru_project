import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/menu.dart';
import '../models/user.dart';
import 'package:logger/logger.dart';
import 'package:ru_project/config.dart';


class ApiService {
  static String? baseUrl = config.apiUrl ;
  static final logger = Logger();

  static Future<dynamic> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['token'];
      } else {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['msg'] ?? 'Erreur de connexion');
      }
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return e;
    }
  }

  static Future<String?> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['token'];
      } else {
        final errorResponse = jsonDecode(response.body);
        throw Exception(errorResponse['msg'] ?? 'Erreur d\'inscription');
      }
    } catch (e) {
      logger.e('Erreur d\'inscription: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUser(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return null;
    }

  }

  static Future<bool> updateStatus(String token, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/status'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return false;
    }
  }

  static Future<bool> addFriend(String token, String friendUsername) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/add-friend'),
        headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'friendUsername': friendUsername}),
      );
      return response.statusCode == 200;
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return false;
    }
  }

  
  static Future<Map<String, dynamic>?> getFriends(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/friends'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return null;
    }
  }

  //TODO : essayez de fait la parti getmenusD dans user provider 
  static Future<Map<String, dynamic>?> getMenus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ru/menus'),
        headers: {'x-auth-token': token},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      logger.e('Erreur de connexion: $e');
      return null;
    }
  }

  //TODO : essayez de fait la parti getmenusD dans user provider 
  static Future<List<Menu>?> getMenusD(String token) async {

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




