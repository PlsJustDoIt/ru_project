import 'package:flutter/material.dart';
import 'package:ru_project/login_page.dart';
import 'package:ru_project/menu.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/widgets/restaurantMap.dart';

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Projet ru de léo',
            style: TextStyle(
                fontFamily: 'Marianne', color: AppColors.secondaryColor),
          ),
          backgroundColor: AppColors.primaryColor,
          bottom: const TabBar(
            labelColor:
                Colors.white, // Couleur du texte et de l'icône sélectionnés
            unselectedLabelColor: AppColors
                .greyLight, // Couleur du texte et de l'icône non sélectionnés
            indicatorColor: Colors
                .yellow, // Couleur de l'indicateur sous l'onglet sélectionné
            tabs: [
              Tab(icon: Icon(Icons.login), text: 'Carte ru'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu ru'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            restaurantMapWidget(),
            MenuWidget(),
          ],
        ),
      ),
    );
  }
}
