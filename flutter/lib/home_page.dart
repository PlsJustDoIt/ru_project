import 'package:flutter/material.dart';
import 'package:ru_project/widgets/tabBar.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      body: TabBarWidget(),
    );
  }
}
