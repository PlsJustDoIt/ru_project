import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

import 'package:image_picker/image_picker.dart';
import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/models/searchResult.dart';

class ApiService {
  late final Dio _dio;
  final SecureStorage _secureStorage = SecureStorage();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiUrl,
      connectTimeout: Duration(seconds: 10), // Plus généreux
      receiveTimeout: Duration(seconds: 7), // Plus long
      validateStatus: (status) {
        return status != null;
      },
    ));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          logger.e(e.requestOptions.validateStatus);
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            try {
              final newToken = await refreshToken();
              if (newToken != null) {
                // Mettre à jour le token
                await _secureStorage.storeAccessToken(newToken);

                // Cloner la requête originale
                final requestOptions = e.requestOptions;
                requestOptions.headers['Authorization'] = 'Bearer $newToken';

                // Réessayer une seule fois
                final response = await _dio.fetch(requestOptions);
                return handler.resolve(response);
              } else {
                logger.e('Failed to refresh token');
              }
            } catch (_) {
              // En cas d'erreur, déconnecter
              await logout();
            }
          }

          logger.i('Erreur détaillée : ${e.type}');
          logger.i('Message : ${e.message}');
          logger.i('Response : ${e.response?.data}');

          // Pour toutes autres erreurs
          return handler.next(e);
        },
        onRequest: (options, handler) async {
          if (options.path.contains('/uploads')) {
            options.headers['Content-Type'] = 'multipart/form-data';
            return handler.next(options);
          }
          final token = await _secureStorage.getAccessToken();
          if (token != null &&
              !options.path.contains('/login') &&
              !options.path.contains('/register')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<String?> refreshToken() async {
    try {
      final String? refreshToken = await _secureStorage.getRefreshToken();
      final Response response =
          await _dio.post('/auth/token', data: {'refreshToken': refreshToken});

      // if (response.statusCode == 403) {
      //   throw Exception('Invalid refresh token');
      // }

      if (response.statusCode == 200 && response.data != null) {
        final String newAccessToken = response.data['accessToken'];
        return newAccessToken;
      }
      logger.e(response.data['error']);

      throw Exception(response.data['error']);
    } catch (e) {
      logger.e('Failed to refresh token: $e');
      return null;
    }
  }

  // Fonction pour login
  Future<Map<String, dynamic>> login(String username, String password) async {
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
          return {'user': user, 'success': true};
        }
        return {
          'error': 'Failed to get user',
          'success': false,
          'errorField': 'username'
        };
      }
      //cas d'erreur field
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

  // Fonction pour s'inscrire
  Future<Map<String, dynamic>> register(
      String username, String password) async {
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
          return {'user': user, 'success': true};
        }
        throw Exception('Failed to get user');
      }
      if (response.data['error']['field'] == null) {
        throw Exception('Failed to register: ${response.data['error']['message']}');
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

  // Fonction pour récupérer les données utilisateur
  Future<User?> getUser() async {
    try {
      final Response response = await _dio.get('/users/me');
      if (response.statusCode == 200 && response.data != null) {
        return User.fromJson(response.data['user']);
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data?['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get user data: $e');
      return null;
    }
  }

  Future<List<SearchResult>> searchUsers(String query) async {
    try {
      final Response response =
          await _dio.get('/users/search', queryParameters: {
        'query': query,
      });

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> rawSearchResultData = response.data;
        logger.i('Users found: $rawSearchResultData');
        // TOUT changer ici
        return (rawSearchResultData['results'] as List)
            .map((result) => SearchResult.fromJson(result))
            .toList();
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      logger.e('Failed to search users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  // Fonction pour ajouter un ami
  Future<User?> addFriend(String friendUsername) async {
    try {
      final Response response = await _dio.post('/users/add-friend', data: {
        'username': friendUsername,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        User friend = User.fromJson(response.data['friend']);
        return friend;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to add friend: $e');
      return null; // Renvoie une exception si quelque chose ne va pas
    }
  }

  // Fonction pour récupérer la liste des amis
  Future<List<User>> getFriends() async {
    try {
      final Response response = await _dio.get('/users/friends');

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        List<User> friends = [
          for (Map<String, dynamic> friend in response.data['friends'])
            User.fromJson(friend)
        ];

        return friends;
      }

      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      throw Exception(
          'Invalid response from server : ${response.statusCode} ${response.data['error']}');
    } catch (e) {
      logger.e('Failed to get friends: $e');
      rethrow;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    try {
      final Response response =
          await _dio.delete('/users/remove-friend', data: {
        'friendId': friendId,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        return true; // Renvoie les données si tout va bien
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to remove friend: $e');
      return false; // Renvoie une exception si quelque chose ne va pas
    }
  }

  //get menus from the API
  Future<List<Menu>> getMenus() async {
    try {
      final Response response = await _dio.get('/ru/menus');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> rawMenuData = response.data;
        //logger.i('Menus récupérés : $rawMenuData');
        return rawMenuData.map((menu) => Menu.fromJson(menu)).toList();
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
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
      final Response response =
          await _dio.post('/auth/logout', data: {refreshToken: refreshToken});
      await _secureStorage.clearTokens();
      if (response.statusCode != 200) {
        logger.e(
            'Invalid response from server: ${response.statusCode} ${response.data['error']}');
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
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to update user: $e');
      return false;
    }
  }

  //update user password (requires user id also requires the old password for verification)
  Future<Map<String, dynamic>> updatePassword(
      String password, String oldPassword) async {
    try {
      final Response response = await _dio.put('/users/update-password', data: {
        'password': password,
        'oldPassword': oldPassword,
      });
      if (response.statusCode == 200) {
        logger.i('Password updated');
        return {'message': response.data['message'], 'success': true};
      }
      if (response.data['error']['field'] == null) {
        return {'error': response.data['error']['message'], 'success': false};
      }
      return {
        'error': response.data['error']['message'],
        'success': false,
        'errorField': response.data['error']['field']
      };
    } catch (e) {
      logger.e('Failed to update password: $e');
      return {'error': '$e', 'success': false};
    }
  }

  //update user status
  Future<Map<String, dynamic>> updateStatus(String status) async {
    try {
      final Response response = await _dio.put('/users/update-status', data: {
        'status': status,
      });
      if (response.statusCode == 200) {
        logger.i('Status updated: $status');
        return {'status': response.data['status'], 'success': true};
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {'error': response.data['error'], 'success': false};
    } catch (e) {
      logger.e('Failed to update status: $e');
      return {'error': e, 'success': false};
    }
  }

  //update user username TODO : se servir d'inspiration pour les autres
  Future<Map<String, dynamic>> updateUsername(String username) async {
    try {
      final Response response = await _dio.put('/users/update-username', data: {
        'username': username,
      });
      if (response.statusCode == 200) {
        logger.i('Username updated: $username');
        return {'username': response.data['username'], 'success': true};
      }
      logger.e(
          'Invalid response from server in updateUsername(): ${response.statusCode} ${response.data['error']}');
      return {'error': response.data['error'], 'success': false};
    } catch (e) {
      logger.e('Failed to update username: $e');
      return {'error': '$e', 'success': false};
    }
  }

  Future<Map<String, dynamic>> getHoraires({String lieu = "crous"}) async {
    try {
      final Response response = await _dio.get('/ginko/info', queryParameters: {
        'lieu': lieu,
      });
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {};
    } catch (e) {
      logger.e('Failed to get profile picture: $e');
      return {};
    }
  }

  //update user profile picture
  Future<String?> updateProfilePicture(XFile pickedFile) async {
    try {
      //update user profile picture (requires user id) //TODO: implement

      var file;

      if (kIsWeb) {
        // For web
        var byteData = await pickedFile.readAsBytes();
        file = MultipartFile.fromBytes(byteData,
            filename: pickedFile.name, contentType: MediaType('image', 'jpeg'));
      } else {
        file = await MultipartFile.fromFile(pickedFile.path,
            filename: pickedFile.name, contentType: MediaType('image', 'jpeg'));
      }

      final formData = FormData.fromMap({
        'avatar': file,
        'platform':
            kIsWeb ? 'web' : Platform.operatingSystem, // Indique la plateforme
      });
      //dio multipart request
      final Response response = await _dio.put('/users/update-profile-picture',
          data: formData); // avatarUrl : response.data['avatarUrl']

      if (response.statusCode == 200 && response.data['avatarUrl'] != null) {
        return response.data['avatarUrl'];
      } else {
        logger.e('Failed to update profile picture');
        return null;
      }
    } catch (e) {
      logger.e('Failed to update profile picture: $e');
      return null;
    }
  }

  Future<bool> deleteAccount() async {
    try {
      // requires refresh token for verification
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

  Future<Map<String, dynamic>> getMessagesChatRoom() async {
    try {
      final Response response = await _dio.get('/socket/chat-room');
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {};
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getMessagesFromRoom(String roomId) async {
    try {
      final Response response =
          await _dio.get('/socket/messages', queryParameters: {
        'roomId': roomId,
      });
      if (response.statusCode == 200 && response.data != null) {
        return response.data;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {};
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return {};
    }
  }

  //TODO : a voir si ya mieux
  String getImageNetworkUrl(String avatarUrl) {
    return '${Config.apiUrl}/$avatarUrl';
  }
}
