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
  final PageController _pageController = PageController();
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
    if (userProvider.menus.isNotEmpty) {
      setState(() {
        _menus = userProvider.menus;
      });
      return;
    }
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

  //build the widget for the menu navigation row 
  Widget buildMenuNavRow(BuildContext context) {
    const buttonSize = 50.0; //temp
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
        Expanded(
          child: Center(
            child: Text('Menu du ${_menus[_currentPage].date}'),
          ),
        ),
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
      child: Column(
        children: [
          const Text(
            'Déjeuner',
            style: TextStyle(
              fontSize: 20.0,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14.0),
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
                return ListView.builder(
                  shrinkWrap: true,
                  //physics: const NeverScrollableScrollPhysics(),
                  itemCount: _menus[index].numberOfMenus,
                  itemBuilder: (context, i) {
                    if (_menus[index].getListFromKey(_menus[index].menuKeys[i]) != null){
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('${_menus[index].menuNames[i]} :'),
                          Text(' - ${_menus[index].getListFromKey(_menus[index].menuKeys[i])?.join('\n - ') ?? "RIEN"}'),
                          const SizedBox(height: 16.0),
                        ],
                      );
                      
                    }
                  },
                );
                
              },
            ),
          ),
        ],
      )
    );
  }
}

/* BEST VERSION HERE instead of ListView.builder
          return SingleChildScrollView(
            child: ListTile( //TODO : listview build
              //alignment:
              title: const Center(child: Text('Déjeuner')),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  //Text('Entrées:\n - ${_menus[index].entrees?.join('\n - ') ?? "RIEN"}\n'), 
                  Text('Cuisine Traditionnelle:\n - ${_menus[index].cuisineTraditionnelle?.join('\n - ') ?? "RIEN"}\nMenu Végétalien:\n - ${_menus[index].menuVegetalien?.join('\n - ') ?? "RIEN"}\nPizza:\n - ${_menus[index].pizza?.join('\n - ') ?? "RIEN"}\nCuisine Italienne:\n - ${_menus[index].cuisineItalienne?.join('\n - ') ?? "RIEN"}\nGrill:\n - ${_menus[index].grill?.join('\n - ') ?? "RIEN"}\n'),
                ],
              ),
            ),
          );
          */