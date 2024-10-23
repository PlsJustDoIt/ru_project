import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
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
  //List<Map<String,dynamic>> _rawMenuData = [];
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
    bool isLoggedIn = await userProvider.isConnected();
    setState(() {
      _isLoggedIn = isLoggedIn;
      if (_isLoggedIn) {
        setMenus(context);
      }
    });
  }

  void setMenus(BuildContext context) async {
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);
    
    //test si le menu a le token
    //TODO : virer cette merde de code
    if (menusProvider.accessToken == null) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.accessToken == null) {
        Logger().e('No token found in UserProvider');
        return;
      }
      menusProvider.storeTokens(userProvider.accessToken!, userProvider.refreshToken!);
    }


    //si le menu est déjà chargé dans le provider
    if (menusProvider.menus.isNotEmpty) { // OK
      setState(() {
        _menus = menusProvider.menus;
        //_rawMenuData = menusProvider.menuData;
      });
      return;
    }


    List<Map<String,dynamic>> rawMenuData = await menusProvider.fetchMenus(); // OK
    List<Menu> menus; // OK

    if (rawMenuData.isEmpty) { // à voir si c'est useless ou pas
      menus = []; 
    } else {
      menus = rawMenuData.map((menu) => Menu.fromJson(menu)).toList();
    }
    setState(() {
      _menus = menus;
      //_rawMenuData = rawMenuData;
      menusProvider.setMenus(menus);
      //menusProvider.setMenuData(rawMenuData);
    });
  }

  @override
  //build the widget
  Widget build(BuildContext context) {
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);
    //final userProvider = Provider.of<UserProvider>(context, listen: false); // jsp
    return Scaffold(
      body: Center(
        child: _isLoggedIn
            ? (menusProvider.menus.isEmpty //TODO TEST THIS
                ? const Text('Chargement...')
                : Column(
                    children: [
                      menuNavRow(context),
                      menuList(context),
                    ],
                  ))
            : const Text('connecte toi frr'),
      ),
    );
  }

  // build the all menu widget
  /*
    widget la_totale(BuildContext context, List<Menu> menus) {

    foreach(Menu menu in menus) {
      return Column(
        children: [
          menuNavRow(context, menu),
          menuList(context, menu),
        ],
      );
    }
  */

  //build the widget for the menu navigation row 
  Widget menuNavRow(BuildContext context) {
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
            child: Text('Menu du ${_menus[_currentPage].date}'), // à voir avec _menus
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
       
  Widget menuList(BuildContext context) {
    return Expanded(
      child: Column(
        children : [
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
              itemCount: _menus.length, // a voir
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rawMenuData[_currentPage].length,
                  itemBuilder: (context, i) {
                    // if (_rawMenuData[_currentPage].keys.elementAt(i) != "Entrées"|| _rawMenuData[_currentPage].keys.elementAt(i) != "date"|| _rawMenuData[_currentPage].keys.elementAt(i) != "menu non communiqué") {
                    //   Logger().i('Menu keys: ${_rawMenuData[_currentPage].keys}');
                    //   return Column(
                    //     crossAxisAlignment: CrossAxisAlignment.center,
                    //     children: [
                    //       Text('${_rawMenuData[_currentPage].keys.elementAt(i)} :'),
                    //       Text(' - ${_rawMenuData[_currentPage].values.elementAt(i)}'),
                    //       //Text(' - ${_rawMenuData[_currentPage].values.elementAt(i).join('\n - ') ?? "RIEN"}'),

                    //       const SizedBox(height: 16.0),
                    //     ],
                    //   );
                    // }
                    return null;
                  }
                );
              }
            )
          ),
        ],
      )
    );
  }
  
}

