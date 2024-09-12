import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/user_provider.dart';

class MenuWidget extends StatefulWidget {
  MenuWidget({super.key});

  @override
  _MenuWidgetState createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  List<Menu> _menus = [];
  
  @override
  void initState() {
    setMenus();
    super.initState();
  }

  void setMenus() async {
    final userProvider = Provider.of<UserProvider>(context);
    List<Menu> menus = await userProvider.fetchMenus();
    _menus = menus;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
  
    return Scaffold(
      body: Center(
        child: _menus.isEmpty
            ? const Text('Chargement...')
            : ListView.builder(
                itemCount: _menus.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_menus[index].date), // Display the date of the menu
                  );
                },
              ),
      ),
    );
  }
}