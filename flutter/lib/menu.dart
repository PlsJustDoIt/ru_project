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
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    bool isLoggedIn = userProvider.token != null;
    setState(() {
      _isLoggedIn = isLoggedIn;
      if (_isLoggedIn) {
        setMenus(context);
      }
    });
  }

  void setMenus(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    List<Menu> menus = await userProvider.fetchMenus();
    setState(() {
      _menus = menus;
    });
  }
  /*
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoggedIn
            ? (_menus.isEmpty
                ? const Text('Chargement...')
                : ListView.builder(
                    itemCount: _menus.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        //remainder menu items : entrees, cuisineTraditionnelle, menuVegetalien, pizza, cuisineItalienne, grill
                        title: Text(_menus[index].date),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Entrées: ${_menus[index].entrees ?? "rien"}\n'),
                            Text('Cuisine Traditionnelle: ${_menus[index].cuisineTraditionnelle ?? "rien"}\n'),
                            Text('Menu Végétalien: ${_menus[index].menuVegetalien ?? "rien"}\n'),
                            Text('Pizza: ${_menus[index].pizza ?? "rien"}\n'),
                            Text('Cuisine Italienne: ${_menus[index].cuisineItalienne ?? "rien"}\n'),
                            Text('Grill: ${_menus[index].grill ?? "rien"}\n'),
                          ],
                        ),
                      );
                    },
                  ))
            : const Text('Please log in to view the menu'),
      ),
    );
  }
  */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoggedIn
            ? (_menus.isEmpty
                ? const Text('Chargement...')
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _menus.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(_menus[index].date),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Entrées: ${_menus[index].entrees ?? "rien"}\n'),
                                  Text('Cuisine Traditionnelle: ${_menus[index].cuisineTraditionnelle ?? "rien"}\n'),
                                  Text('Menu Végétalien: ${_menus[index].menuVegetalien ?? "rien"}\n'),
                                  Text('Pizza: ${_menus[index].pizza ?? "rien"}\n'),
                                  Text('Cuisine Italienne: ${_menus[index].cuisineItalienne ?? "rien"}\n'),
                                  Text('Grill: ${_menus[index].grill ?? "rien"}\n'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () {
                              if (_currentPage > 0) {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
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
                      ),
                    ],
                  ))
            : const Text('Please log in to view the menu'),
      ),
    );
  }
}