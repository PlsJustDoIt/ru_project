import 'package:flutter/material.dart';
import 'package:ru_project/models/restaurant.dart';

/// Liste des restaurants CROUS avec barre de recherche : le flux officiel
/// en compte plusieurs dizaines, un simple dropdown n'est pas tenable.
/// Utilisé par l'inscription / onboarding invité ([RestaurantPicker])
/// et par les paramètres (sélection puis pop avec le résultat).
class RestaurantSelectorList extends StatefulWidget {
  const RestaurantSelectorList({
    super.key,
    required this.restaurants,
    required this.selectedId,
    required this.onSelect,
  });

  final List<RestaurantPartial> restaurants;
  final String? selectedId;
  final void Function(RestaurantPartial restaurant) onSelect;

  @override
  State<RestaurantSelectorList> createState() =>
      _RestaurantSelectorListState();
}

class _RestaurantSelectorListState extends State<RestaurantSelectorList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.restaurants
        : widget.restaurants
            .where((r) =>
                r.name.toLowerCase().contains(query) ||
                (r.zone?.toLowerCase().contains(query) ?? false) ||
                (r.address?.toLowerCase().contains(query) ?? false))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Rechercher (nom, ville...)',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('Aucun restaurant trouvé',
                      style: theme.textTheme.bodyMedium),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final r = filtered[index];
                    final selected = r.restaurantId == widget.selectedId;
                    return ListTile(
                      leading: Icon(_typeIcon(r.type),
                          color: theme.colorScheme.primary),
                      title: Text(r.name,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          )),
                      subtitle: (r.address != null && r.address!.isNotEmpty)
                          ? Text(r.address!,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: selected
                          ? Icon(Icons.check_circle,
                              color: theme.colorScheme.primary)
                          : null,
                      onTap: () => widget.onSelect(r),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'Cafétéria':
        return Icons.local_cafe_outlined;
      case 'Foodtruck':
        return Icons.local_shipping_outlined;
      case 'Brasserie':
        return Icons.local_bar_outlined;
      default:
        return Icons.restaurant_outlined; // Restaurant & assimilés
    }
  }
}
