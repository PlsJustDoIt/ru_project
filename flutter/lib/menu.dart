import 'package:flutter/material.dart';
import 'package:ru_project/services/logger.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/menu_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart'; // Import UserProvider

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});
  @override
  State<MenuWidget> createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> with AutomaticKeepAliveClientMixin {
  List<Menu> _menus = [];
  //system de page menu
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // if (_menus.isEmpty) {
    //   _checkLoginStatus();
    // }

    setMenus(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  

  //check if the user is connected and set the menus
  // void _checkLoginStatus() async {
  //   final userProvider = Provider.of<UserProvider>(context, listen: false);
  //   bool isLoggedIn = await userProvider.isConnected();

  //   if (!isLoggedIn || context.mounted == false) {
  //     return;
  //   }

  //   setMenus(context);

  // }

  //set the menus
  void setMenus(BuildContext context) async {
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    if (_menus.isNotEmpty) {
      logger.i('Les menus ne sont pas vides');
    }
    List<Menu> menus = await apiService.getMenus(); // OK
    setState(() {
      _menus = menus;
      menusProvider.setMenus(menus);
    });
  }

  @override
  //build the widget
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Center(
        child: ((_menus.isEmpty)
                ? const Text('Chargement...')
                : Column(
                    children: [
                      menuNavRow(context),
                      menuList(context),
                    ],
                  ))
      ),
    );
  }

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
  
  //build the widget for the menu list
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
              itemCount: _menus.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: 1,
                  itemBuilder: (context, i) {
                    return menuPlat(context, _menus[index].plats);
                  }
                );
              }
            )
          ),
        ],
      )
    );
  }
  
  //build the widget for the menu plats (map key = String, value = List of dynamic or string)
  Column? menuPlat(BuildContext context, Map<String, dynamic> plats) {
    
    // ignore: prefer_const_constructors
    Column res = Column(
      // ignore: prefer_const_literals_to_create_immutables
      children: [],
    );
    plats.forEach((key, value) {
    
      //continue if the value is null, not a list or if key is "Entrées"
      //(en gros si le menu est pas communiqué et si c'est une entrée sa dégage)
      if (value == null || value == "menu non communiqué" || key == "Entrées") {
        return;
      }
    
      //center the text
      res.children.add(Center(
        child: Text(key),
      ));

      

      if (value is String) { //case string
        res.children.add(Center(
          child: Text("- $value"),
        ));
      }else{ //case list dynamic
        String joinedValue = value.map((item) => item.toString()).join('\n- ');
        res.children.add(Center(
          child: Text("- $joinedValue"),
        ));
      }

      res.children.add(const SizedBox(height: 16.0));
    });

    return res;
  }
  
  @override
  bool get wantKeepAlive => true;
}