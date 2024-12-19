import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/user_storage.dart';

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

      if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
        final User? user = await _api.getUser();
        if (user != null) {
          _user = user;
          UserStorageService.saveUser(user);
          notifyListeners();
        } else {
          handleLoginError();
        }
        // await fetchFriends(); cette fonction marche pas
      } else {
        // si accessToken est null ou expiré
        logger.i(accessToken != null ? 'Token expired' : 'No token');

        if (user != null) {
          await _handleTokenExpiration();
        } else {
          //M jsp
        }
      }
    } catch (e) {
      throw Exception('Failed to initialize user provider: $e');
    }
  }

  Future<void> _handleTokenExpiration() async {
    logger.i('handling token expiration');

    final String? newAccessToken = await _api.refreshToken();
    logger.i('New access token: $newAccessToken');
    if (newAccessToken != null) {
      await _secureStorage.storeAccessToken(newAccessToken);
      _initialize(); // Relancer l'initialisation avec le nouveau token
    } else {
      handleLoginError();
    }
  }

  Future<bool> isConnected() async {
    final String? accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null && !JwtDecoder.isExpired(accessToken)) {
      return true;
    }
    return false;
  }

  void setUser(User user) {
    _user = user;
    UserStorageService.saveUser(user);
    notifyListeners();
  }

  // Méthode poour recharger un utilisateur depuis l'API
  Future<void> reloadUser() async {
    final User? user = await _api.getUser();
    if (user != null) {
      _user = user;
      UserStorageService.saveUser(user);
      notifyListeners();
    } else {
      handleLoginError();
    }
  }

  // Méthode poour recharger un utilisateur depuis l'UserStorage
  Future<void> reloadUserFromStorage() async {
    final User? user = await UserStorageService.getUser();
    if (user != null) {
      _user = user;
      notifyListeners();
    } else {
      handleLoginError();
    }
  }

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    UserStorageService.deleteUser();
    _friends = [];
    notifyListeners();
  }

  // TODO : Gérer les erreurs de connexion
  void handleLoginError() {}
}
