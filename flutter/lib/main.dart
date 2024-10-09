import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
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

    FlutterSecureStorage storage = FlutterSecureStorage();
    UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.loadTokens();
    
    storage.read(key: 'accessToken').then((accessToken) {
          
        });
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
      home:FutureBuilder(future: storage.read(key: 'accessToken'), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        storage.read(key: 'accessToken').then((accessToken) {
          
        });

        
        if (snapshot.data != null) {
          return const TabBarWidget();
        } else {
          return  WelcomeWidget2();
        }
      } else {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
    }),
    );
  }
}


class AuthChecker extends StatelessWidget {
  @override
  Widget  build(BuildContext context) {
    // Appel de la méthode isConnected via le UserProvider
    // bool isConnected = await UserProvider().isConnected();// await UserProvider().isLoggedIn();  // Vérification synchrone
    // 
    // // Choisir la page selon l'état de connexion
    // if (isConnected) {
    //   return const TabBarWidget();  // Si connecté, aller à l'écran principal
    // } else {
    //   return WelcomeWidget2();  // Sinon, afficher l'écran de connexion
    // }
    return FutureBuilder(future: UserProvider().isConnected(), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {

        
        if (snapshot.data == true) {
          return const TabBarWidget();
        } else {
          return  WelcomeWidget2();
        }
      } else {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
    });
  }
}

