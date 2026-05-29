# Phase 0 — Fix « F5 sur web déconnecte » — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Une auth valide ne doit jamais être déconnectée parce qu'une donnée annexe (restaurant, amis) n'a pas pu charger — corrige le retour à l'accueil au F5 sur web.

**Architecture :** On découple la restauration de session du chargement des données annexes dans `UserProvider.init()` (`_isConnected = true` dès que `getUser()` réussit ; amis + restaurant en *best-effort*). On ajoute un helper `RestaurantProvider.tryLoadRestaurant(String?)` réutilisé par `init`, `login` et `register`. On supprime la valeur fabriquée `restaurantId ?? 'r135'` (→ `restaurantId` nullable).

**Tech Stack :** Flutter 3.35, Provider, `flutter_test`. Pas de mockito/mocktail dans le projet → doublures de test écrites à la main (`extends`/`implements`).

> Branche : `fix/phase0-refresh-web` (déjà créée). Toutes les commandes `flutter` se lancent depuis `flutter/` (`cd flutter`).
> Spec de référence : `docs/superpowers/specs/2026-05-29-phase0-fix-refresh-web-design.md`.

## Structure de fichiers

- **Modifier** `flutter/lib/providers/restaurant_provider.dart` — ajouter `tryLoadRestaurant(String?)` (best-effort, garde le null/vide, avale les erreurs).
- **Modifier** `flutter/lib/providers/user_provider.dart` — `init()` résilient (+ import `logger`).
- **Modifier** `flutter/lib/models/user.dart` — `restaurantId` nullable, plus de défaut `'r135'`.
- **Modifier** `flutter/lib/widgets/welcome/login.dart` & `register.dart` — appeler `tryLoadRestaurant`.
- **Tests** : `flutter/test/restaurant_provider_test.dart`, `flutter/test/user_provider_init_test.dart`, `flutter/test/user_model_test.dart`.

> Ordre choisi pour garder le build vert à chaque tâche : (1) ajout additif du helper, (2) `init` résilient (le modèle est encore non-null, `String` se passe à un `String?`), (3) passage du modèle en nullable + bascule des 2 derniers appelants.

---

### Task 1 : `RestaurantProvider.tryLoadRestaurant` (best-effort)

Helper additif : ne change aucun comportement existant.

**Files:**
- Modify: `flutter/lib/providers/restaurant_provider.dart`
- Test: `flutter/test/restaurant_provider_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `flutter/test/restaurant_provider_test.dart` :
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/services/restaurant_service.dart';

class _FakeRestaurantProvider extends RestaurantProvider {
  _FakeRestaurantProvider() : super(RestaurantService(dio: Dio()));

  bool shouldThrow = false;
  int loadCalls = 0;
  String? lastId;

  @override
  Future<void> loadRestaurant(String restaurantId) async {
    loadCalls++;
    lastId = restaurantId;
    if (shouldThrow) {
      throw Exception('boom');
    }
  }
}

void main() {
  test('tryLoadRestaurant ne charge rien si id null', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant(null);
    expect(p.loadCalls, 0);
  });

  test('tryLoadRestaurant ne charge rien si id vide', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant('');
    expect(p.loadCalls, 0);
  });

  test('tryLoadRestaurant charge si id renseigné', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant('abc');
    expect(p.loadCalls, 1);
    expect(p.lastId, 'abc');
  });

  test('tryLoadRestaurant avale les erreurs (ne propage pas)', () async {
    final p = _FakeRestaurantProvider()..shouldThrow = true;
    await p.tryLoadRestaurant('abc'); // ne doit pas lever
    expect(p.loadCalls, 1);
  });
}
```

- [ ] **Step 2 : Lancer le test → échec**

