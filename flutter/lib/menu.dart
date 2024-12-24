import 'package:flutter/material.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/services/logger.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/menu_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart'; // Import UserProvider
import 'package:intl/intl.dart';

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});
  @override
  State<MenuWidget> createState() => _MenuWidgetState();
}

/*
// Fonction pour convertir la date
const formatDate = (dateString: string): string => {
    // Parsing de la date au format 'YYYY-MM-DD'
    const date = parse(dateString, 'yyyy-MM-dd', new Date());
    // Formatage de la date au format 'dddd d MMMM yyyy'
    return format(date, 'eeee d MMMM yyyy', { locale: fr });
};
 */

String formatDate(String dateString) {
  DateTime date = DateTime.parse(dateString);
  String formattedDate = DateFormat('EEEE d MMMM y', 'fr_FR').format(date);
  return formattedDate;
}

// TODO : Amélioration posible en choisissant l'index la plus proche de la date actuelle a partir de la date du menu
int indexCloserDateInMenus(List<Menu> menus) {
  if (menus.isEmpty) return 0;

  DateTime now = DateTime.now();
  int index = 0;
  int minDiff = (DateTime.parse(menus[0].date).difference(now)).inDays.abs();

  for (int i = 1; i < menus.length; i++) {
    int diff = (DateTime.parse(menus[i].date).difference(now)).inDays.abs();
    if (diff < minDiff) {
      minDiff = diff;
      index = i;
    }
  }
  return index;
}

class _MenuWidgetState extends State<MenuWidget>
    with AutomaticKeepAliveClientMixin {
  List<Menu> _menus = [];
  //system de page menu
  PageController _pageController = PageController();
  int _currentPage = 0;
  var screenSize = 0.0;

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

  //set the menus
  void setMenus(BuildContext context) async {
    final menusProvider = Provider.of<MenuProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    if (_menus.isNotEmpty) {
      logger.i('Les menus ne sont pas vides');
    }
    List<Menu> menus = await apiService.getMenus(); // OK
    if (menus.isEmpty) {
      logger.i('Les menus sont vides');
      return;
    }
    setState(() {
      _menus = menus;
      menusProvider.setMenus(menus);
      _currentPage = indexCloserDateInMenus(menus);
      _pageController = PageController(initialPage: _currentPage);
    });
  }

  @override
  //build the widget
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size.width;
    super.build(context);
    return Scaffold(
      body: Center(
          child: ((_menus.isEmpty)
              ? const Text('Chargement...')
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      menuNavRow(context),
                      const SizedBox(height: 16.0),
                      menuList(context),
                    ],
                  )))),
    );
  }

  //build the widget for the menu navigation row
  Widget menuNavRow(BuildContext context) {
    const buttonSize = 50.0; //temp
    return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          //TODO : la decoration est a revoir
          border: Border.all(
            color: AppColors.primaryColor,
            width: 3.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              //left button
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
                child: Text(
                  'Menu du ${formatDate(_menus[_currentPage].date)}',
                  style: TextStyle(
                    fontSize: (screenSize * 0.02).clamp(16.0, 25.0),
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            IconButton(
              //right button
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
        ));
  }

  //build the widget for the menu list
  Widget menuList(BuildContext context) {
    return Expanded(
        child: Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        //TODO : la decoration est a revoir
        border: Border.all(
          color: AppColors.primaryColor,
          width: 3.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        children: [
          Text(
            'Déjeuner',
            style: TextStyle(
              fontSize: (screenSize * 0.018).clamp(16.0, 25.0),
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
                        });
                  })),
        ],
      ),
    ));
  }

  //build the widget for the menu plats (map key = String, value = List of dynamic or string), TODO : faire un option cas ou jour ferie
  Column? menuPlat(BuildContext context, Map<String, dynamic> plats) {
    final fontSize = (screenSize * 0.015).clamp(15.0, 20.0);
    Column res = Column(
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
        child: Text(key,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
            )),
      ));

      if (value is String) {
        //case string
        res.children.add(Center(
          child: Text("- $value",
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.black,
              )),
        ));
      } else {
        //case list dynamic
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
