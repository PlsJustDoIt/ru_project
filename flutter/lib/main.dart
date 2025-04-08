import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/tab_bar_widget.dart';
import 'package:ru_project/widgets/welcome.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.init();

  // Instanciation manuelle

  final secureStorage = SecureStorage();
  final userProvider = UserProvider(secureStorage: secureStorage);

  final apiService = ApiService(
    userProvider: userProvider,
    secureStorage: secureStorage,
  );

  // Initialisation de l'état utilisateur
  await userProvider.init(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        Provider<ApiService>.value(value: apiService),
      ],
      child: BetterFeedback(
        theme: FeedbackThemeData(
          feedbackSheetColor: Colors.white,
          background: Colors.green,
          drawColors: [
            Colors.red,
            Colors.green,
            Colors.blue,
            Colors.yellow,
          ],
        ),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalFeedbackLocalizationsDelegate(),
        ],
        localeOverride: const Locale('fr', 'FR'),
        child: const MyApp(),
      ),
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
      themeMode: ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
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
          surfaceContainerHigh:
              Color.fromARGB(255, 196, 201, 202), //TODO a voir si on garde
        ),
        fontFamily: 'Marianne',
      ),
      home: userProvider.isConnected
          ? const TabBarWidget()
          : const WelcomeWidget(),
    );
  }
}
