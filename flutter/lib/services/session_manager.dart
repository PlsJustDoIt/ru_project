import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';

/// Point unique pour fermer une session : avant, chaque écran (Plus, Profil,
/// intercepteur HTTP) faisait sa propre déconnexion partielle — les tokens
/// restaient en stockage (reconnexion automatique au redémarrage), la socket
/// de chat restait ouverte et les non-lus survivaient.
class SessionManager {
  SessionManager({
    required this.authService,
    required this.secureStorage,
    required this.userProvider,
    required this.chatConnection,
    required this.notificationProvider,
    required this.friendService,
    required this.restaurantProvider,
  });

  final AuthService authService;
  final SecureStorage secureStorage;
  final UserProvider userProvider;
  final ChatConnection chatConnection;
  final NotificationProvider notificationProvider;
  final FriendService friendService;
  final RestaurantProvider restaurantProvider;

  bool _closing = false;

  /// Ouvre la session de [user] après login / inscription (tokens déjà
  /// stockés par [AuthService]). Les chargements annexes sont best-effort :
  /// un échec ne doit pas bloquer l'entrée dans l'appli.
  Future<void> openSession(User user) async {
    userProvider.setUser(user);
    notificationProvider.reset();
    try {
      await secureStorage.clearGuestRestaurantId();
    } catch (e) {
      logger.e('SessionManager: effacement du RU invité échoué: $e');
    }
    await restaurantProvider.tryLoadRestaurant(user.restaurantId);
    try {
      userProvider.setFriends(await friendService.getFriends());
    } catch (e) {
      logger.e('SessionManager: chargement des amis échoué: $e');
    }
    await chatConnection.connect();
  }

  /// Déconnexion volontaire : révoque le refresh token côté serveur (best
  /// effort) puis nettoie tout l'état local.
  Future<void> logout() async {
    await authService.logout();
    await clearLocalSession();
  }

  /// Nettoie l'état local sans appeler le serveur (session expirée, compte
  /// supprimé). Idempotent : plusieurs requêtes en échec simultanées ne
  /// déclenchent qu'un seul nettoyage.
  Future<void> clearLocalSession() async {
    if (_closing) return;
    _closing = true;
    try {
      await secureStorage.clearTokens();
      await secureStorage.clearGuestRestaurantId();
    } catch (e) {
      logger.e('SessionManager: nettoyage du stockage échoué: $e');
    }
    chatConnection.disconnect();
    notificationProvider.reset();
    userProvider.clearUserData();
    _closing = false;
  }

  /// Quitte le mode invité (retour à l'accueil sans RU mémorisé).
  Future<void> leaveGuestMode() => clearLocalSession();
}
