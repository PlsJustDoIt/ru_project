# Plan de Refactorisation 2025 - ru_project

Ce document détaille les pistes d'amélioration pour l'architecture et le code du projet `ru_project`, en s'inspirant des meilleures pratiques observées dans des projets de référence comme `compass_app`. L'objectif est d'améliorer la maintenabilité, la testabilité et la robustesse de l'application.

---

## 1. Architecture : Vers une Clean Architecture

L'architecture actuelle, basée sur des dossiers par type (`services`, `models`, `providers`), est simple mais peut rendre le projet difficile à faire évoluer. Une "Clean Architecture" sépare clairement les responsabilités en couches distinctes.

**Pourquoi ?**
- **Testabilité :** La logique métier (`domain`) peut être testée sans aucune dépendance à l'UI ou à la base de données.
- **Indépendance :** Le cœur de votre application (`domain`) ne dépend d'aucun framework. Vous pourriez changer de base de données ou de framework UI sans le réécrire.
- **Organisation :** Le code est plus facile à trouver, et les dépendances sont claires et unidirectionnelles (UI -> Domain <- Data).

### Checklist de Migration

- [ ] **Créer la structure de dossiers**
  - `lib/domain` : Le cœur de l'application.
    - `lib/domain/models` : Vos classes de modèle pures (ex: `User`, `Friend`).
    - `lib/domain/repositories` : Des classes abstraites (`abstract class`) qui définissent des "contrats" pour la récupération de données (ex: `abstract class FriendRepository`).
  - `lib/data` : L'implémentation des contrats du domaine.
    - `lib/data/repositories` : Les classes concrètes qui implémentent les contrats (ex: `class FriendRepositoryImpl implements FriendRepository`). C'est ici que les appels API avec `Dio` seront faits.
    - `lib/data/models` : (Optionnel) Si les modèles de l'API sont différents de ceux du domaine, on les met ici (DTOs - Data Transfer Objects).
  - `lib/ui` (ou `presentation`) : Tout ce qui concerne l'interface utilisateur.
    - `lib/ui/screens` : Les différents écrans de l'application.
    - `lib/ui/widgets` : Les widgets réutilisables.
    - `lib/ui/blocs` ou `lib/ui/view_models` : La logique de gestion d'état.

- [ ] **Migrer le code existant**
  - [ ] Déplacer les modèles actuels dans `lib/domain/models`.
  - [ ] Créer les contrats dans `lib/domain/repositories`.
  - [ ] Déplacer la logique des `services` actuels dans les implémentations de `lib/data/repositories`.
  - [ ] Mettre à jour le reste du code pour utiliser les nouveaux `repositories` au lieu des anciens `services`.

---

## 2. Modèles de Donn��es : Adopter `freezed`

Actuellement, vos modèles sont écrits à la main, ce qui est répétitif et source d'erreurs. `freezed` est un générateur de code qui simplifie et sécurise la création de modèles.

**Pourquoi ?**
- **Moins de code :** Fini d'écrire `fromJson`, `toJson`, `copyWith`, `toString`, `==` et `hashCode`.
- **Immutabilité :** Les objets créés sont immuables par défaut, ce qui prévient de nombreux bugs.
- **Fonctionnalités avancées :** Permet de créer facilement des "sealed classes" (unions), parfaites pour la gestion d'état.

### Checklist d'Intégration

- [ ] **Ajouter les dépendances au `pubspec.yaml`**
  ```yaml
  dependencies:
    freezed_annotation: ^2.4.1

  dev_dependencies:
    build_runner: ^2.4.8
    freezed: ^2.4.7
    json_serializable: ^6.7.1
  ```

- [ ] **Convertir un premier modèle (ex: `Friend`)**
  ```dart
  // lib/domain/models/friend.dart
  import 'package:freezed_annotation/freezed_annotation.dart';

  part 'friend.freezed.dart'; // Le nom du fichier actuel + .freezed.dart
  part 'friend.g.dart';      // Le nom du fichier actuel + .g.dart

  @freezed
  class Friend with _$Friend {
    const factory Friend({
      @JsonKey(name: '_id') required String id,
      required String username,
      required String status,
      required String avatarUrl,
    }) = _Friend;

    factory Friend.fromJson(Map<String, dynamic> json) => _$FriendFromJson(json);
  }
  ```

