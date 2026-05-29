import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/models/sector.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/restaurant_service.dart';

class RestaurantProvider extends ChangeNotifier {
  final RestaurantService restaurantService;
  RestaurantTmp? _restaurant;
  Timer? _sectorTimer;
  String? _mySectorId; // sector id where current user is sitting

  RestaurantProvider(this.restaurantService);

  RestaurantTmp? get restaurant => _restaurant;

  /// Charge un restaurant avec ses secteurs
  Future<void> loadRestaurant(String restaurantId) async {
    _restaurant = await restaurantService.getRestaurantById(restaurantId);

    if (_restaurant == null) {
      throw Exception("Restaurant not found");
    }
    _restaurant!.sectors =
        await restaurantService.getRestaurantsSectors(idResto: restaurantId);
    // Restore my personal occupancy flag after reload
    if (_mySectorId != null) {
      try {
        final mine =
            _restaurant!.sectors?.firstWhere((s) => s.id == _mySectorId);
        if (mine != null) mine.occupiedByMe = true;
      } catch (_) {}
    }
    logger.d('Sectors: ${_restaurant!.sectors}');
    notifyListeners();
  }

  /// Charge le restaurant en best-effort : ne fait rien si [restaurantId] est
  /// nul/vide, et n'a jamais d'effet bloquant (erreurs loggées, pas propagées).
  /// Utilisé pendant la restauration de session et le login pour qu'un échec de
  /// chargement ne déconnecte pas un utilisateur authentifié.
  Future<void> tryLoadRestaurant(String? restaurantId) async {
    if (restaurantId == null || restaurantId.isEmpty) {
      return;
    }
    try {
      await loadRestaurant(restaurantId);
    } catch (e) {
      logger.e('tryLoadRestaurant: chargement du restaurant échoué (non bloquant): $e');
    }
  }

  /// Récupère les users dans un secteur et met à jour l’état
  Future<void> fetchUsersInSector(String sectorId) async {
    if (_restaurant == null) return;

    final sector = _restaurant!.sectors?.firstWhere(
      (s) => s.id == sectorId,
      orElse: () => throw Exception("Sector not found"),
    );

    if (sector != null) {
      final friends = await restaurantService.getFriendsInSector(sectorId);
      // occupied représente ici: ami présent
      sector.occupied = friends.isNotEmpty;
      notifyListeners();

      // reset auto géré seulement pour occupiedByMe
    }
  }

  /// Met à jour l'état d'occupation d'un secteur et notifie l'UI
  void setSectorOccupied(Sector sector, bool occupied) {
    sector.occupied = occupied;
    notifyListeners();
    // friends occupancy has no auto reset here
  }

  /// Marque le secteur comme occupé par MOI (orange)
  void setSectorOccupiedByMe(Sector sector, bool byMe, {Duration? duration}) {
    sector.occupiedByMe = byMe;
    _mySectorId = byMe ? sector.id : null;
    notifyListeners();
    if (byMe) {
      startSectorAutoReset(sector, duration: duration);
    }
  }

  /// Lance un timer pour réinitialiser `occupied`
  void startSectorAutoReset(Sector sector, {Duration? duration}) {
    logger.d('Starting auto-reset timer for sector: ${sector.id}');
    // Annule tout timer précédent
    _sectorTimer?.cancel();

    // Utilise la durée fournie (minutes sélectionnées) sinon fallback
    final expiresIn = duration ?? const Duration(minutes: 30);
    _sectorTimer = Timer(expiresIn, () {
      sector.occupiedByMe = false;
      if (_mySectorId == sector.id) _mySectorId = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sectorTimer?.cancel();
    super.dispose();
  }
}
