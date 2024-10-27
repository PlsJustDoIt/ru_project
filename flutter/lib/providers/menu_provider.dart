import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:ru_project/services/api_service.dart';
import '../models/menu.dart';
import '../services/SecureStorage.dart';

class MenuProvider with ChangeNotifier {
  //variables
  // List<Map<String,dynamic>> _menuRawData = [];
  List<Menu> _menus = [];

  //user token 
  String? _accessToken;
  String? _refreshToken;
  final _secureStorage = SecureStorage();


  // Getters
  List<Menu> get menus => _menus;
  // List<Map<String,dynamic>> get menuData => _menuRawData;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  // //Setters
  // void setMenuData(List<Map<String,dynamic>> data) {
  //   _menuRawData = data;
  //   notifyListeners();
  // }

  void setMenus(List<Menu> menuList) {
    _menus = menuList;
    notifyListeners();
  }


  //constructor
  MenuProvider(){
    loadTokens();
  }

  //functions
  Future<void> storeTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    await _secureStorage.storeTokens(accessToken, refreshToken);

    notifyListeners();
  }

  Future<void> loadTokens() async {
    final tokens = await _secureStorage.getTokens();
    _accessToken = tokens['accessToken'];
    _refreshToken = tokens['refreshToken'];
    
    notifyListeners();
  }

  Future<void> clearTokens() async {
    await _secureStorage.clearTokens();

    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }


  //get menus from the API
  Future<List<Map<String,dynamic>>> fetchMenus() async {
    if (_accessToken == null){
      //Logger().e('No access token');
      return [];
    }
    //Logger().i('Fetching menus');
    final menusData = await ApiService.getMenus(_accessToken!);

    return List<Map<String, dynamic>>.from(menusData);
  }
}
