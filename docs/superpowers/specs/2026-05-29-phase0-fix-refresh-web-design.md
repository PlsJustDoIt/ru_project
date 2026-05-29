# Phase 0 — Bug « F5 sur web déconnecte » — Design

**Date :** 2026-05-29
**Type :** correctif borné (bloquant de lancement)
**Branche :** `fix/phase0-refresh-web`
**Statut :** design validé — à décomposer en plan d'implémentation

> Chantier issu de la feuille de route `2026-05-29-roadmap-ameliorations-appli-ru-design.md` (Phase 0).

---

## Problème

Sur la version web, un rafraîchissement (F5) renvoie l'utilisateur à l'écran d'accueil, alors que sa session est valide.

## Diagnostic (confirmé par observation live sur prod web + lecture du code)

La déconnexion **n'est pas un problème d'authentification**. Les tokens survivent au F5 (présents dans `localStorage`) et `GET /users/me` répond `200`. La déconnexion vient du **couplage** entre la restauration de session et le chargement de données annexes dans `UserProvider.init()`.

Chaîne de cause :

1. Le modèle Mongoose `User` a un champ **`restaurant`** (`ObjectId`, ref `Restaurant`, **optionnel**). `/users/me` le sérialise ainsi : `restaurantId: user.restaurant?.toString()` (`user.controller.ts:33`). Pour un utilisateur **sans `restaurant` assigné**, la valeur vaut `undefined` → la clé est **omise du JSON** → côté Flutter `json['restaurantId']` est `null`.
2. Le modèle Flutter fabrique alors une valeur en dur :
   ```dart
   // flutter/lib/models/user.dart:24
   restaurantId: json['restaurantId'] ?? 'r135', // todo eviter confusion
   ```
3. `UserProvider.init()` appelle `restaurantProvider.loadRestaurant('r135')` → `GET /ru/r135`.
   - `r135` n'est pas un `ObjectId` valide → le backend à jour répond `400 Invalid restaurant ID format` ; la **prod (périmée)** ne connaît pas la route et répond `404 « Cannot GET /api/ru/r135 »`.
4. `getRestaurantById` renvoie `null` → `loadRestaurant` lève `Exception("Restaurant not found")`.
5. Le `catch` générique de `init()` exécute `clearUserData()` → `_isConnected = false` → l'app affiche `WelcomeWidget`.

Code fautif (`flutter/lib/providers/user_provider.dart`) :

```dart
Future<void> init(UserService userService, FriendService friendService,
    RestaurantProvider restaurantProvider) async {
  final accessToken = await secureStorage.getAccessToken();
  if (accessToken != null) {
    try {
      final user = await userService.getUser();        // OK (200)
      if (user == null) { clearUserData(); return; }
      final friends = await friendService.getFriends();          // peut throw (rethrow)
      await restaurantProvider.loadRestaurant(user.restaurantId); // throw « Restaurant not found »
      _user = user;
      _friends = friends;
      _isConnected = true;                              // jamais atteint si throw au-dessus
    } catch (_) {
      clearUserData();                                  // ← déconnexion à tort
    }
  }
  notifyListeners();
}
```

`_isConnected = true` n'est positionné qu'**après** `getFriends()` et `loadRestaurant()`. Tout échec de l'un de ces deux appels (donnée manquante, blip réseau) déconnecte une session pourtant valide.

## Invariant à rétablir

> Une auth valide (token présent + `getUser()` qui réussit) ne doit **jamais** être déconnectée parce qu'une donnée annexe (restaurant, amis) n'a pas pu charger.

## Solution retenue (approche 1)

Découpler la restauration de session du chargement des données annexes, et arrêter de fabriquer un `restaurantId` bidon.

### Changements

1. **`UserProvider.init()` résilient** (`flutter/lib/providers/user_provider.dart`)
   - Dès que `getUser()` renvoie un user non-null : `_user = user; _isConnected = true;`.
   - `getFriends()` et `loadRestaurant()` deviennent *best-effort* : chacun dans son propre `try/catch` qui **logge** l'erreur sans toucher à l'état de connexion.
   - On garde la sortie « non connecté » uniquement quand il n'y a pas de token, ou que `getUser()` renvoie `null`/échoue (vraie invalidité de session).

2. **`restaurantId` nullable** (`flutter/lib/models/user.dart`)
   - Supprimer le défaut `?? 'r135'`. `restaurantId` devient `String?` (ou `''` traité comme absent — voir « Décision » ci-dessous).
   - Répercuter sur le constructeur, `fromJson`, `toJson`, `toString`.
   - `init()` n'appelle `loadRestaurant` que si `restaurantId` est non-vide ; sinon on saute proprement (et best-effort de toute façon).

3. **Tests** (`flutter/test/`)
   - `UserProvider.init()` : (a) token absent → non connecté ; (b) `getUser` null → non connecté ; (c) `getUser` OK mais `loadRestaurant` throw → **connecté** (régression du bug) ; (d) `getUser` OK mais `getFriends` throw → **connecté** ; (e) cas nominal → connecté + amis + resto chargés.
   - `User.fromJson` sans `restaurantId` → champ nul/vide, **pas** `'r135'`.
   - Doublures de `UserService`/`FriendService`/`RestaurantProvider` (fakes ou mocks) pour piloter succès/échec sans réseau.

### Découpage en unités

- `UserProvider.init` reste le point d'entrée ; sa responsabilité se réduit à « restaurer la session » + déclencher les chargements annexes en best-effort.
- Le modèle `User` voit sa seule responsabilité de désérialisation corrigée (plus de valeur fabriquée).

## Hors périmètre (noté, pas traité ici)

- **Redéploiement de la prod** (backend périmé → « Cannot GET /api/ru/:id ») : action **ops**, pas un changement de code. À faire avant lancement.
- **Rattachement des users à un RU** (champ `restaurant` du modèle `User`, souvent vide) : décision de données/feature (les users doivent-ils être rattachés à un RU par défaut ?). Relève d'un chantier ultérieur (Phase 3/4), pas du correctif borné. Le correctif ici rend simplement l'absence de restaurant non-fatale.
- Réécriture de la gestion d'erreurs Dio / `secure_storage` `WebOptions` : non nécessaire, le diagnostic a écarté la persistance des tokens.

## Décision ouverte (à trancher dans le plan)

- `restaurantId` : `String?` (nullable) **ou** `String` défaut `''` ? Recommandation : `String?` nullable, c'est le plus explicite ; le garde `if (restaurantId != null && restaurantId.isNotEmpty)` avant `loadRestaurant`. À confirmer selon l'usage de `restaurantId` ailleurs dans le code (carte/secteurs).

## Critères de succès

- F5 sur web avec session valide → l'utilisateur **reste connecté**, même si `/ru/:id` ou `/users/friends` échoue.
- Aucune régression : login/logout/refresh inchangés ; cas nominal charge bien amis + resto.
- `flutter analyze` propre, suite `flutter test` verte (tests existants Phase 1 + nouveaux).
