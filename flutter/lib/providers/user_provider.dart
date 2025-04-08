import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/secure_storage.dart';

class UserProvider with ChangeNotifier {
  final SecureStorage secureStorage;

  User? _user;
  List<User> _friends = [];
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  User? get user => _user;
  List<User> get friends => _friends;

  UserProvider({required this.secureStorage});

  Future<void> init(ApiService apiService) async {
    final accessToken = await secureStorage.getAccessToken();
    if (accessToken != null) {
      try {
        final user = await apiService.getUser();
        if (user == null) {
          clearUserData();
          return;
        }

        _user = user;
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

  void setFriends(List<User> friends) {
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
