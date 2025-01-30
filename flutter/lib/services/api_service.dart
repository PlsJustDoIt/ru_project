import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';

import 'package:image_picker/image_picker.dart';
import 'package:ru_project/config.dart';
import 'package:dio/dio.dart';
import 'package:ru_project/main.dart';
import 'package:ru_project/models/friends_request.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/models/searchResult.dart';
import 'package:ru_project/widgets/welcome.dart';

class ApiService {
  late final Dio _dio;
  final UserProvider userProvider;
  final SecureStorage secureStorage;

  ApiService({required this.userProvider, required this.secureStorage}) {
    initializeDio();
    _initializeInterceptors();
  }

  void initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiUrl,
      connectTimeout: Duration(seconds: 10), // Plus généreux
      receiveTimeout: Duration(seconds: 7), // Plus long
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
              return;
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
            options.headers['Authorization'] = 'Bearer $token';
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

  // Fonction pour login
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final Response response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        final String accessToken = response.data['accessToken'];
        final String refreshToken = response.data['refreshToken'];

        await secureStorage.storeAccessToken(accessToken);
        await secureStorage.storeRefreshToken(refreshToken);
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
        await secureStorage.storeAccessToken(accessToken);
        await secureStorage.storeRefreshToken(refreshToken);
        final User? user = await getUser();
        if (user != null) {
          return {'user': user, 'success': true};
        }
        throw Exception('Failed to get user');
      }
      if (response.data['error']['field'] == null) {
        throw Exception(
            'Failed to register: ${response.data['error']['message']}');
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
      final Response response = await _dio.post('/users/send-friend-request', data: { //temp  /users/add-friend
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

  // Fonction pour supprimer un ami TODO : à revoir pour suprimer dans les 2 sens dans le backend 
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

  // Fonction pour récupérer les demandes d'amis
  Future<Map<String, dynamic>> getFriendsRequests() async {
  try {
    final Response response = await _dio.get('/users/friends-requests');
    
    logger.i('Friends requests: ${response.data}');

    List<dynamic> rawFriendsRequests = response.data['friendsRequests'];

    if (response.statusCode == 200 && response.data != null) {
      logger.i('Raw friends requests: $rawFriendsRequests');
      List<FriendsRequest> friendsRequests = rawFriendsRequests.map((request) {
        logger.i('Processing friend request: $request, type: ${request.runtimeType}');
        return FriendsRequest.fromJson(request);
      }).toList();
      logger.i('Processed friends requests: $friendsRequests');
      
      return {
        'friendsRequests': friendsRequests,
        'success': true
      };
    }
    
    logger.e('Invalid response from server: ${response.statusCode} ${response.data?['error']}');
    return {
      'error': response.data?['error'] ?? 'An error occurred',
      'success': false
    };
  } catch (e) {
    logger.e('Failed to get friend requests: $e');
    return {
      'error': 'Failed to get friend requests: $e',
      'success': false
    };
  }
}

// Fonction pour accepter une demande d'ami
Future<bool> acceptFriendRequest(String requestId) async {
  try {
    final Response response = await _dio.post('/users/handle-friend-request', 
      data: {
        'requestId': requestId,
        'isAccepted': true
      }
    );

    if (response.statusCode == 200) {
      logger.i('Friend request accepted');
      return true;
    }
    
    logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
    return false;
  } catch (e) {
    logger.e('Failed to accept friend request: $e');
    return false;
  }
}

// Fonction pour refuser une demande d'ami
Future<bool> rejectFriendRequest(String requestId) async {
  try {
    final Response response = await _dio.post('/users/handle-friend-request', 
      data: {
        'requestId': requestId,
        'isAccepted': false
      }
    );

    if (response.statusCode == 200) {
      logger.i('Friend request rejected');
      return true;
    }
    
    logger.e('Invalid response from server: ${response.statusCode} ${response.data['error']}');
    return false;
  } catch (e) {
    logger.e('Failed to reject friend request: $e');
    return false;
  }
}

  //get menus from the API
  Future<List<Menu>> getMenus() async {
    try {
      final Response response = await _dio.get('/ru/menus');

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> menus = response.data['menus'] as List;
        return menus.map((menu) => Menu.fromJson(menu)).toList();
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
      final refreshToken = await secureStorage.getRefreshToken();
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

  //update user username
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
      if (response.statusCode == 200) {
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
      final String? refreshToken = await secureStorage.getRefreshToken();
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

  Future<List<Message>?> getMessagesChatRoom() async {
    try {
      final Response response = await _dio.get('/socket/chat-room');
      if (response.statusCode == 200 && response.data != null) {
        List<Message> messages = [
          for (Map<String, dynamic> message in response.data['messages'])
            Message.fromJson(message)
        ];
        return messages;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return null;
    }
  }

  Future<Message?> sendMessageChatRoom(String content) async {
    try {
      final Response response =
          await _dio.post('/socket/send-chat-room', data: {
        'content': content,
      });
      if (response.statusCode == 201) {
        Message message = Message.fromJson(response.data['message']);
        return message;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to send message: $e');
      return null;
    }
  }

  Future<List<Message>?> getMessagesFromRoom(String roomName) async {
    try {
      final Response response =
          await _dio.get('/socket/messages', queryParameters: {
        'roomName': roomName,
      });
      if (response.statusCode == 200 && response.data != null) {
        List<Message> messages = [
          for (Map<String, dynamic> message in response.data['messages'])
            Message.fromJson(message)
        ];
        return messages;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return null;
    }
  }

  Future<Message?> sendMessageToRoom(String roomName, String content) async {
    try {
      final Response response = await _dio.post('/socket/send-message', data: {
        'roomName': roomName,
        'content': content,
      });
      if (response.statusCode == 201) {
        Message message = Message.fromJson(response.data['message']);
        return message;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to send message: $e');
      return null;
    }
  }

  // router.delete('/delete-messages
  Future<bool> deleteMessages(String roomName) async {
    try {
      final Response response = await _dio.delete('/socket/delete-all-messages',
          queryParameters: {'roomName': roomName});
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to delete messages: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId,String roomName) async {
    try {
      final Response response = await _dio.delete('/socket/delete-message',
          queryParameters: {'messageId': messageId,'roomName': roomName});
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to delete message: $e');
      return false;
    }
  }

  //TODO : a voir si ya mieux
  String getImageNetworkUrl(String avatarUrl) {
    return '${Config.apiUrl}/$avatarUrl';
  }

  // //get user profile picture
  // Future<String?> getProfilePicture(String ) async {
  //   try {
  //     final Response response = await _dio.get('/users/profile-picture');
  //     if (response.statusCode == 200 && response.data != null) {
  //       return response.data['avatarUrl'];
  //     }
  //     logger.e(
  //         'Invalid response from server: ${response.statusCode} ${response.data['error']}');
  //     return null;
  //   } catch (e) {
  //     logger.e('Failed to get profile picture: $e');
  //     return null;
  //   }
  // }
}
