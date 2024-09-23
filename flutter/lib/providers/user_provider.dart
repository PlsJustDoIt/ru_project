import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../models/menu.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  final _storage = const FlutterSecureStorage();

  Future<void> storeToken(String token) async {
    await _storage.write(key: 'jwt', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt');
  }

    // Future<bool> isTokenValid() async {
    // final token = await _storage.read(key: 'jwt');
    // if (token == null) return false;

    // // Décoder la partie payload du JWT (2e partie du token séparée par des points)
    // final parts = token.split('.');
    // if (parts.length != 3) return false;

    // // Le payload est en base64
    // final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    
    // // Vérification de la date d'expiration
    // final exp = payload['exp'];
    // final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    
    // return DateTime.now().isBefore(expirationDate);  // Retourne true si le token n'est pas expiré
    //}

}

class UserProvider with ChangeNotifier {
  User? _user;
  String? _token;
  List<User> _friends = [];

  // Getters
  User? get user => _user;
  String? get token => _token;
  List<User> get friends => _friends;


  Future<bool> isConnected() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final expirationTime = prefs.getString('tokenExpiration');

  if (token == null || expirationTime == null) {
    return false; // Pas de token ou pas d'heure d'expiration
  }

  final expirationDate = DateTime.parse(expirationTime);

  // Comparer l'heure actuelle avec l'heure d'expiration
  if (DateTime.now().isAfter(expirationDate)) {
    // Token expiré, supprimer le token
    await prefs.remove('token');
    await prefs.remove('tokenExpiration');
    return false;
  }

  return true; // Token toujours valide
}

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    // Stocker le token
    await prefs.setString('token', token);

    // Stocker l'heure d'expiration (1 heure après l'heure actuelle)
    final expirationTime = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
    await prefs.setString('tokenExpiration', expirationTime);
  }

  // Méthode pour se connecter , ApiService.login could return null or a token or an exception
  Future<void> login(String username, String password) async { 
    final token = await ApiService.login(username, password); //response is dynamic
    if (token != null) {
      //test if exception
      if(token is String){
        _token = token;
        await fetchUserData();
        notifyListeners();
      }else{
        _token = null;
        _user = null;
        Logger().e('Erreur de connexion: $token');
        handleLoginError();
        notifyListeners();
      }
    } else {
      _token = null;
      _user = null;
      handleLoginError();
      notifyListeners();
    }
  }

  // Méthode pour s'inscrire ApiService.register could return null or a token or an exception
  Future<String?> register(String username, String password) async {
    final token = await ApiService.register(username, password);
    if (token != null) {
      _token = token;
      await fetchUserData();
      notifyListeners();
      return "Inscription réussie";
    } else {
      _token = null;
      _user = null;
      handleLoginError();
      notifyListeners();
      return "Erreur d'inscription";
    }
  }

   // Méthode pour récupérer les données utilisateur après la connexion
  Future<void> fetchUserData() async {
    if (_token != null) {
      final userData = await ApiService.getUser(_token!);
      if (userData != null) {
        _user = User.fromJson(userData);
      } else {
        _user = null;
        _token = null;
      }
      notifyListeners();
      
    }
  }

  // Méthode pour mettre à jour l'état de l'utilisateur
  Future<void> updateStatus(String newStatus) async {
    if (_token == null || _user == null) return;

    final success = await ApiService.updateStatus(_token!, newStatus);
    if (success) {
      _user!.status = newStatus;
      notifyListeners();
    }
  }

  // Méthode pour ajouter un ami
  Future<void> addFriend(String friendUsername) async {
    if (_token == null) return;

    final success = await ApiService.addFriend(_token!, friendUsername);
    if (success) {
      // Mettez à jour la liste des amis après l'ajout
      await fetchFriends();
    }
  }

  // Méthode pour récupérer la liste des amis et leurs états
  Future<void> fetchFriends() async {
    if (_token == null) return;

    final friendsData = await ApiService.getFriends(_token!);
    if (friendsData != null) {
      _friends = friendsData['friends'].map<User>((json) => User.fromJson(json)).toList();
      notifyListeners();
    }
  }

  //the method returns a list of Menu objects, to be used in the MenuWidget
  Future<List<Menu>> fetchMenus() async {
    if (_token == null) return [];
    final menusData = await ApiService.getMenus(_token!);
    List<Menu> menusRes = [];
    if (menusData != null) {
      for (var menu in menusData) {
        menusRes.add(Menu.fromJson(menu));
      }
    }
    return menusRes;
  }

  //the method returns a list of Menu objects, to be used in the MenuWidget (way better version)
  Future<List<Menu>> fetchMenusALT() async {
    if (_token == null) return [];
    final menusData = await ApiService.getMenusALT(_token!);
    if (menusData != null) {
      return menusData;
    }
    return [];
  }

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    _token = null;
    _friends = [];
    notifyListeners();
  }

  // TODO : Gérer les erreurs de connexion
  void handleLoginError() {
    
  }
}
