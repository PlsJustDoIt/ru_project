import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/home_page.dart';
import 'package:ru_project/providers/user_provider.dart';
class WelcomeWidget extends StatefulWidget {
  @override
  _WelcomeWidgetState createState() => _WelcomeWidgetState();
}

class _WelcomeWidgetState extends State<WelcomeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Text(
            'Welcome!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class WelcomeWidget2 extends StatefulWidget {
  @override
  _WelcomeWidget2State createState() => _WelcomeWidget2State();
}

class _WelcomeWidget2State extends State<WelcomeWidget2>  with SingleTickerProviderStateMixin {

  late AnimationController controller;
  late Animation<double> welcomeFadeanimation;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 20),
        );

    welcomeFadeanimation = Tween<double>(begin: 0, end: 1).animate(controller);

    controller.forward();
  }

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
            const Text(
          'Bienvenue !',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ).animate().fadeIn(duration: 500.ms,begin: 0).tint(color: Colors.green).slide(duration: 500.ms,curve: Curves.easeIn).animate(onPlay: (controller) => controller.repeat()).shake(delay: 1.seconds),
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
              ).animate().fade(duration: 500.ms).scale(delay:0.6.seconds),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () async {
                final response = await userProvider.register(_usernameController.text, _passwordController.text);
                  if (userProvider.user != null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => HomePage()),
                    );
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

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }
}