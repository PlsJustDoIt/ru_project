import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/widgets/restaurant_selector_list.dart';

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

  /// Appelé avec l'id CROUS officiel du restaurant choisi ('r135').
  final Future<void> Function(BuildContext context, String restaurantId) onSelected;

  @override
  State<RestaurantPicker> createState() => _RestaurantPickerState();
}

class _RestaurantPickerState extends State<RestaurantPicker> {
  List<RestaurantPartial> _restaurants = [];
  RestaurantPartial? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
        if (restaurants.isNotEmpty) {
          _selected = restaurants.firstWhere(
            (r) => r.restaurantId == widget.initialRestaurantId,
            orElse: () => restaurants.first,
          );
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
    final selected = _selected;
    if (selected == null) return;
    setState(() => _submitting = true);
    await widget.onSelected(context, selected.restaurantId);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : Column(
                      children: [
                        const Text('Choisissez votre restaurant universitaire',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: RestaurantSelectorList(
                            restaurants: _restaurants,
                            selectedId: _selected?.restaurantId,
                            onSelect: (r) => setState(() => _selected = r),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_selected == null || _submitting) ? null : _confirm,
                            child: _submitting
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(widget.confirmLabel),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