Run: `cd flutter && flutter test test/restaurant_provider_test.dart`
Expected: FAIL (`tryLoadRestaurant` n'existe pas → erreur de compilation).

- [ ] **Step 3 : Ajouter le helper**

Dans `flutter/lib/providers/restaurant_provider.dart`, ajouter cette méthode dans la classe `RestaurantProvider` (juste après `loadRestaurant`, vers la ligne 37). `logger` y est déjà importé (utilisé par `loadRestaurant`) :
```dart
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
```

- [ ] **Step 4 : Lancer le test → succès**

Run: `cd flutter && flutter test test/restaurant_provider_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5 : Commit**

```bash
git add flutter/lib/providers/restaurant_provider.dart flutter/test/restaurant_provider_test.dart
git commit -m "feat(flutter): RestaurantProvider.tryLoadRestaurant (chargement best-effort)"
```

---

### Task 2 : `UserProvider.init` résilient

`_isConnected = true` dès que `getUser()` réussit ; amis + restaurant en best-effort. À ce stade `User.restaurantId` est encore un `String` non-null (passé sans souci à `tryLoadRestaurant(String?)`).

**Files:**
- Modify: `flutter/lib/providers/user_provider.dart`
- Test: `flutter/test/user_provider_init_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `flutter/test/user_provider_init_test.dart` :
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/user_service.dart';

class _FakeSecureStorage implements SecureStorage {
  String? accessToken;

  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<void> storeTokens(String accessToken, String refreshToken) async {}
  @override
  Future<void> storeAccessToken(String accessToken) async {}
  @override
  Future<void> storeRefreshToken(String refreshToken) async {}
  @override
  Future<Map<String, String?>> getTokens() async => {};
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> clearTokens() async {}
}

class _FakeUserService extends UserService {
  _FakeUserService() : super(dio: Dio());
  User? userToReturn;
  @override
  Future<User?> getUser() async => userToReturn;
}

class _FakeFriendService extends FriendService {
  _FakeFriendService() : super(dio: Dio());
  bool shouldThrow = false;
  List<Friend> friends = [];
  @override
  Future<List<Friend>> getFriends() async {
    if (shouldThrow) throw Exception('friends boom');
    return friends;
  }
}

class _FakeRestaurantProvider extends RestaurantProvider {
  _FakeRestaurantProvider() : super(RestaurantService(dio: Dio()));
  bool shouldThrow = false;
  int loadCalls = 0;
  @override
  Future<void> loadRestaurant(String restaurantId) async {
    loadCalls++;
    if (shouldThrow) throw Exception('resto boom');
  }
}

User _user() => User(
      id: '1',
      username: 'bob',
      status: 'absent',
      avatarUrl: 'a.png',
      restaurantId: 'resto1',
    );

void main() {
  late _FakeSecureStorage storage;
  late _FakeUserService userService;
  late _FakeFriendService friendService;
  late _FakeRestaurantProvider restaurantProvider;
  late UserProvider provider;

  setUp(() {
    storage = _FakeSecureStorage();
    userService = _FakeUserService();
    friendService = _FakeFriendService();
    restaurantProvider = _FakeRestaurantProvider();
    provider = UserProvider(secureStorage: storage);
  });

  test('pas de token → non connecté', () async {
    storage.accessToken = null;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, false);
    expect(provider.user, isNull);
  });

  test('token mais getUser null → non connecté', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = null;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, false);
  });

  test('REGRESSION: getUser OK mais loadRestaurant échoue → reste connecté',
      () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    restaurantProvider.shouldThrow = true;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
    expect(provider.user, isNotNull);
  });

  test('getUser OK mais getFriends échoue → reste connecté', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    friendService.shouldThrow = true;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
  });

  test('cas nominal → connecté, amis + resto chargés', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    friendService.friends = [
      Friend(id: '2', username: 'al', status: 'absent', avatarUrl: 'b.png'),
    ];
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
    expect(provider.friends.length, 1);
    expect(restaurantProvider.loadCalls, 1);
  });
}
```

- [ ] **Step 2 : Lancer le test → échec**

Run: `cd flutter && flutter test test/user_provider_init_test.dart`
Expected: FAIL — le test REGRESSION échoue (l'`init` actuel déconnecte quand `loadRestaurant` lève).

- [ ] **Step 3 : Réécrire `init` + importer le logger**

Dans `flutter/lib/providers/user_provider.dart`, ajouter l'import en tête (après les autres imports) :
```dart
import 'package:ru_project/services/logger.dart';
```
Puis remplacer entièrement la méthode `init` (lignes 21-44) par :
```dart
  Future<void> init(UserService userService, FriendService friendService,
      RestaurantProvider restaurantProvider) async {
    final accessToken = await secureStorage.getAccessToken();
    if (accessToken == null) {
      notifyListeners();
      return;
    }

    final user = await userService.getUser();
    if (user == null) {
      // Token présent mais session invalide : vraie déconnexion.
      clearUserData();
      return;
    }

    // Session valide : on est connecté, quoi qu'il advienne des données annexes.
    _user = user;
    _isConnected = true;

    // Chargements best-effort : un échec ne doit JAMAIS déconnecter.
    try {
      _friends = await friendService.getFriends();
    } catch (e) {
      logger.e('init: chargement des amis échoué (non bloquant): $e');
    }
    await restaurantProvider.tryLoadRestaurant(user.restaurantId);

    notifyListeners();
  }
