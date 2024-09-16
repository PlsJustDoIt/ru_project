import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/login_page.dart';
import 'package:ru_project/widgets/tabBar.dart';
import '../providers/user_provider.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${userProvider.user?.username}'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              userProvider.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
              
            },
          ),
        ],
      ),
      body: TabBarWidget(),
    );
  }
}
