import 'package:flutter/material.dart';
import 'package:ru_project/login_page.dart';
import 'package:ru_project/menu.dart';



class TabBarWidget extends StatelessWidget {
  const TabBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Projet ru de léo'),
          backgroundColor: const Color.fromARGB(209, 66, 206, 62),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.login), text: 'Default'),
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Menu ru'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LoginPage(),
            MenuWidget(),
          ],
        ),
      ),
    );
  }
}