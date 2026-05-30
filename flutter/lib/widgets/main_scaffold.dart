import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/widgets/bug_report_action.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: const [BugReportButton()],
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
