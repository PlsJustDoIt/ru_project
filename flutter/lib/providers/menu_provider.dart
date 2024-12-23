import 'package:flutter/material.dart';
import 'package:ru_project/services/api_service.dart';
import '../models/menu.dart';
import '../services/secure_storage.dart';

class MenuProvider with ChangeNotifier {
  //variables
  List<Menu> _menus = [];
  final _secureStorage = SecureStorage();

  // Getters
  List<Menu> get menus => _menus;

  // Setters
  void setMenus(List<Menu> menus) {
    _menus = menus;
    notifyListeners();
  }

  //constructor
  MenuProvider();
}
