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
  bool _isGuest = false;

  bool get isConnected => _isConnected;
  bool get isGuest => _isGuest;
  User? get user => _user;
  List<Friend> get friends => _friends;

  UserProvider({required this.secureStorage});

  Future<void> init(UserService userService, FriendService friendService,
      RestaurantProvider restaurantProvider) async {
    final accessToken = await secureStorage.getAccessToken();
    if (accessToken == null) {
      final guestRestaurantId = await secureStorage.getGuestRestaurantId();
      if (guestRestaurantId != null && guestRestaurantId.isNotEmpty) {
        _isGuest = true;
        await restaurantProvider.tryLoadRestaurant(guestRestaurantId);
      }
      notifyListeners();
      return;
    }

    final user = await userService.getUser();
    if (user == null) {
      // Token présent mais session invalide : vraie déconnexion.
      clearUserData();
      return;
    }

    // Session valide : on est connecté, quoi qu'il advienne des données annexes.
    _user = user;
    _isConnected = true;

    // Chargements best-effort : un échec ne doit JAMAIS déconnecter.
    try {
      _friends = await friendService.getFriends();
    } catch (e) {
      logger.e('init: chargement des amis échoué (non bloquant): $e');
    }
    await restaurantProvider.tryLoadRestaurant(user.restaurantId);

    notifyListeners();
  }

  void setUser(User? user) {
    if (user == null) {
      clearUserData();
    } else {
      _user = user;
      _isConnected = true;
      _isGuest = false;
      notifyListeners();
    }
  }

  /// Active le mode invité (pas de compte). Le restaurant est déjà chargé
  /// par l'appelant via RestaurantProvider.
  void enterGuestMode() {
    _isGuest = true;
    _isConnected = false;
    notifyListeners();
  }

  void setFriends(List<Friend> friends) {
    _friends = friends;
    notifyListeners();
  }

  void clearUserData() {
    _user = null;
    _friends = [];
    _isConnected = false;
    _isGuest = false;
    notifyListeners();
  }
}
