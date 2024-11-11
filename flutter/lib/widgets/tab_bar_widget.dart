import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/menu.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/widgets/debug_widget.dart';
import 'package:ru_project/widgets/tables.dart';
import 'package:ru_project/widgets/profile.dart';

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return DefaultTabController(
      length: 4,
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
              Tab(icon: Icon(Icons.person), text: 'Profil'),
              Tab(icon: Icon(Icons.bug_report), text: 'Debug'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CafeteriaLayout(),
            const MenuWidget(),
            ProfileWidget(user: userProvider.user, onUserUpdated: (user) {
              // save to backend
              Logger().i("User updated: $user['username'])");
              Logger().i('User updated: $user');
            }),
            DebugWidget(),
          ],
        ),
      ),
    );
  }
}
