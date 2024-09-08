import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/user_provider.dart';
import 'main.dart';
import 'package:flutter_animate/flutter_animate.dart';


class LoginPage extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      
      body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const UserStateWidget(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _usernameController,
            decoration: InputDecoration(labelText: 'Username'),
            
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
              await userProvider.login(
                  _usernameController.text, _passwordController.text);
              if (userProvider.user != null) {
                Navigator.pushReplacementNamed(context, '/home');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Login failed')));
              }
                },
                child: const Text('Login'),
              ).animate().fade(duration: 500.ms).scale(delay:0.6.seconds),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
                final response = await userProvider.register(_usernameController.text, _passwordController.text);
                  if (userProvider.user != null) {
              Navigator.pushReplacementNamed(context, '/home');
                  } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(response ?? 'Registration failed')));
                  }
                },
                child: const Text('Register'),
              ).animate().fade(duration: 500.ms).scale(delay:0.6.seconds),
            ),
          ],
        ),
            ],
        ),
      ),
      ),
    );
  }
}



// class registerButton extends ElevatedButton {
//   registerButton({super.onPressed, super.child});
// }
