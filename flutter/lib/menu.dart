import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/menu_provider.dart';
import 'package:ru_project/providers/user_provider.dart'; // Import UserProvider

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});
  @override
  _MenuWidgetState createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  List<Menu> _menus = [];
  Map<String,dynamic> _rawMenuData = {};
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
    bool isLoggedIn = userProvider.accessToken != null;
    setState(() {
      _isLoggedIn = isLoggedIn;
      if (_isLoggedIn) {
        setMenus(context);
      }
    });
  }

  void setMenus(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);

    if (menusProvider.isMenuSet) {
      setState(() {
        _menus = menusProvider.menuList;
        _rawMenuData = menusProvider.menuData;
      });
      return;
    }

    Map<String,dynamic> rawMenuData = await userProvider.fetchMenus();
    List<Menu> menus;
    if (rawMenuData != null) {
      menus = rawMenuData.values.map<Menu>((menu) => Menu.fromJson(menu)).toList();
    } else {
      menus = [];
    }
    setState(() {
      _menus = menus;
      _rawMenuData = rawMenuData;
      menusProvider.setMenus(menus);
      menusProvider.setMenuData(rawMenuData);
    });
  }

  @override
  //build the widget
  Widget build(BuildContext context) {
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);
    return Scaffold(
      body: Center(
        child: _isLoggedIn
            ? (!menusProvider.isMenuSet //TODO TEST THIS
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
       
  Widget buildMenuList(BuildContext context) {
    return const Expanded(
      child: Column(
        children : [
          Text(
            'Déjeuner',
            style: TextStyle(
              fontSize: 20.0,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 16.0),
          Expanded(
            child: Text('TODO : PageView.builder'),
          ),
        ],
      )
    );
  }
  
}

/* 
old :

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
          const SizedBox(height: 16.0),
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
                    //si la liste n'est pas vide ou si menu Keys[i] n est pas "entrees"
                    if (_menus[index].getListFromKey(_menus[index].menuKeys[i]) != null && _menus[index].menuKeys[i] != "entrees") {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text('${_menus[index].menuNames[i]} :'),
                          Text(' - ${_menus[index].getListFromKey(_menus[index].menuKeys[i])?.join('\n - ') ?? "RIEN"}'),
                          const SizedBox(height: 16.0),
                        ],
                      );
                      
                    }
                    return null;
                  },
                );
                
              },
            ),
          ),
        ],
      )
    );
  }



  BEST VERSION HERE instead of ListView.builder
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