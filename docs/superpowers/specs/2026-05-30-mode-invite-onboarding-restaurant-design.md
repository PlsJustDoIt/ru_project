# Mode invité + onboarding restaurant — Design

**Date** : 2026-05-30
**Statut** : design validé, à implémenter
**Origine** : retour utilisateur — pouvoir utiliser l'app sans se connecter (« en tant que guest »).

## 1. Objectif & périmètre

Permettre d'utiliser l'application **sans compte** (mode invité), et introduire un
**onboarding de choix du restaurant** réutilisé à la fois au lancement invité et à
l'inscription.

| Fonction | Invité | Compte requis |
|---|:---:|:---:|
| Menu RU (CROUS) | ✅ | |
| Bus (Ginko) | ✅ | |
| Carte / plan des secteurs (lecture seule) | ✅ | |
| Check-in secteur (s'asseoir/se lever) | | ✅ |
| Voir amis dans les secteurs | | ✅ |
| Chat | | ✅ |
| Amis | | ✅ |
| Profil | | ✅ |

**Hors périmètre** : les autres idées d'amélioration du projet (cycles design→plan
séparés).

## 2. Décisions de design

1. **Accès backend invité** : on rend **publics** les endpoints de consultation
   (pas de token invité ni de middleware « auth optionnelle »). Données CROUS/Ginko
   publiques par nature.
2. **Navigation invité** : **3 onglets seulement** (Carte, Menu, Bus) + point
   d'entrée « Se connecter ». Pas d'onglets sociaux verrouillés.
3. **Onboarding** : choix du restaurant via un picker, affiché **une seule fois**
   pour l'invité (mémorisé localement), et intégré au flux d'inscription.
