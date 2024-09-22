import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/home_page.dart';
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
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: TextField(
              //     controller: _usernameController,
              //     decoration: InputDecoration(labelText: 'Username'),

              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: TextField(
              //     controller: _passwordController,
              //     decoration: InputDecoration(labelText: 'Password'),
              //     obscureText: true,
              //   ),
              // ),
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
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => HomePage()),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Login failed')));
                        }
                      },
                      child: const Text('Login'),
                    )
                        .animate()
                        .fade(duration: 500.ms)
                        .scale(delay: 0.6.seconds),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        final response = await userProvider.register(
                            _usernameController.text, _passwordController.text);
                        if (userProvider.user != null) {
                          Navigator.pushReplacementNamed(context, '/home');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content:
                                  Text(response ?? 'Registration failed')));
                        }
                      },
                      child: const Text('Register'),
                    )
                        .animate()
                        .fade(duration: 500.ms)
                        .scale(delay: 0.6.seconds),
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

class UserStateWidget extends StatefulWidget {
  const UserStateWidget({super.key});

  @override
  _UserStateWidgetState createState() => _UserStateWidgetState();
}

class _UserStateWidgetState extends State<UserStateWidget> {
  String _currentState = "Inactif"; // État par défaut

  void _changeState(String newState) {
    setState(() {
      _currentState = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text(
          //   'État actuel : $_currentState',
          //   style: const TextStyle(
          //     fontSize: 24,
          //     color: Colors.green,
          //   ),
          // ),
          // const SizedBox(height: 20), // Espacement
          //   Column(
          //   children: [
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("Inactif"),
          //       child: const Text('Inactif'),
          //     ),
          //     ),
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("Sur le point de manger"),
          //       child: const Text('Sur le point de manger'),
          //     ),
          //     ),
          //     Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: ElevatedButton(
          //       onPressed: () => _changeState("A fini de manger"),
          //       child: const Text('A fini de manger'),
          //     ),
          //     ),
          //   ],
          //   ),

          const Text(
            'Bienvenue !',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          )
              .animate()
              .tint(color: Colors.green)
              .slide(duration: 500.ms, curve: Curves.easeIn)
              .fadeIn(duration: 500.ms, begin: 0)
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(duration: 500.ms, begin: 0)
              .shake(delay: 1.seconds)
              .fadeOut(duration: 500.ms, delay: 2.seconds),
          Image.asset(
            "assets/images/jm.jpg",
            width: 200,
            height: 200,
          ),
        ],
      ),
    );
  }
}
