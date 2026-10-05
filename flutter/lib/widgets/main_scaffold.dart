import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/navigation/app_navigation.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/session_manager.dart';
import 'package:ru_project/widgets/bug_report_action.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/login.dart';
import 'package:ru_project/widgets/welcome/register.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';

/// Libellé de l'onglet de messagerie (badge de non-lus, bandeau « Voir »).
const String kMessagesTabLabel = 'Messages';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key, this.destinations});

  /// Injectable pour les tests ; par défaut [kMainDestinations].
  final List<MainDestination>? destinations;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  StreamSubscription<MessageNotified>? _bannerSub;
  bool _guestBannerDismissed = false;

  List<MainDestination> get _destinations =>
      widget.destinations ?? kMainDestinations;

  @override
  void initState() {
    super.initState();
    final notifications = context.read<NotificationProvider?>();
    _bannerSub = notifications?.banners.listen(_showBanner);
  }

  void _showBanner(MessageNotified event) {
    if (!mounted) return;
    final messagesIndex =
        _destinations.indexWhere((d) => d.label == kMessagesTabLabel);
    final isGlobal = event.roomName == 'Global';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(isGlobal
            ? '${event.message.sender} a écrit dans Global'
            : '${event.message.sender} t\'a écrit'),
        duration: const Duration(seconds: 3),
        action: messagesIndex == -1 || messagesIndex == _index
            ? null
            : SnackBarAction(
                label: 'Voir',
                onPressed: () {
                  if (mounted) setState(() => _index = messagesIndex);
                },
              ),
      ));
  }

  String? get _guestRestaurantId =>
      context.read<RestaurantProvider>().restaurant?.restaurantId;

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(guestRestaurantId: _guestRestaurantId),
      ),
    );
  }

  void _openRegister() {
    // Le RU déjà choisi en invité est repris : pas besoin de le resélectionner.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterWidget(initialRestaurantId: _guestRestaurantId),
      ),
    );
  }

  Future<void> _leaveGuestMode() async {
    await context.read<SessionManager>().leaveGuestMode();
    if (!mounted) return;
    goToWelcome(context: context);
  }

  void _changeGuestRestaurant() {
    final secureStorage = Provider.of<SecureStorage>(context, listen: false);
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantPicker(
          title: 'Changer de RU',
          confirmLabel: 'Valider',
          initialRestaurantId: restaurantProvider.restaurant?.restaurantId,
          onSelected: (pickerContext, restaurant) async {
            await secureStorage.storeGuestRestaurantId(restaurant.restaurantId);
            await restaurantProvider.tryLoadRestaurant(restaurant.restaurantId);
            if (!pickerContext.mounted) return;
            Navigator.pop(pickerContext);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerSub?.cancel();
    super.dispose();
  }

  Widget _guestMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Compte',
      onSelected: (value) {
        switch (value) {
          case 'login':
            _openLogin();
          case 'register':
            _openRegister();
          case 'change_ru':
            _changeGuestRestaurant();
          case 'leave':
            _leaveGuestMode();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'login', child: Text('Se connecter')),
        PopupMenuItem(value: 'register', child: Text('Créer un compte')),
        PopupMenuItem(value: 'change_ru', child: Text('Changer de RU')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'leave', child: Text('Quitter le mode invité')),
      ],
    );
  }

  /// Rappel discret des fonctions réservées aux comptes (masquable).
  Widget _guestBanner() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Mode invité : crée un compte pour le chat et retrouver tes amis au RU.',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: _openRegister,
              child: const Text('Créer'),
            ),
            IconButton(
              tooltip: 'Masquer',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _guestBannerDismissed = true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    if (_index >= destinations.length) _index = 0;
    final current = destinations[_index];
    final totalUnread =
        context.watch<NotificationProvider?>()?.totalUnread ?? 0;
    final isGuest = context.watch<UserProvider?>()?.isGuest ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
          if (isGuest) _guestMenu(),
          const BugReportButton(),
        ],
      ),
      body: Column(
        children: [
          if (isGuest && !_guestBannerDismissed) _guestBanner(),
          Expanded(child: current.builder(context)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: d.label == kMessagesTabLabel && totalUnread > 0
                  ? Badge(
                      label: Text('$totalUnread'),
                      child: Icon(d.icon),
                    )
                  : Icon(d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
