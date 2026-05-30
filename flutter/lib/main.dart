import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/feedback_service.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/ginko_service.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/services/user_service.dart';
import 'package:ru_project/theme/app_theme.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.init();

  // Instanciation manuelle
  final secureStorage = SecureStorage();
  final userProvider = UserProvider(secureStorage: secureStorage);

  final apiClient = ApiClient(
    userProvider: userProvider,
    secureStorage: secureStorage,
  );

  final userService = UserService(dio: apiClient.dio);
  final friendService = FriendService(dio: apiClient.dio);
  final authService = AuthService(
      dio: apiClient.dio,
      secureStorage: secureStorage,
      userService: userService);
  final restaurantService = RestaurantService(dio: apiClient.dio);
  final socketService = SocketService(dio: apiClient.dio);
  final chatConnection =
      ChatConnection(tokenProvider: secureStorage.getAccessToken);
  final notificationProvider = NotificationProvider(chatConnection);
  final ginkoService = GinkoService(dio: apiClient.dio);
  final feedbackService = FeedbackService(dio: apiClient.dio);

  final restaurantProvider = RestaurantProvider(restaurantService);

  // Initialisation de l'état utilisateur
  await userProvider.init(userService, friendService, restaurantProvider);

  if (userProvider.isConnected) {
    await chatConnection.connect();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        Provider<AuthService>.value(value: authService),
        Provider<UserService>.value(value: userService),
        Provider<FriendService>.value(value: friendService),
        Provider<RestaurantService>.value(value: restaurantService),
        Provider<SocketService>.value(value: socketService),
        ChangeNotifierProvider<ChatConnection>.value(value: chatConnection),
        ChangeNotifierProvider<NotificationProvider>.value(
            value: notificationProvider),
        Provider<GinkoService>.value(value: ginkoService),
        Provider<FeedbackService>.value(value: feedbackService),
        Provider<SecureStorage>.value(value: secureStorage),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<RestaurantProvider>.value(
            value: restaurantProvider),
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
      theme: buildAppTheme(),
      home: userProvider.isConnected
          ? const MainScaffold()
          : userProvider.isGuest
              ? MainScaffold(destinations: kGuestDestinations)
              : const WelcomeWidget(),
    );
  }
}
