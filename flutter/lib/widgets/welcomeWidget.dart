import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    return Scaffold(
      body: Center(
        child: const Text(
          'Bienvenue !',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ).animate(onPlay: (controller) => controller.repeat()).tint(color: Colors.green).slide(duration: 500.ms,curve: Curves.easeIn).fadeIn(duration: 500.ms,begin: 0).shake(delay: 1.seconds).fadeOut(duration: 500.ms,delay: 2.seconds),
      ),
    );
  }
}