```
> `clearUserData()` appelle déjà `notifyListeners()`.

- [ ] **Step 4 : Lancer le test → succès**

Run: `cd flutter && flutter test test/user_provider_init_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5 : Commit**

```bash
git add flutter/lib/providers/user_provider.dart flutter/test/user_provider_init_test.dart
git commit -m "fix(flutter): init() résilient — l'auth valide ne déconnecte plus sur échec annexe"
```

---

### Task 3 : `restaurantId` nullable + bascule des appelants login/register

On supprime la valeur fabriquée `'r135'` et on passe `restaurantId` en nullable ; on bascule les deux derniers appelants (`login`, `register`) sur `tryLoadRestaurant` — ce qui corrige aussi leur fragilité au login.

**Files:**
- Modify: `flutter/lib/models/user.dart`
- Modify: `flutter/lib/widgets/welcome/login.dart:29`
- Modify: `flutter/lib/widgets/welcome/register.dart:27`
- Test: `flutter/test/user_model_test.dart`

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `flutter/test/user_model_test.dart` :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/user.dart';

void main() {
  test('fromJson sans restaurantId → null (plus de défaut r135)', () {
    final user = User.fromJson({
      'id': '1',
      'username': 'bob',
      'status': 'absent',
      'avatarUrl': 'a.png',
    });
    expect(user.restaurantId, isNull);
  });

  test('fromJson conserve un restaurantId fourni', () {
    final user = User.fromJson({'restaurantId': 'abc'});
    expect(user.restaurantId, 'abc');
  });
}
```

- [ ] **Step 2 : Lancer le test → échec**

Run: `cd flutter && flutter test test/user_model_test.dart`
Expected: FAIL — le 1er test échoue (`restaurantId` vaut `'r135'`, pas `null`).

- [ ] **Step 3 : Passer `restaurantId` en nullable**

Dans `flutter/lib/models/user.dart` :
- Ligne 8, remplacer `String restaurantId;` par :
```dart
  String? restaurantId;
```
- Dans le constructeur (ligne 14), remplacer `required this.restaurantId,` par :
```dart
      this.restaurantId,
