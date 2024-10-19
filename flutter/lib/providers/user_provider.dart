import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../models/menu.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class TokenManager {
//   final _storage = const FlutterSecureStorage();

//   Future<void> storeToken(String token) async {
//     await _storage.write(key: 'jwt', value: token);
//   }

//   Future<String?> getToken() async {
//     return await _storage.read(key: 'jwt');
//   }

//   Future<void> deleteToken() async {
//     await _storage.delete(key: 'jwt');
//   }

//   // Future<bool> isTokenValid() async {
//   // final token = await _storage.read(key: 'jwt');
//   // if (token == null) return false;

//   // // Décoder la partie payload du JWT (2e partie du token séparée par des points)
//   // final parts = token.split('.');
//   // if (parts.length != 3) return false;

//   // // Le payload est en base64
//   // final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

//   // // Vérification de la date d'expiration
//   // final exp = payload['exp'];
//   // final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

//   // return DateTime.now().isBefore(expirationDate);  // Retourne true si le token n'est pas expiré
//   //}
// }

class UserProvider with ChangeNotifier {
  User? _user;
  List<User> _friends = [];
  final _secureStorage = const FlutterSecureStorage();

  String? _accessToken;
  String? _refreshToken;


  // Getters
  User? get user => _user;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
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
    _secureStorage.read(key: 'accessToken').then((accessToken) {
          
        });
    
    return false;
  }
  

  Future<void> storeTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    await _secureStorage.write(key: 'accessToken', value: accessToken);
    await _secureStorage.write(key: 'refreshToken', value: refreshToken);

    notifyListeners();
  }

  Future<void> loadTokens() async {
    
    _accessToken = await _secureStorage.read(key: 'accessToken');
    _refreshToken = await _secureStorage.read(key: 'refreshToken');
    
    
    notifyListeners();
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'accessToken');
    await _secureStorage.delete(key: 'refreshToken');

    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }

  // Méthode pour se connecter , ApiService.login could return null or a token or an exception
  Future<void> login(String username, String password) async {


    final response = await ApiService.login(username, password); //response is dynamic
    //test if exception
    
    //storeTokens(response['accessToken'], refreshToken)
    await storeTokens(response['accessToken'], response['refreshToken']);
    await loadTokens();
    await fetchUserData();
    notifyListeners();
    }

  // Méthode pour s'inscrire ApiService.register could return null or a token or an exception
  Future<String?> register(String username, String password) async {
    final token = await ApiService.register(username, password);
    // _token = token;
    await fetchUserData();
    notifyListeners();
    return "Inscription réussie";
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
      _accessToken = null;
      notifyListeners();
    }
    
  }

  // Méthode pour mettre à jour l'état de l'utilisateur
  Future<void> updateStatus(String newStatus) async {
    if (_accessToken == null || _user == null) return;

    final success = await ApiService.updateStatus(_accessToken!, newStatus);
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

  // Méthode pour récupérer les menus
  Future<Map<String,dynamic>> fetchMenus() async {
    if (_accessToken == null) return {}; //[]
    final menusData = await ApiService.getMenus(_accessToken!);
    /*
    List<Menu> menusRes = [];
    if (menusData != null) {
      for (var menu in menusData.values) {
        menusRes.add(Menu.fromJson(menu));
      }
    }
    return menusRes;
    */
    return menusData;
  }

  //the method returns a list of Menu objects, to be used in the MenuWidget (way better version)
  Future<List<Menu>> fetchMenusALT() async {
    if (_accessToken == null) return [];
    final menusData = await ApiService.getMenusALT(_accessToken!);
    if (menusData != null) {
      //set the menus in Menu class
      //_menus = menusData;
      return menusData;
    }
    return [];
  }

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    _accessToken = null;
    _friends = [];
    // TODO : add logout method to backend
    notifyListeners();
  }

  // TODO : Gérer les erreurs de connexion
  void handleLoginError() {}
}
