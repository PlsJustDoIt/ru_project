
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/secure_storage.dart';


class UserProvider with ChangeNotifier {
  User? _user;
  List<User> _friends = [];
  final SecureStorage _secureStorage = SecureStorage();
  final _api = ApiService();

  // Getters
  User? get user => _user;
  List<User> get friends => _friends;

 
//   Future<bool> isConnected() async {
//   final prefs = await SharedPreferences.getInstance();
//   final token = prefs.getString('token');
//   final expirationTime = prefs.getString('tokenExpiration');

//   if (token == null || expirationTime == null) {
//     return false; // Pas de token ou pas d'heure d'expiration
//   }

//   final expirationDate = DateTime.parse(expirationTime);

//   // Comparer l'heure actuelle avec l'heure d'expiration
//   if (DateTime.now().isAfter(expirationDate)) {
//     // Token expiré, supprimer le token
//     await prefs.remove('token');
//     await prefs.remove('tokenExpiration');
//     return false;
//   }

//   return true; // Token toujours valide
// }

  // Future<void> storeToken(String token) async {
  //   final prefs = await SharedPreferences.getInstance();

  //   // Stocker le token
  //   await prefs.setString('token', token);

  //   // Stocker l'heure d'expiration (1 heure après l'heure actuelle)
  //   final expirationTime =
  //       DateTime.now().add(const Duration(hours: 1)).toIso8601String();
  //   await prefs.setString('tokenExpiration', expirationTime);
  // }

   // Constructor
  UserProvider() {
    _initialize();
  }

  // Initialization method
  Future<void> _initialize() async {

    Logger().i('initializing user provider');

    await loadTokens();

    if (_accessToken != null) {
      
      await fetchUserData();
      // await fetchFriends(); cette fonction marche pas
    }
  }

  Future<bool> isConnected() async {
    if (_accessToken != null) {
      return true;
    }
    
    return false;
  }
  

  Future<void> storeTokens(String accessToken, String refreshToken) async {

    await _secureStorage.storeTokens(accessToken, refreshToken);

    notifyListeners();
  }


  Future<void> clearTokens() async {
    await _secureStorage.clearTokens();
    notifyListeners();
  }

  // Méthode pour se connecter , ApiService.login could return null or a token or an exception
  Future<Map<String,dynamic>> login(String username, String password) async {

    try {
      final response = await _api.login(username, password); //response is dynamic

      await storeTokens(response['accessToken'], response['refreshToken']);
      await fetchUserData();
      notifyListeners();
      return {
        'success': true,
        'message': 'Connexion réussie'
      };
      } catch (e) {
        Logger().e('Erreur de connexion: $e');
        return {
          'success': false,
          'message': 'Erreur de connexion'
        };
      }
    
  }

  // Méthode pour s'inscrire ApiService.register could return null or a token or an exception
  Future<Map<String,dynamic>> register(String username, String password) async {

    try {
      final response = await _api.register(username, password);
      await storeTokens(response['accessToken'], response['refreshToken']);

      await fetchUserData();
      notifyListeners();
      return {
        'success': true,
        'message': 'Inscription réussie'
      };
    } catch (e) {
      Logger().e('Erreur d\'inscription: $e');
      return {
        'success': false,
        'message': 'Erreur d\'inscription'
      };
  
    }
  }

  // Méthode pour récupérer les données utilisateur après la connexion
  Future<void> fetchUserData() async {
    try {
      if (_accessToken != null) {
      final userData = await ApiService.getUser(_accessToken!);
      _user = User.fromJson(userData);
          notifyListeners();
      }
    } catch (e) {
      Logger().e('Erreur de connexion: $e');
      _user = null;
      notifyListeners();
    }
    
  }

  // Méthode pour mettre à jour l'état de l'utilisateur
  Future<void> updateStatus(String newStatus) async {
    if (_user == null) return;

    final success = await _api.updateStatus(_accessToken!, newStatus);
    if (success) {
      _user!.status = newStatus;
      notifyListeners();
    }
  }

  // Méthode pour ajouter un ami
  Future<void> addFriend(String friendUsername) async {
    if (_accessToken == null) return;

    final success = await ApiService.addFriend(_accessToken!, friendUsername);
    if (success) {
      // Mettez à jour la liste des amis après l'ajout
      await fetchFriends();
    }
  }

  // Méthode pour récupérer la liste des amis et leurs états
  Future<void> fetchFriends() async {
    if (_accessToken == null) return;

    final friendsData = await ApiService.getFriends(_accessToken!);
    Logger().i(friendsData);
    _friends = friendsData['friends']
        .map<User>((json) => User.fromJson(json))
        .toList();
    notifyListeners();
    }

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    
    _friends = [];
    // TODO : add logout method to backend
    notifyListeners();
  }

  // TODO : Gérer les erreurs de connexion
  void handleLoginError() {}
}
