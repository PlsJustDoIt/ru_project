import 'package:flutter/material.dart';
import 'package:ru_project/models/menu.dart';

class MenuWidget extends StatelessWidget {
   MenuWidget({super.key});

  final List<Menu> _menus = [];

  
  
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      body: Center(
        child: Text('Menu'),
      ),
    );
  }

  

}