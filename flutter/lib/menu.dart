import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/user_provider.dart'; // Import UserProvider

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});

  @override
  _MenuWidgetState createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  List<Menu> _menus = [];
  bool _isLoggedIn = false;
  //system de page menu
  PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // _checkLoginStatus();
  }

  // void _checkLoginStatus() async {
  //   final userProvider = Provider.of<UserProvider>(context, listen: false);
  //   bool isLoggedIn = userProvider.token != null;
  //   setState(() {
  //     _isLoggedIn = isLoggedIn;
  //     if (_isLoggedIn) {
  //       setMenus(context);
  //     }
  //   });
  // }

  void setMenus(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    List<Menu> menus = await userProvider.fetchMenus(); //fetchMenusALT is better
    setState(() {
      _menus = menus;
    });
  }

  @override
  //build the widget
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoggedIn
            ? (_menus.isEmpty
                ? const Text('Chargement...')
                : Column(
                    children: [
                      buildMenuNavRow(context),
                      buildMenuList(context),
                    ],
                  ))
            : const Text('Please log in to view the menu'),
      ),
    );
  }

  //build the widget for the menu navigation row (TODO : problem overflows if the screen is not wide enough) 
  Row buildMenuNavRow(context){
    const buttonSize = 50.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton( //left button
          icon: const Icon(Icons.arrow_back),
          iconSize: buttonSize,
          onPressed: () {
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
        Text(_menus[_currentPage].date),
        IconButton( //right button
          icon: const Icon(Icons.arrow_forward),
          iconSize: buttonSize,
          onPressed: () {
            if (_currentPage < _menus.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        ),
      ],
    );
  }

  //build the widget for the menu list
  Widget buildMenuList(BuildContext context) {
    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        itemCount: _menus.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            child: ListTile(
              title: Text(_menus[index].date),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrées:\n - ${_menus[index].entrees?.join('\n - ') ?? "RIEN"}\n'),
                  Text('Cuisine Traditionnelle:\n - ${_menus[index].cuisineTraditionnelle?.join('\n - ') ?? "RIEN"}\n'),
                  Text('Menu Végétalien:\n - ${_menus[index].menuVegetalien?.join('\n - ') ?? "RIEN"}\n'),
                  Text('Pizza:\n - ${_menus[index].pizza?.join('\n - ') ?? "RIEN"}\n'),
                  Text('Cuisine Italienne:\n - ${_menus[index].cuisineItalienne?.join('\n - ') ?? "RIEN"}\n'),
                  Text('Grill:\n - ${_menus[index].grill?.join('\n - ') ?? "RIEN"}\n'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}