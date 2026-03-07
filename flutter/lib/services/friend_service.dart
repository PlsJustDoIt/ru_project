import 'package:dio/dio.dart';
import 'package:ru_project/models/friend_request.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

class FriendService {
  final Dio _dio;

  FriendService({required Dio dio}) : _dio = dio;

  // Fonction pour ajouter un ami
  Future<Friend?> addFriend(String friendUsername) async {
    try {
      final Response response =
          await _dio.post('/users/send-friend-request', data: {
        'username': friendUsername,
      });

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200) {
        Friend friend = Friend.fromJson(response.data['friend']);
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
  Future<List<Friend>> getFriends() async {
    try {
      final Response response = await _dio.get('/users/friends');

      // Vérifie si la réponse contient des données valides
      if (response.statusCode == 200 && response.data != null) {
        return Friend.fromJsonList(response.data['friends']);
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

  // Fonction pour supprimer un ami
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
  Future<Map<String, dynamic>> getFriendRequests() async {
    try {
      final Response response = await _dio.get('/users/friend-requests');

      List<dynamic> rawFriendRequests = response.data['friendRequests'];

      if (response.statusCode == 200 && response.data != null) {
        List<FriendRequest> friendRequests = rawFriendRequests.map((request) {
          return FriendRequest.fromJson(request);
        }).toList();
        logger.i('Processed friends requests: $friendRequests');

        return {'friendRequests': friendRequests, 'success': true};
      }

      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data?['error']}');
      return {
        'error': response.data?['error'] ?? 'An error occurred',
        'success': false
      };
    } catch (e) {
      logger.e('Failed to get friend requests: $e');
      return {'error': 'Failed to get friend requests: $e', 'success': false};
    }
  }

  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final Response response = await _dio
          .post('/users/accept-friend-request', data: {'requestId': requestId});

      if (response.statusCode == 200) {
        logger.i('Friend request accepted');
        return true;
      }

      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to handle friend request: $e');
      return false;
    }
  }

  Future<bool> declineFriendRequest(String requestId) async {
    try {
      final Response response = await _dio.post('/users/decline-friend-request',
          data: {'requestId': requestId});

      if (response.statusCode == 200) {
        logger.i('Friend request declined');
        return true;
      }

      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to handle friend request: $e');
      return false;
    }
  }
}
