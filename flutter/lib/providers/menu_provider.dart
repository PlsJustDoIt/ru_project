import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ru_project/services/api_service.dart';
import '../models/menu.dart';
import '../services/SecureStorage.dart';

class MenuProvider with ChangeNotifier {
  //variables
  List<Menu> _menus = [];
  final _secureStorage = SecureStorage();


  // Getters
  List<Menu> get menus => _menus;

  // Setters  
  void setMenus(List<Menu> menuList) {
    _menus = menuList;
    notifyListeners();
  }


  //constructor
  MenuProvider();


  //get menus from the API
  Future<List<Map<String,dynamic>>> fetchMenus() async {

    final tokens = await _secureStorage.getTokens();
    if (tokens['accessToken'] == null) {
      return [];
    }
    final menusData = await ApiService.getMenus(tokens['accessToken']!);

    return List<Map<String, dynamic>>.from(menusData);
  }
}
