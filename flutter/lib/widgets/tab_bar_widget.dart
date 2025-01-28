import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/widgets/menu_widget.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/widgets/debug_widget.dart';
import 'package:ru_project/widgets/tables.dart';
import 'package:ru_project/widgets/profile.dart';
import 'package:ru_project/widgets/welcome.dart';
import 'package:ru_project/widgets/friends_widget.dart';
import 'package:ru_project/widgets/bus_widget.dart';
import 'package:ru_project/widgets/chat_screen_widget.dart';
import 'package:ru_project/widgets/chat_page_widget.dart';
import 'package:liquid_swipe/liquid_swipe.dart';

class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final apiService = Provider.of<ApiService>(context);

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Projet ru de léo',
            style: TextStyle(
                fontFamily: 'Marianne', color: AppColors.secondaryColor),
          ),
          leading: IconButton(
              icon: Icon(Icons.bug_report),
              color: Colors.white,
              onPressed: () {
                BetterFeedback.of(context).show((UserFeedback feedback) async {
                  bool res = await apiService.sendFeedback(feedback);
                  if (!context.mounted) {
                    return;
                  }
                  if (res) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Feedback envoyé :)')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Echec de l\'envoi du feedback :(')));
                  }
                });
              }),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                color: Colors.white,
                onPressed: () async {
                  bool res = await apiService.logout();
                  userProvider.logout();
                  //log out apiservice (test bool)
                  if (!context.mounted) {
                    return;
                  }
                  if (res) {
                    logger.i('Logout successful');
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Déconnexion réussie')));
                  } else {
                    logger.e('Logout failed');
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Déconnexion échouée')));
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WelcomeWidget()),
                  );
                }),
          ],
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
              Tab(icon: Icon(Icons.fiber_new), text: 'amis'),
              Tab(icon: Icon(Icons.messenger), text: 'Chat'),
              Tab(icon: Icon(Icons.person), text: 'Profil'),
              Tab(icon: Icon(Icons.directions_bus), text: 'Bus'),
              Tab(icon: Icon(Icons.bug_report), text: 'Debug'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const CafeteriaLayout(),
            const MenuWidget(),
            FriendsListSheet(),
            CircularProgressIndicator(),
            ProfileWidget(),
            TransportTimeWidget(),
            DebugWidget(),
          ],
        ),
      ),
    );
  }
}
