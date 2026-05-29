import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ru_project/models/search_result.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

class UserService {
  final Dio _dio;

  UserService({required Dio dio}) : _dio = dio;

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

  //update user profile picture
  Future<String?> updateProfilePicture(XFile pickedFile) async {
    try {
      MultipartFile file;

      if (kIsWeb) {
        // For web
        var byteData = await pickedFile.readAsBytes();
        file = MultipartFile.fromBytes(byteData,
            filename: pickedFile.name,
            contentType: DioMediaType('image', 'jpeg'));
      } else {
        file = await MultipartFile.fromFile(pickedFile.path,
            filename: pickedFile.name,
            contentType: DioMediaType('image', 'jpeg'));
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
}
