import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/menu.dart';
import 'package:intl/intl.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/services/user_service.dart';

class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});
  @override
  State<MenuWidget> createState() => _MenuWidgetState();
}

/// Icône associée à une catégorie de plats (flux CROUS).
IconData _categoryIcon(String category) {
  switch (category) {
    case 'Entrées':
      return Icons.egg_alt_outlined;
    case 'Cuisine traditionnelle':
      return Icons.restaurant;
    case 'Menu végétalien':
      return Icons.eco_outlined;
    case 'Pizza':
      return Icons.local_pizza_outlined;
    case 'Cuisine italienne':
      return Icons.local_dining_outlined;
    case 'Grill':
      return Icons.outdoor_grill_outlined;
    default:
      return Icons.restaurant_menu;
  }
}

String _formatFullDate(String dateString) {
  final date = DateTime.parse(dateString);
  return DateFormat('EEEE d MMMM y', 'fr_FR').format(date);
}

String _formatChip(String dateString) {
  final date = DateTime.parse(dateString);
  final label = DateFormat('EEE d', 'fr_FR').format(date);
  return label[0].toUpperCase() + label.substring(1);
}

class _MenuWidgetState extends State<MenuWidget>
    with AutomaticKeepAliveClientMixin {
  List<Menu> _menus = [];
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _joining = false;
  late final RestaurantService restaurantService;
  late final UserService userService;
  late final SocketService socketService;

  @override
  void initState() {
    super.initState();
    restaurantService = Provider.of<RestaurantService>(context, listen: false);
    userService = Provider.of<UserService>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
    _loadMenus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMenus() async {
    final menus = await restaurantService.getMenus();
    if (menus.isEmpty) {
      logger.i('Les menus sont vides');
      return;
    }
    if (mounted) setState(() => _menus = menus);
  }

  void _selectDay(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_menus.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _dayStrip(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _menus.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) => _dayView(_menus[index]),
          ),
        ),
        _eatHereBar(),
      ],
    );
  }

  /// Accroche sociale : relie le menu au statut « au ru » et au chat Global.
  Widget _eatHereBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _joining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.restaurant),
            label: const Text('On y mange ?'),
            onPressed: _joining ? null : _onEatHere,
          ),
        ),
      ),
    );
  }

  Future<void> _onEatHere() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    setState(() => _joining = true);
    try {
      final result = await userService.updateStatus('au ru');
      if (result['success'] == true) {
        user.status = 'au ru';
        userProvider.setUser(user);
        await socketService.sendMessageToRoom(
            'Global', '${user.username} mange au RU aujourd\'hui 🍽️');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Statut « au ru » — Global prévenu')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la mise à jour du statut')),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  /// Bandeau de jours cliquables, jour sélectionné mis en avant.
  Widget _dayStrip() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _menus.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == _currentPage;
          return ChoiceChip(
            label: Text(_formatChip(_menus[index].date)),
            selected: selected,
            onSelected: (_) => _selectDay(index),
            labelStyle: TextStyle(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            selectedColor: theme.colorScheme.primary,
            showCheckmark: false,
          );
        },
      ),
    );
  }

  /// Vue détaillée d'un jour : toutes les catégories en cartes, lisibles d'un coup.
  Widget _dayView(Menu menu) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Déjeuner — ${_formatFullDate(menu.date)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (menu.isClosed())
          _closedCard(menu.fermeture ?? 'Fermé')
        else
          ..._categoryCards(menu.plats),
      ],
    );
  }

  Widget _closedCard(String message) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(Icons.no_meals, color: theme.colorScheme.primary),
        title: const Text('Fermé'),
        subtitle: Text(message),
      ),
    );
  }

  List<Widget> _categoryCards(Map<String, dynamic>? plats) {
    if (plats == null) {
      return [_closedCard('Menu non communiqué')];
    }

    final cards = <Widget>[];
    plats.forEach((category, value) {
      final items = _plats(value);
      if (items.isEmpty) return; // catégorie vide / non communiquée
      cards.add(_categoryCard(category, items));
    });

    if (cards.isEmpty) {
      return [_closedCard('Menu non communiqué')];
    }
    return cards;
  }

  /// Normalise la valeur d'une catégorie (String ou List) en liste de plats,
  /// en écartant les « menu non communiqué ».
  List<String> _plats(dynamic value) {
    if (value == null || value == 'menu non communiqué') return [];
    if (value is String) return [value];
    if (value is List) {
      return value
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty && e != 'menu non communiqué')
          .toList();
    }
    return [];
  }

  Widget _categoryCard(String category, List<String> items) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(category),
                    color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(category,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final plat in items)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text('• $plat', style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
