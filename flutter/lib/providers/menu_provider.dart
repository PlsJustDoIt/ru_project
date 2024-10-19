import 'package:flutter/material.dart';
import '../models/menu.dart';

class MenuProvider with ChangeNotifier {
  Map<String,dynamic> _menuRawData = {};
  List<Menu> _menus = [];
  bool _isMenuSet = false;

  // Getters
  List<Menu> get menuList => _menus;
  Map<String,dynamic> get menuData => _menuRawData;
  bool get isMenuSet => _isMenuSet;

  //Setters
  void setMenuData(Map<String,dynamic> data) {
    _menuRawData = data;
    _isMenuSet = true;
    notifyListeners();
  }

  void setMenus(List<Menu> menuList) {
    _menus = menuList;
    notifyListeners();
  }


  //constructor
  MenuProvider();
}
