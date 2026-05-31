import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/user_service.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  List<RestaurantPartial> _restaurants = [];
  String? _selectedRestaurantId;
  bool _saving = false;
  bool _loadingRestaurants = true;
  late final RestaurantService _restaurantService;
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _restaurantService = Provider.of<RestaurantService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);
    // Initialise sur le restaurant réel de l'utilisateur (_id Mongo).
    _selectedRestaurantId =
        Provider.of<UserProvider>(context, listen: false).user?.restaurantId;
    _loadRestaurants();
  }

  void _loadRestaurants() async {
    try {
      final restaurants = await _restaurantService.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        // Si l'utilisateur n'a pas de resto, défaut = premier de la liste.
        if (_selectedRestaurantId == null && restaurants.isNotEmpty) {
          _selectedRestaurantId = restaurants.first.restaurantId;
        }
        _loadingRestaurants = false;
      });
    } catch (e) {
      // En cas d'erreur, la liste reste vide
      if (mounted) setState(() => _loadingRestaurants = false);
    }
  }

  Future<void> _onChanged(String? value) async {
    if (value == null) return;
    setState(() {
      _selectedRestaurantId = value;
      _saving = true;
    });
    bool ok = false;
    try {
      ok = await _userService.updateRestaurant(value);
      if (ok && mounted) {
        await Provider.of<RestaurantProvider>(context, listen: false)
            .tryLoadRestaurant(value);
      }
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Restaurant mis à jour' : 'Échec de la mise à jour'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paramètres'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choix de votre restaurant universitaire',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                // Hauteur réservée = hauteur du dropdown, pour que le titre ne
                // saute pas pendant le chargement (spinner plus petit).
                height: 64,
                child: _loadingRestaurants
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
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
                      onChanged: _saving ? null : _onChanged,
                    ),
              ),
            ),
            if (_saving) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
