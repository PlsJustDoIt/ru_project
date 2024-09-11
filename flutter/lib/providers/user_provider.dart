import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  String? _token;
  List<User> _friends = [];

  // Getters
  User? get user => _user;
  String? get token => _token;
  List<User> get friends => _friends;

  // Méthode pour se connecter
  Future<void> login(String username, String password) async {
    final token = await ApiService.login(username, password); //response is dynamic //TODO géré les erreurs
    if (token != null) {
      _token = token;
      await fetchUserData();
      notifyListeners();
    } else {
      _token = null;
      _user = null;
      handleLoginError();
      notifyListeners();
    }
  }

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

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    _token = null;
    _friends = [];
    notifyListeners();
  }

  
  void handleLoginError() {
    // TODO : Gérer les erreurs de connexion
  }
}
