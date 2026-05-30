
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';

class RegisterWidget extends StatelessWidget {
  const RegisterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return AuthFormWidget(
      title: 'S\'inscrire',
      buttonText: 'S\'inscrire',
      apiCall: authService.register,
      onSuccess: (response, context) async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final restaurantProvider =
            Provider.of<RestaurantProvider>(context, listen: false);
        final User user = response['user'];
        userProvider.setUser(user);
        await restaurantProvider.tryLoadRestaurant(user.restaurantId);
        if (!context.mounted) return;
        Provider.of<ChatConnection>(context, listen: false).connect();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScaffold(),
          ),
        );
      },
    );
  }
}
