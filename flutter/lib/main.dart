import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/home_page.dart';
import 'package:ru_project/login_page.dart';
import 'package:ru_project/menu.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/widgets/tabBar.dart';
import 'package:ru_project/widgets/welcome.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  runApp(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  @override 
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      theme: ThemeData(
        colorScheme: const ColorScheme (
          primary: AppColors.primaryColor,
          secondary: Colors.blue,
          surface: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onError: Colors.white,
          brightness: Brightness.light,

        ),
        fontFamily: 'Marianne',
      ),
      home:AuthChecker(),
    );
  }
}


class AuthChecker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Appel de la méthode isConnected via le UserProvider
    bool isConnected = UserProvider().accessToken != null ? true : false;// await UserProvider().isLoggedIn();  // Vérification synchrone

    // Choisir la page selon l'état de connexion
    if (isConnected) {
      return const TabBarWidget();  // Si connecté, aller à l'écran principal
    } else {
      return WelcomeWidget2();  // Sinon, afficher l'écran de connexion
    }
  }
}