```
- Dans `fromJson` (ligne 24), remplacer la ligne `restaurantId: json['restaurantId'] ?? 'r135', // todo eviter confusion` par :
```dart
        restaurantId: json['restaurantId'],
```
(`toJson` et `toString` restent inchangés : une valeur nulle s'y sérialise/affiche sans souci.)

- [ ] **Step 4 : Basculer login + register sur `tryLoadRestaurant`**

Dans `flutter/lib/widgets/welcome/login.dart` (ligne 29), remplacer :
```dart
        await restaurantProvider.loadRestaurant(user.restaurantId);
```
par :
```dart
        await restaurantProvider.tryLoadRestaurant(user.restaurantId);
```
Faire le **même remplacement** dans `flutter/lib/widgets/welcome/register.dart` (ligne 27).

- [ ] **Step 5 : Lancer le test → succès**

Run: `cd flutter && flutter test test/user_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6 : Commit**

```bash
git add flutter/lib/models/user.dart flutter/lib/widgets/welcome/login.dart flutter/lib/widgets/welcome/register.dart flutter/test/user_model_test.dart
git commit -m "fix(flutter): restaurantId nullable (fin du défaut 'r135'), login/register en best-effort"
```

---

### Task 4 : Vérification globale (analyse + suite complète)

**Files:** aucun changement de code attendu (sauf correction d'un éventuel lint).

- [ ] **Step 1 : Analyse statique**

Run: `cd flutter && flutter analyze`
Expected: pas de **nouvelle** erreur introduite par ces changements (les warnings préexistants restent tolérés ; aucune référence cassée à `restaurantId` non-null).

- [ ] **Step 2 : Suite de tests complète**

Run: `cd flutter && flutter test`
Expected: tous les tests PASS (Phase 1 : app_colors, app_theme, main_destinations, more_widget, main_scaffold, widget_test ; Phase 0 : restaurant_provider, user_provider_init, user_model).

- [ ] **Step 3 : Si un lint apparaît, le corriger puis re-commit**

```bash
git add -A
git commit -m "chore(flutter): corriger les lints résiduels du fix Phase 0"
```
(Sinon, rien à committer.)

---

### Task 5 : Vérification manuelle sur web

Pas de test automatisé — on reproduit le scénario d'origine.

- [ ] **Step 1 : Lancer en web**

Run: `cd flutter && flutter run -d chrome` (backend local démarré).

- [ ] **Step 2 : Contrôler la check-list**

- Se connecter, puis faire **F5** → on **reste connecté** (plus de retour à l'accueil), même pour un utilisateur sans restaurant assigné.
- Le cas nominal (utilisateur avec restaurant valide) charge toujours la carte/secteurs.
- Login et register naviguent bien vers `MainScaffold` même si le restaurant ne charge pas.

- [ ] **Step 3 : Note d'avancement + rappel ops**

- Cocher toutes les cases de ce plan une fois validé.
- **Rappel hors périmètre code :** la prod renvoyait « Cannot GET /api/ru/:id » (backend périmé) → **redéployer la prod** avant lancement (action ops). Et décider plus tard (Phase 3/4) si les utilisateurs doivent être rattachés à un RU par défaut (champ `restaurant` du modèle `User`, souvent vide).

---

## Auto-revue (effectuée)

- **Couverture du spec :** invariant « auth valide ne déconnecte jamais sur échec annexe » → Task 2 ; `restaurantId` nullable / fin de `'r135'` → Task 3 ; tests d'`init` (token absent / getUser null / loadRestaurant throw / getFriends throw / nominal) → Task 2 ; test `fromJson` → Task 3 ; hors périmètre (redeploy prod, champ backend) → noté Task 5 Step 3.
- **Appelants de `loadRestaurant(user.restaurantId)` :** les 3 sites (`user_provider`, `login`, `register`) basculent sur `tryLoadRestaurant` → aucun `String?` passé à un paramètre `String` non-null restant.
- **Build vert par tâche :** Task 1 additive ; Task 2 utilise `tryLoadRestaurant(String?)` avec un `restaurantId` encore `String` (assignable) ; Task 3 passe au nullable et bascule simultanément les 2 derniers appelants.
- **Cohérence des types :** `tryLoadRestaurant(String?)` défini Task 1, consommé identique Tasks 2/3 ; doublures de test via `extends` (services/provider, classes non-`final`) et `implements SecureStorage` (constructeur privé) — toutes les méthodes publiques de `SecureStorage` sont implémentées.
- **Placeholders :** aucun — chaque step contient le code/commande réel.
