import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/welcome.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => UserProvider(),
        ),
        Provider(
            create: (context) => ApiService(
                  userProvider:
                      Provider.of<UserProvider>(context, listen: false),
                  secureStorage: SecureStorage(),
                )),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    UserProvider userProvider =
        Provider.of<UserProvider>(context, listen: false);

    return MaterialApp(
      navigatorKey: navigatorKey,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('fr', 'FR'),
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
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
      home: userProvider.isConnected
          ? const TabBarWidget()
          : const WelcomeWidget(),
    );
  }
}
