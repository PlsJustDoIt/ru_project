import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/services/api_service.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  List<Restaurant> _restaurants = [];
  String? _selectedRestaurantId;
  bool _isLoading = true;
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);

    _loadRestaurants();
  }

  void _loadRestaurants() async {
    try {
      final restaurants = await _apiService.getRestaurants();
      setState(() {
        _restaurants = restaurants;
        _isLoading = false;
        // Sélectionner le premier restaurant par défaut s'il existe
        if (restaurants.isNotEmpty) {
          _selectedRestaurantId = restaurants.first.id;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildRestaurantDropdown() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }

    if (_restaurants.isEmpty) {
      return const Text('Aucun restaurant disponible');
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Restaurant universitaire',
      ),
      value: _selectedRestaurantId,
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
      },
    );
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
                  value: _selectedRestaurantId,
                  items: _restaurants.map((restaurant) {
                    return DropdownMenuItem<String>(
                      value: restaurant.id,
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
