import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/models/user.dart';

class MenuWidget extends StatefulWidget {
  MenuWidget({super.key});

  @override
  _MenuWidgetState createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  List<Menu> _menus = [];
   // TODO: Replace with user token
  final String _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY2ZGRjNjUzYmEzN2EyYmZjNTZjYzNkMiIsImlhdCI6MTcyNjA1Nzg3MiwiZXhwIjoxNzI2MDYxNDcyfQ.5mw-gdIGbm8DvfR-UfoogpQTnV7VEuUc5sEtIohmwGo';

  @override
  void initState() {
    super.initState();
    _fetchMenus();
  }

  Future<void> _fetchMenus() async {
    try {
      final Map<String, dynamic>? response = await ApiService.getMenus(_token); // Call the API service
      List<Menu> menus = []; 
      if (response == null) {
        throw Exception('Failed to fetch menus');
      }
      //menus = List<Menu>.from(response['menus'].map((x) => Menu.fromJson(x))); a revoir
      setState(() {
        _menus = menus;
      });
    } catch (e) {
      // Handle error
      print('Failed to fetch menus: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _menus.isEmpty
            ? const Text('Chargement...')
            : ListView.builder(
                itemCount: _menus.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_menus[index].date), // Display the date of the menu
                  );
                },
              ),
      ),
    );
  }
}