4. **Changement de RU connecté** : on branche réellement le dropdown des réglages
   (aujourd'hui non fonctionnel) via un nouvel endpoint `PUT /users/update-restaurant`.

## 3. Backend

### 3.1 Rendre publiques les routes de consultation
Retirer le middleware `auth` de (`routes/ru/ru.routes.ts`) :
- `GET /menus`
- `GET /restaurants`
- `GET /:restaurantId`
- `GET /:restaurantId/info`
- `GET /:restaurantId/sectors`

Et dans `routes/ginko` :
- `GET /info`

**Restent protégés** (inchangés) : `GET /:restaurantId/sectors-sessions` et
`/sectors-sessions/all`, `sectors/join|leave`, tout `users/`, chat, auth.
Conséquence : un invité voit le **plan des secteurs** mais **aucune session ni
identité** → cohérent avec « sans voir amis ». Le rate-limit 50 req/min continue
de s'appliquer.

### 3.2 Restaurant à l'inscription
`POST /register` accepte un champ **optionnel** `restaurantId` (string, ex. `"r135"`) :
- si fourni → résolu en `Restaurant._id` (lookup sur `Restaurant.restaurantId`) et
  écrit dans `user.restaurant` à la création.
- si absent → comportement actuel inchangé (pas de restaurant).

### 3.3 Endpoint de changement de restaurant (connecté)
Nouveau `PUT /api/users/update-restaurant` (auth) :
- body : `{ restaurantId: string }`
- résout `restaurantId` → `Restaurant._id`, écrit `user.restaurant`, renvoie le user mis à jour.
- 404 si le `restaurantId` n'existe pas.

> Note : aujourd'hui `user.restaurant` (ObjectId, ref `Restaurant`) n'est jamais
> défini à l'inscription — trou existant que §3.2 comble.

## 4. Flutter — état & persistance du mode invité

### 4.1 Persistance
`SecureStorage` : nouvelle clé `guestRestaurantId` (string).

Règle de mode au démarrage (`UserProvider.init` / `main.dart`) :
1. token présent + session valide → **connecté** → `MainScaffold` (destinations complètes)
2. pas de token + `guestRestaurantId` présent → **invité** → `MainScaffold` (destinations invité)
3. sinon → **`WelcomeWidget`**

### 4.2 État
`UserProvider` expose `bool isGuest` (true si mode invité actif). Au **login/register
réussi**, on quitte le mode invité (et on peut effacer `guestRestaurantId`, le resto
du compte faisant foi).

### 4.3 Intercepteur Dio (nettoyage)
Aujourd'hui l'`onRequest` attache `Authorization: Bearer null` quand il n'y a pas de
token. On **n'attache pas** l'en-tête `Authorization` si le token est nul (sans risque
sur les routes publiques, plus propre, évite tout effet de bord côté backend).

## 5. Flutter — `RestaurantPicker` réutilisable

Nouveau widget de sélection de restaurant :
- source : `RestaurantService.getRestaurants()` → `List<RestaurantPartial>` (`restaurantId`, `name`) — **existe déjà**.
- UI : reprend le pattern dropdown de `settings_widget.dart`.
- callback `onSelected(restaurantId)`.

**Réutilisé dans 2 flux** :
- **Invité** : `WelcomeWidget` → bouton « Continuer sans compte » → picker → stocke
  `guestRestaurantId` → entre dans l'app (affiché une seule fois).
- **Inscription** : étape « restaurant » ajoutée au flux register → `restaurantId`
  envoyé dans `POST /register`.

## 6. Flutter — navigation invité

`MainScaffold` accepte déjà un paramètre `destinations` injectable.

Nouvelle liste `kGuestDestinations` = `[Carte, Menu, Bus]`
(Bus, aujourd'hui sous l'onglet « Plus », devient un onglet top-level pour l'invité).

- Action AppBar **« Se connecter »** visible en mode invité → `WelcomeWidget` / login.
- Accès **« Changer de RU »** invité (re-déclenche `RestaurantPicker`, met à jour
  `guestRestaurantId` + recharge `RestaurantProvider`). Emplacement : action AppBar.
- **Pas de connexion chat** en mode invité (`NotificationProvider` reste à 0, aucune
  bannière). `MainScaffold.initState` lit `user?.username` (null en invité) → OK.

## 7. Flutter — carte en lecture seule

`FloorPlan` (`map_widget.dart`) est couplé à un user connecté :
`restaurant = restaurantProvider.restaurant!` + appel `getFriendsSessions` (route protégée).

Modifications :
- Au démarrage invité, charger le resto choisi dans `RestaurantProvider`
  (`loadRestaurant(guestRestaurantId)`), de sorte que `restaurantProvider.restaurant`
  ne soit jamais null à l'ouverture de la carte.
- Ajouter un **mode lecture seule** piloté par `userProvider.isGuest` :
  - **ne pas** appeler `getFriendsSessions` ;
  - masquer le bouton *S'asseoir / Se lever*, le FAB *Sessions*, la section *Amis dans le secteur* ;
  - tap secteur → infos du secteur uniquement (couleurs par défaut, pas d'occupation amis).

## 8. Flutter — réglages : brancher le changement de RU (connecté)

`settings_widget.dart` :
- `onChanged` du dropdown → appelle le nouveau `PUT /users/update-restaurant`, puis
  recharge `RestaurantProvider.loadRestaurant(...)` et met à jour le user.
- **Initialiser** le dropdown sur le **restaurant réel** de l'utilisateur
  (`user.restaurant`/`restaurantId`) plutôt que « premier de la liste », pour que
  l'écran reflète l'état réel (sinon un dropdown qui persiste mais s'affiche sur le
  premier resto serait incohérent).
- Retour visuel (snackbar) succès / erreur.

## 9. Tests

### Backend (Jest + supertest)
- Mettre à jour les tests qui attendaient `401` sur les routes désormais publiques.
- Ajouter : `200` **sans token** pour `menus`, `ginko/info`, `restaurants`,
  `:restaurantId`, `:restaurantId/sectors`.
- Vérifier que `sectors-sessions` reste `401` sans token.
- `POST /register` avec `restaurantId` → `user.restaurant` défini ; sans → inchangé ;
  `restaurantId` inexistant → erreur propre.
- `PUT /users/update-restaurant` : succès, 404 resto inconnu, 401 sans token.

### Flutter
Pas d'infra de test active (cf. `AUDIT.md`) → **vérification manuelle** :
1. Premier lancement sans compte → onboarding → choix resto → 3 onglets.
2. Carte invité : plan visible, pas de check-in, pas de FAB Sessions, pas d'amis.
3. Menu et Bus accessibles en invité.
4. « Se connecter » depuis l'invité → login → bascule vers app complète.
5. Relancement invité → arrive directement (resto mémorisé), pas de ré-onboarding.
6. Connecté : changer de RU dans les réglages → persiste après relance.

## 10. Risques & points d'attention

- **Confidentialité** : on ne rend publiques que des données non personnelles
  (menus, horaires, plan des secteurs). Les sessions/identités restent protégées.
- **Couplage carte** : `FloorPlan` force-unwrap `restaurant!` ; bien garantir le
  chargement du resto invité avant l'affichage de l'onglet Carte.
- **Cohérence resto** : `update-restaurant` doit recharger `RestaurantProvider` pour
  que la carte reflète immédiatement le changement.
