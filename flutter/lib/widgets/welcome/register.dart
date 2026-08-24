import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/models/user.dart';import 'package:ru_project/providers/restaurant_provider.dart';
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
  RestaurantPartial? _restaurant;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialRestaurantId;
    if (initialId != null) {
      // Mode invité : on ne connaît que l'id ; si le RU est déjà chargé dans
      // le provider on réutilise son nom, sinon l'id sert de placeholder.
      final loaded =
          context.read<RestaurantProvider>().restaurant;
      _restaurant = RestaurantPartial(
        restaurantId: initialId,
        name:
            loaded?.restaurantId == initialId ? loaded!.name : initialId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final restaurant = _restaurant;

    // Étape 2 : identifiants. La closure capture le restaurant choisi.
    if (restaurant != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('S\'inscrire')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(restaurant.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  TextButton(onPressed: () => setState(() => _restaurant = null), child: const Text('Modifier')),
                ],
              ),
            ),
            Expanded(
              child: AuthFormWidget(
                title: 'S\'inscrire',
                buttonText: 'S\'inscrire',
                apiCall: (username, password) => authService.register(
                    username, password,
                    restaurantId: restaurant.restaurantId),
                onSuccess: (response, context) async {
                  final userProvider =
                      Provider.of<UserProvider>(context, listen: false);
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
                    MaterialPageRoute(
                        builder: (context) => const MainScaffold()),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Étape 1 : choix du restaurant.
    return RestaurantPicker(
      title: 'S\'inscrire',
      confirmLabel: 'Suivant',
      onSelected: (pickerContext, selected) async {
        setState(() => _restaurant = selected);
      },
    );
  }
}
