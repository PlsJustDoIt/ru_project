import 'package:dio/dio.dart';
import 'package:ru_project/models/friendsInSector.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/models/sector.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

class RestaurantService {
  final Dio _dio;

  RestaurantService({required Dio dio}) : _dio = dio;

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

  Future<List<Sector>> getRestaurantsSectors({String idResto = "r135"}) async {
    try {
      logger.i('Getting sectors for restaurant: $idResto');
      final Response response = await _dio.get('/ru/$idResto/sectors');
      if (response.statusCode == 200 && response.data != null) {
        List<Sector> sectors = [
          for (Map<String, dynamic> sector in response.data['sectors'])
            Sector.fromJson(sector)
        ];
        return sectors;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return [];
    } catch (e) {
      logger.e('Failed to get sectors: $e');
      return [];
    }
  }

  Future<bool> sitInSector(int duration, String sectorId) async {
    try {
      final Response response =
          await _dio.post('/sectors/join/$sectorId', data: {
        'duration': duration,
      });
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to sit in sector: $e');
      return false;
    }
  }

  Future<bool> leaveSector(String sectorId) async {
    try {
      final Response response = await _dio.post('/sectors/leave/$sectorId');
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to leave sector: $e');
      return false;
    }
  }

  Future<List<User>> getFriendsInSector(String sectorId) async {
    try {
      final Response response = await _dio.get('/sectors/$sectorId/friends');
      if (response.statusCode == 200 && response.data != null) {
        logger.i('Response from server: ${response.data}');
        if (response.data['friendsInSector'] == null) {
          return [];
        }

        List<User> users = [
          for (Map<String, dynamic> user in response.data['friendsInSector'])
            User.fromJson(user)
        ];
        return users;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return [];
    } catch (e) {
      logger.e('Failed to get users in sector: $e');
      return [];
    }
  }

  Future<List<User>> getUsersInSector(String restaurantId) async {
    try {
      final Response response =
          await _dio.get('/ru/$restaurantId/sectors-sessions');
      if (response.statusCode == 200 && response.data != null) {
        logger.i('Response from server: ${response.data}');
        if (response.data['usersInSector'] == null) {
          return [];
        }

        List<User> users = [
          for (Map<String, dynamic> user in response.data['friendsInSectors'])
            User.fromJson(user)
        ];
        return users;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return [];
    } catch (e) {
      logger.e('Failed to get users in sector: $e');
      return [];
    }
  }

  Future<List<RestaurantPartial>> getRestaurants() async {
    try {
      final Response response = await _dio.get('/ru/restaurants');
      if (response.statusCode == 200 && response.data != null) {
        List<RestaurantPartial> restaurants = [
          for (Map<String, dynamic> restaurant in response.data['restaurants'])
            RestaurantPartial.fromJson(restaurant)
        ];
        return restaurants;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return [];
    } catch (e) {
      logger.e('Failed to get restaurants: $e');
      return [];
    }
  }

  // utilise l'id de l'api officiel
  Future<RestaurantTmp?> getRestaurantInfo(String restaurantId) async {
    try {
      final Response response = await _dio.get('/ru/$restaurantId/info');
      if (response.statusCode == 200 && response.data != null) {
        logger.i('Response from server: ${response.data}');
        return RestaurantTmp.fromJson(response.data['restaurant']);
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get restaurant info: $e');
      return null;
    }
  }

  // utilise l'id interne
  Future<RestaurantTmp?> getRestaurantById(String restaurantId) async {
    try {
      final Response response = await _dio.get('/ru/$restaurantId');
      if (response.statusCode == 200 && response.data != null) {
        logger.i('Response from server: ${response.data}');
        return RestaurantTmp.fromJson(response.data['restaurant']);
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data}');
      return null;
    } catch (e) {
      logger.e('Failed to get restaurant: $e');
      return null;
    }
  }

  Future<FriendsInSectors?> getFriendsSessions(String restaurantId) async {
    try {
      final Response response =
          await _dio.get('/ru/$restaurantId/sectors-sessions');
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['message'] != null) {
          return null;
        }
        logger.i('Response from server: ${response.data}');
        return FriendsInSectors.fromJson(response.data);
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get friends in sectors: $e');
      return null;
    }
  }

  Future<FriendsInSectors?> getAllSectorsSessions(String restaurantId) async {
    try {
      final Response response =
          await _dio.get('/ru/$restaurantId/sectors-sessions/all');
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['message'] != null) {
          return null;
        }
        logger.i('Response (all sessions) from server: ${response.data}');
        return FriendsInSectors.fromJson(response.data);
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get all sectors sessions: $e');
      return null;
    }
  }
}
