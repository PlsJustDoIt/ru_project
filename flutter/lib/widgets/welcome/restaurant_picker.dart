import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/services/restaurant_service.dart';

/// Écran de sélection d'un restaurant. Réutilisé par l'onboarding invité,
/// l'inscription et le changement de RU invité.
class RestaurantPicker extends StatefulWidget {
  const RestaurantPicker({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onSelected,
    this.initialRestaurantId,
  });

  final String title;
  final String confirmLabel;
  final String? initialRestaurantId;

  /// Appelé avec l'_id Mongo du restaurant choisi.
  final Future<void> Function(BuildContext context, String restaurantId) onSelected;

  @override
  State<RestaurantPicker> createState() => _RestaurantPickerState();
}

class _RestaurantPickerState extends State<RestaurantPicker> {
  List<RestaurantPartial> _restaurants = [];
  String? _selectedId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialRestaurantId;
    _load();
  }

  Future<void> _load() async {
    final service = Provider.of<RestaurantService>(context, listen: false);
    try {
      final restaurants = await service.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _loading = false;
        final ids = restaurants.map((r) => r.restaurantId).toSet();
        if ((_selectedId == null || !ids.contains(_selectedId)) &&
            restaurants.isNotEmpty) {
          _selectedId = restaurants.first.restaurantId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les restaurants.';
      });
    }
  }

  Future<void> _confirm() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _submitting = true);
    await widget.onSelected(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Choisissez votre restaurant universitaire',
                          style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Restaurant universitaire',
                        ),
                        initialValue: _selectedId,
                        items: _restaurants
                            .map((r) => DropdownMenuItem<String>(
                                  value: r.restaurantId,
                                  child: Text(r.name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedId = value),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_selectedId == null || _submitting) ? null : _confirm,
                        child: _submitting
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(widget.confirmLabel),
                      ),
                    ],
                  ),
      ),
    );
  }
}
