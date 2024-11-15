
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';


class UserProvider with ChangeNotifier {
  User? _user;
  List<User> _friends = [];
  final SecureStorage _secureStorage = SecureStorage();
  final _api = ApiService();


  // Getters
  User? get user => _user;
  List<User> get friends => _friends;

   // Constructor
  UserProvider() {
    _initialize();
  }

  // Initialization method
  Future<void> _initialize() async {

    logger.i('initializing user provider');
    try {
    
      final String? accessToken = await _secureStorage.getAccessToken();

      if (accessToken != null) {
        
        final User? user = await _api.getUser();
        if (user != null) {
          _user = user;
          notifyListeners();
        } else {
          handleLoginError();
        }
        // await fetchFriends(); cette fonction marche pas
      }

    } catch (e) {
      throw Exception('Failed to initialize user provider: $e');
    }
  }

  Future<bool> isConnected() async {
    if (user != null) {
      return true;
    }
    
    return false;
  }

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }
  
  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    _friends = [];
    notifyListeners();
  }

  // TODO : Gérer les erreurs de connexion
  void handleLoginError() {}
}
