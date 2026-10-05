import 'package:flutter/material.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';

/// Navigator racine de l'appli : permet de naviguer hors d'un BuildContext
/// (ex. expiration de session détectée par l'intercepteur HTTP).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Remplace TOUTE la pile par [page]. À utiliser pour les transitions d'état
/// de session (connexion, inscription, invité, déconnexion) : un simple
/// `pushReplacement` depuis une page empilée laissait l'écran d'accueil (ou
/// l'appli connectée) sous la nouvelle page, accessible via « retour ».
void resetTo(Widget page, {BuildContext? context}) {
  final navigator =
      context != null ? Navigator.of(context, rootNavigator: true) : navigatorKey.currentState;
  navigator?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => page),
    (_) => false,
  );
}

/// Appli connectée (5 onglets).
void goToHome({BuildContext? context}) =>
    resetTo(const MainScaffold(), context: context);

/// Appli en mode invité (consultation seule).
void goToGuestHome({BuildContext? context}) =>
    resetTo(MainScaffold(destinations: kGuestDestinations), context: context);

/// Écran d'accueil (connexion / inscription / invité).
void goToWelcome({BuildContext? context}) =>
    resetTo(const WelcomeWidget(), context: context);
