import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/widgets/bug_report_action.dart';
import 'package:ru_project/widgets/bus_widget.dart';
import 'package:ru_project/widgets/debug_widget.dart';
import 'package:ru_project/widgets/profile.dart';
import 'package:ru_project/widgets/settings_widget.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';

class MoreWidget extends StatelessWidget {
  const MoreWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profil'),
          onTap: () => _openPage(context, 'Profil', ProfileWidget()),
        ),
        ListTile(
          leading: const Icon(Icons.directions_bus_outlined),
          title: const Text('Bus'),
          onTap: () =>
              _openPage(context, 'Bus', const TransportTimeWidget()),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Réglages'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsWidget()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Signaler un bug'),
          onTap: () => showBugReport(context),
        ),
        if (Config.env == 'development')
          ListTile(
            leading: const Icon(Icons.developer_mode),
            title: const Text('Debug'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugWidget()),
            ),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.accent),
          title: const Text('Déconnexion'),
          onTap: () => _logout(context),
        ),
      ],
    );
  }

  /// Ouvre une sous-page qui ne porte pas son propre Scaffold (Profil, Bus) :
  /// on lui fournit une AppBar (donc un bouton retour) et un fond opaque.
  void _openPage(BuildContext context, String title, Widget child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: const [BugReportButton()],
          ),
          body: child,
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await authService.logout();
    userProvider.clearUserData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Déconnexion réussie')),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeWidget()),
    );
  }
}
