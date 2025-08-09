import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/user_service.dart';

class UserProvider with ChangeNotifier {
  final SecureStorage secureStorage;

  User? _user;
  List<Friend> _friends = [];
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  User? get user => _user;
  List<Friend> get friends => _friends;

  UserProvider({required this.secureStorage});

  Future<void> init(UserService userService, FriendService friendService,
      RestaurantProvider restaurantProvider) async {
    final accessToken = await secureStorage.getAccessToken();
    if (accessToken != null) {
      try {
        final user = await userService.getUser();
        if (user == null) {
          clearUserData();
          return;
        }

        final friends = await friendService.getFriends();

        await restaurantProvider.loadRestaurant(user.restaurantId);

        _user = user;
        _friends = friends;
        _isConnected = true;
      } catch (_) {
        clearUserData();
      }
    }
    notifyListeners();
  }

  void setUser(User? user) {
    if (user == null) {
      clearUserData();
    } else {
      _user = user;
      _isConnected = true;
      notifyListeners();
    }
  }

  void setFriends(List<Friend> friends) {
    _friends = friends;
    notifyListeners();
  }

  void clearUserData() {
    _user = null;
    _friends = [];
    _isConnected = false;
    notifyListeners();
  }
}
