import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';

/// Inscription en 2 étapes : 1) choix du restaurant, 2) identifiants.
class RegisterWidget extends StatefulWidget {
  const RegisterWidget({super.key, this.initialRestaurantId});

  /// Pré-sélection (ex: depuis le mode invité).
  final String? initialRestaurantId;

  @override
  State<RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _restaurantId = widget.initialRestaurantId;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Étape 2 : identifiants. La closure capture le restaurantId choisi.
    if (_restaurantId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('S\'inscrire')),
        body: AuthFormWidget(
          title: 'S\'inscrire',
          buttonText: 'S\'inscrire',
          apiCall: (username, password) =>
              authService.register(username, password, restaurantId: _restaurantId),
          onSuccess: (response, context) async {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final restaurantProvider =
              Provider.of<RestaurantProvider>(context, listen: false);
          final secureStorage =
              Provider.of<SecureStorage>(context, listen: false);
          final User user = response['user'];
          userProvider.setUser(user);
          await secureStorage.clearGuestRestaurantId();
          await restaurantProvider.tryLoadRestaurant(user.restaurantId);
          if (!context.mounted) return;
          Provider.of<ChatConnection>(context, listen: false).connect();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScaffold()),
          );
          },
        ),
      );
    }

    // Étape 1 : choix du restaurant.
    return RestaurantPicker(
      title: 'S\'inscrire',
      confirmLabel: 'Suivant',
      onSelected: (pickerContext, restaurantId) async {
        setState(() => _restaurantId = restaurantId);
      },
    );
  }
}