- [ ] **Lancer la génération de code**
  - Exécutez cette commande dans votre terminal :
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```

- [ ] **Migrer progressivement**
  - [ ] Remplacer l'ancien modèle `Friend` par le nouveau dans toute l'application.
  - [ ] Répéter le processus pour tous les autres modèles (`User`, `Message`, etc.).

---

## 3. Gestion de l'État : Migrer vers BLoC

`Provider` avec `ChangeNotifier` est bien, mais `BLoC` offre une séparation plus stricte entre la logique et l'UI, ce qui est idéal pour les écrans complexes.

**Pourquoi ?**
- **Flux de données clair :** Le flux `UI -> Event -> BLoC -> State -> UI` est très prédictible.
- **Testabilité :** Un BLoC peut être testé de manière unitaire, sans avoir besoin de construire l'UI.
- **Moins de rebuilds inutiles :** L'UI ne se reconstruit que lorsque l'état change réellement.

### Checklist de Migration (pour un écran)

- [ ] **Ajouter la dépendance `flutter_bloc`**
- [ ] **Définir les `Events` :** Les actions que l'utilisateur peut faire.
  ```dart
  // Ex: friend_list_event.dart
  @freezed
  abstract class FriendListEvent with _$FriendListEvent {
    const factory FriendListEvent.load() = _Load;
  }
  ```
- [ ] **Définir les `States` :** Les différents états de l'écran (initial, chargement, succès, erreur).
  ```dart
  // Ex: friend_list_state.dart
  @freezed
  abstract class FriendListState with _$FriendListState {
    const factory FriendListState.initial() = _Initial;
    const factory FriendListState.loading() = _Loading;
    const factory FriendListState.loaded(List<Friend> friends) = _Loaded;
    const factory FriendListState.error(String message) = _Error;
  }
  ```
- [ ] **Créer le `BLoC`**
  - Il prend des `Events` en entrée et produit des `States` en sortie.
- [ ] **Intégrer dans l'UI**
  - [ ] Fournir le BLoC avec `BlocProvider`.
  - [ ] Envoyer des événements avec `context.read<FriendListBloc>().add(FriendListEvent.load())`.
  - [ ] Reconstruire l'UI avec `BlocBuilder`.

---

## 4. Gestion des Erreurs : Utiliser `Either`

Lancer des exceptions (`throw Exception`) cache le fait qu'une fonction peut échouer. Utiliser un type `Either` rend la gestion d'erreur explicite et obligatoire.

**Pourquoi ?**
- **Sécurité :** La signature de la fonction `Future<Either<Failure, Success>>` vous force à gérer le cas d'erreur.
- **Clarté :** Le code est plus lisible. On voit immédiatement les deux chemins possibles (succès ou échec).

### Checklist d'Intégration

- [ ] **Ajouter la dépendance `fpdart`**
- [ ] **Créer une classe `Failure` générique**
  ```dart
  class Failure {
    final String message;
    Failure(this.message);
  }
  ```
- [ ] **Modifier la signature d'une méthode de repository**
  ```dart
  // Avant
  Future<List<Friend>> getFriends();

  // Après
  Future<Either<Failure, List<Friend>>> getFriends();
  ```
- [ ] **Adapter le code du repository**
  ```dart
  try {
    // ... appel api ...
    return Right(friends); // Le côté droit pour le succès
  } catch (e) {
    return Left(Failure('Impossible de charger les amis.')); // Le côté gauche pour l'échec
  }
  ```
- [ ] **Gérer le résultat dans le BLoC/ViewModel**
  ```dart
  final result = await friendRepository.getFriends();
  result.fold(
    (failure) => emit(FriendListState.error(failure.message)), // Si c'est un Left
    (friends) => emit(FriendListState.loaded(friends)),      // Si c'est un Right
  );
  ```

---

## 5. Routage : Adopter `go_router`

Le système de navigation actuel (`home: isConnected ? A : B`) est simple mais limité. Un routeur déclaratif comme `go_router` (recommandé par l'équipe Flutter) centralise la navigation et gère des cas complexes comme l'authentification.

**Pourquoi ?**
- **Centralisation :** Toutes les routes (`/login`, `/profile`, `/friends/:id`) sont définies en un seul endroit.
- **Sécurité :** Permet de créer un "gardien d'authentification" (`redirect`) qui protège les routes et redirige automatiquement vers la page de connexion si l'utilisateur n'est pas authentifié.
- **Navigation par URL (Deep Linking) :** Gère nativement la navigation à partir de liens externes.

### Checklist d'Intégration

- [ ] **Ajouter la dépendance `go_router`**
- [ ] **Créer un fichier pour le routeur (ex: `lib/routing/app_router.dart`)**
- [ ] **Définir les routes et la logique de redirection**
  ```dart
  final GoRouter router = GoRouter(
    refreshListenable: userProvider, // Le routeur écoute les changements d'état de connexion
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const WelcomeWidget(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const TabBarWidget(),
      ),
    ],
    redirect: (context, state) {
      final bool isLoggedIn = userProvider.isConnected;
      final bool isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login'; // Si pas connecté, redirige vers /login
      }
      if (isLoggingIn) {
        return '/'; // Si connecté et sur /login, redirige vers l'accueil
      }
      return null; // Pas de redirection
    },
  );
  ```
- [ ] **Modifier `MyApp` pour utiliser `MaterialApp.router`**
  ```dart
  class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      return MaterialApp.router(
        routerConfig: router, // Utiliser la configuration du routeur
        // ... reste du thème ...
      );
    }
  }
  ```

---

## 6. Configurations par Environnement

Avoir une seule configuration pour le développement et la production est risqué. Il faut séparer les configurations pour éviter d'utiliser des API de dev en production, par exemple.

**Pourquoi ?**
- **Sécurité :** Empêche les clés d'API de test de fuiter en production.
- **Stabilité :** Permet d'utiliser des URL d'API différentes pour le développement, la pré-production (`staging`) et la production.
- **Flexibilité :** Permet d'activer des logs détaillés en développement ou d'utiliser des données "mockées" sans affecter la version de production.

### Checklist de Mise en Place

- [ ] **Créer des points d'entrée différents**
  - [ ] `lib/main_development.dart`
  - [ ] `lib/main_production.dart`
  - [ ] (Optionnel) `lib/main_staging.dart`

- [ ] **Adapter chaque point d'entrée pour charger sa propre configuration**
  ```dart
  // Dans lib/main_development.dart
  void main() {
    // Configurer pour le développement
    Config.init(apiUrl: 'http://localhost:3000/api');
    // Lancer l'application
    runApp(const MyApp());
  }

  // Dans lib/main_production.dart
  void main() {
    // Configurer pour la production
    Config.init(apiUrl: 'https://api.ru-project.com');
    // Lancer l'application
    runApp(const MyApp());
  }
  ```

- [ ] **Modifier le `Config.dart` pour accepter des paramètres**
  ```dart
  class Config {
    static String apiUrl = 'default_url';

    static Future<void> init({required String apiUrl}) async {
      Config.apiUrl = apiUrl;
      // ...
    }
  }
  ```

- [ ] **Utiliser les configurations de lancement de VS Code ou d'Android Studio**
  - Créez des configurations pour lancer l'application avec la bonne cible (`-t`).
  - Exemple de `launch.json` pour VS Code :
    ```json
    "configurations": [
        {
            "name": "Launch Dev",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_development.dart"
        },
        {
            "name": "Launch Prod",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_production.dart"
        }
    ]
    ```
- [ ] **Adapter les commandes de build**
  ```bash
  # Pour builder l'APK de production
  flutter build apk --release -t lib/main_production.dart
  ```