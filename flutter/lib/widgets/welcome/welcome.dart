import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/custom_snack_bar.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';
import 'package:ru_project/widgets/welcome/login.dart';
import 'package:ru_project/widgets/welcome/register.dart';

class WelcomeWidget extends StatefulWidget {
  const WelcomeWidget({super.key});

  @override
  State<WelcomeWidget> createState() => _WelcomeWidget2State();
}

class _WelcomeWidget2State extends State<WelcomeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> welcomeFadeanimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    welcomeFadeanimation = Tween<double>(begin: 0, end: 1).animate(controller);

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: 'Projet RU'.split('').asMap().entries.map((entry) {
                        final index = entry.key;
                        final letter = entry.value;
                        return Text(
                          letter,
                          style: const TextStyle(
                            fontSize: 40,
                            fontFamily: 'Marianne',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 300.ms, delay: (index * 100).ms);
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bienvenue !',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              final apiService = Provider.of<ApiService>(context, listen: false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    appBar: AppBar(title: const Text('Connexion')),
                                    body: LoginWidget(),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Se connecter'),
                          )
                              .animate()
                              .fade(duration: 500.ms)
                              .scale(delay: 0.6.seconds),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () {
                              final apiService = Provider.of<ApiService>(context, listen: false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    appBar: AppBar(title: const Text('Inscription')),
                                    body: RegisterWidget(),
                                  ),
                                ),
                              );
                            },
                            child: const Text('S\'inscrire'),
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
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
