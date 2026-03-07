
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';

class LoginWidget extends StatelessWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    return AuthFormWidget(
      title: 'Se connecter',
      buttonText: 'Se connecter',
      apiCall: apiService.login,
      onSuccess: (response, context) async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final User user = response['user'];
        userProvider.setUser(user);
        List<User> fetchedFriends = await apiService.getFriends();
        userProvider.setFriends(fetchedFriends);
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TabBarWidget(),
          ),
        );
      },
    );
  }
}