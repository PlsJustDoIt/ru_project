import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



class ApiService {
  static String? baseUrl = dotenv.env['APi_URL'] ?? 'http://127.0.0.1:5000/api';
  static final logger = Logger();

  static Future<String?> login(String username, String password) async {

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['token'];
      } else {
          // Gérer les erreurs HTTP non 200
          final errorResponse = jsonDecode(response.body);
          throw Exception(errorResponse['msg'] ?? 'Erreur de connexion');
        }
    } catch (e) {
      // Gérer les exceptions de la requête HTTP
      logger.e('Erreur de connexion: $e');
      return null;
    }
  }

  static Future<String?> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['token'];
    } else {
      return null;
    }
  }

 static Future<User?> getUser(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'x-auth-token': token},
    );
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      return null;
    }
  }

 static Future<bool> updateStatus(String token, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/status'),
      headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    return response.statusCode == 200;
  }

 static Future<bool> addFriend(String token, String friendUsername) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/add-friend'),
      headers: {'x-auth-token': token, 'Content-Type': 'application/json'},
      body: jsonEncode({'friendUsername': friendUsername}),
    );
    return response.statusCode == 200;
  }

  
static Future<Map<String, dynamic>?> getFriends(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/friends'),
      headers: {'x-auth-token': token},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }
}




