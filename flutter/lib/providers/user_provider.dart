import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';

class UserProvider with ChangeNotifier {
  User? _user; // Utilisateur actuellement connecté
  List<User> _friends = []; // Liste des amis de l'utilisateur

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  UserProvider();

  User? get user => _user;
  List<User> get friends => _friends;

  // Met à jour l'utilisateur et notifie les widgets écoutant cet état
  void setUser(User? user) {
    if (user == null) {
      clearUserData();
      _isConnected = false;
      notifyListeners();
      return;
    }
    _user = user;
    _isConnected = true;
    notifyListeners();
  }

  // Réinitialise les données utilisateur et notifie les widgets
  void clearUserData() {
    _user = null;
    _friends = [];
    _isConnected = false;
    notifyListeners();
  }
}
