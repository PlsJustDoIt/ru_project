import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/navigation/app_navigation.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/session_manager.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';
import 'package:ru_project/widgets/welcome/register.dart';

/// Page de connexion complète (AppBar + formulaire + lien vers l'inscription).
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.guestRestaurantId});

  /// RU choisi en mode invité : proposé par défaut si l'utilisateur bascule
  /// vers l'inscription.
  final String? guestRestaurantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(child: LoginWidget()),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterWidget(
                        initialRestaurantId: guestRestaurantId),
                  ),
                ),
                child: const Text('Pas encore de compte ? S\'inscrire'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginWidget extends StatelessWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return AuthFormWidget(
      title: 'Se connecter',
      buttonText: 'Se connecter',
      apiCall: authService.login,
      onSuccess: (response, context) async {
        final sessionManager =
            Provider.of<SessionManager>(context, listen: false);
        final User user = response['user'];
        await sessionManager.openSession(user);
        if (!context.mounted) return;
        goToHome(context: context);
      },
    );
  }
}
