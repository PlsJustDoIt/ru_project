import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/models/menu.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/restaurant_service.dart';

/// Pont entre l'app et le widget Android « Menu du RU » épinglable sur
/// l'écran d'accueil (`android/.../MenuWidgetProvider.kt`).
///
/// L'app pousse dans les SharedPreferences de `home_widget` :
/// - l'URL de l'API et l'id CROUS du RU sélectionné (le widget s'en sert pour
///   se rafraîchir seul, l'endpoint `/ru/menus` étant public) ;
/// - le nom du RU (titre du widget) ;
/// - les menus déjà chargés, au format brut du backend, pour un affichage
///   immédiat sans attendre le réseau.
///
/// Toutes les valeurs sont des String : le code natif les relit telles quelles.
class MenuHomeWidget {
  MenuHomeWidget._();

  /// Nom de classe qualifié du AppWidgetProvider natif.
  static const String qualifiedAndroidName =
      'fr.pleasejustdoit.ru_project.MenuWidgetProvider';

  // Clés partagées avec MenuWidgetData.kt — à garder synchronisées.
  static const String keyApiUrl = 'menu_api_url';
  static const String keyRestaurantId = 'menu_restaurant_id';
  static const String keyRestaurantName = 'menu_restaurant_name';
  static const String keyMenusJson = 'menu_json';
  static const String keyStatus = 'menu_status';
  static const String keyFetchedAt = 'menu_fetched_at';

  /// Le widget n'existe que sur Android.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Synchronise le widget avec le RU courant du [provider], maintenant puis à
  /// chaque changement de RU (réglages, onboarding invité...).
  static void attach(RestaurantProvider provider, RestaurantService service) {
    if (!isSupported) return;
    String? lastSyncedId;

    Future<void> sync() async {
      final restaurant = provider.restaurant;
      if (restaurant == null || restaurant.restaurantId == lastSyncedId) {
        return;
      }
      lastSyncedId = restaurant.restaurantId;
      final menus =
          await service.getMenus(restaurantId: restaurant.restaurantId);
      await save(
        restaurantId: restaurant.restaurantId,
        restaurantName: restaurant.name,
        menus: menus,
      );
    }

    provider.addListener(sync);
    sync();
  }

  /// Écrit les données du widget puis demande son redessin.
  ///
  /// [menus] == null signifie que le RU ne publie pas de menu (404 backend).
  /// Une liste vide (erreur réseau) n'écrase pas un cache existant pour le
  /// même RU : le widget garde l'ancien et se rafraîchira seul.
  static Future<void> save({
    required String restaurantId,
    required String restaurantName,
    required List<Menu>? menus,
  }) async {
    if (!isSupported) return;
    try {
      final previousId = await HomeWidget.getWidgetData<String>(keyRestaurantId);
      final sameRestaurant = previousId == restaurantId;

      await HomeWidget.saveWidgetData<String>(keyApiUrl, Config.apiUrl);
      await HomeWidget.saveWidgetData<String>(keyRestaurantId, restaurantId);
      await HomeWidget.saveWidgetData<String>(keyRestaurantName, restaurantName);

      if (menus == null) {
        await HomeWidget.saveWidgetData<String>(keyStatus, 'none');
        await HomeWidget.saveWidgetData<String>(keyMenusJson, '[]');
        await _markFetched();
      } else if (menus.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>(keyStatus, 'ok');
        await HomeWidget.saveWidgetData<String>(
            keyMenusJson, jsonEncode(menus.map(_toRawJson).toList()));
        await _markFetched();
      } else if (!sameRestaurant) {
        // Nouveau RU mais pas de données : on vide l'ancien cache et on force
        // le widget à retenter le réseau (fetched_at = 0).
        await HomeWidget.saveWidgetData<String>(keyStatus, 'ok');
        await HomeWidget.saveWidgetData<String>(keyMenusJson, '[]');
        await HomeWidget.saveWidgetData<String>(keyFetchedAt, '0');
      }

      await HomeWidget.updateWidget(qualifiedAndroidName: qualifiedAndroidName);
    } catch (e) {
      // Jamais bloquant pour l'app (plugin absent, aucun widget posé...).
      logger.w('MenuHomeWidget.save: $e');
    }
  }

  static Future<void> _markFetched() => HomeWidget.saveWidgetData<String>(
      keyFetchedAt, DateTime.now().millisecondsSinceEpoch.toString());

  /// Remet un [Menu] au format brut renvoyé par `GET /ru/menus`
  /// (`{date, fermeture}` ou `{date, <catégorie>: String|List}`), le seul que
  /// le parseur natif connaît.
  static Map<String, dynamic> _toRawJson(Menu menu) {
    if (menu.isClosed()) {
      return {'date': menu.date, 'fermeture': menu.fermeture};
    }
    return {'date': menu.date, ...?menu.plats};
  }

  /// Le lanceur sait-il épingler un widget depuis l'app (Android 8+) ?
  static Future<bool> canRequestPin() async {
    if (!isSupported) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ouvre la boîte de dialogue système « Ajouter à l'écran d'accueil ».
  static Future<void> requestPin() async {
    if (!isSupported) return;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: qualifiedAndroidName);
  }
}
