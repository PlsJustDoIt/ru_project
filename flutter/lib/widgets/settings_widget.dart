import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/services/restaurant_service.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  List<RestaurantPartial> _restaurants = [];
  String? _selectedRestaurantId;
  late final RestaurantService _restaurantService;

  @override
  void initState() {
    super.initState();
    _restaurantService = Provider.of<RestaurantService>(context, listen: false);

    _loadRestaurants();
  }

  void _loadRestaurants() async {
    try {
      final restaurants = await _restaurantService.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        // Sélectionner le premier restaurant par défaut s'il existe
        if (restaurants.isNotEmpty) {
          _selectedRestaurantId = restaurants.first.restaurantId;
        }
      });
    } catch (e) {
      // En cas d'erreur, la liste reste vide
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Paramètres'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choix de votre restaurant universitaire',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Restaurant universitaire',
                  ),
                  initialValue: _selectedRestaurantId,
                  items: _restaurants.map((restaurant) {
                    return DropdownMenuItem<String>(
                      value: restaurant.restaurantId,
                      child: Text(restaurant.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRestaurantId = value;
                    });
                    // Vous pouvez ajouter ici la logique pour sauvegarder le choix de l'utilisateur
                    // Par exemple, l'enregistrer dans SharedPreferences
                  },
                )),
          ],
        ),
      ),
    );
  }
}
