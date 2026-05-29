import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final destinations = widget.destinations ?? kMainDestinations;
    final current = destinations[_index];

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
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
