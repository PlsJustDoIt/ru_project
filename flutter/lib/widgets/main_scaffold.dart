import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/bug_report_action.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';

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

  @override
  void initState() {
    super.initState();
    final notifications =
        Provider.of<NotificationProvider>(context, listen: false);
    notifications.currentUsername =
        Provider.of<UserProvider>(context, listen: false).user?.username;
    _bannerSub = notifications.banners.listen(_showBanner);
  }

  void _showBanner(MessageNotified event) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${event.message.sender} t\'a écrit'),
        duration: const Duration(seconds: 3),
      ));
  }

  void _changeGuestRestaurant(BuildContext context) {
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
          onSelected: (pickerContext, restaurantId) async {
            await secureStorage.storeGuestRestaurantId(restaurantId);
            await restaurantProvider.tryLoadRestaurant(restaurantId);
            if (!pickerContext.mounted) return;
            Navigator.pop(pickerContext);
            setState(() {}); // rebuild de l'onglet courant
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

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations ?? kMainDestinations;
    final current = destinations[_index];
    final totalUnread = context.watch<NotificationProvider>().totalUnread;
    final isGuest = context.watch<UserProvider>().isGuest;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
          if (isGuest)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) {
                if (value == 'login') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeWidget()),
                  );
                } else if (value == 'change_ru') {
                  _changeGuestRestaurant(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'login', child: Text('Se connecter')),
                PopupMenuItem(value: 'change_ru', child: Text('Changer de RU')),
              ],
            ),
          const BugReportButton(),
        ],
      ),
      body: current.builder(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: d.label == 'Messages' && totalUnread > 0
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
