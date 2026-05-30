# Mode invité + onboarding restaurant — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre d'utiliser l'app sans compte (Carte/Menu/Bus en lecture seule) et introduire un onboarding de choix du restaurant réutilisé au lancement invité et à l'inscription.

**Architecture:** Backend — on rend publics les endpoints de consultation et on standardise l'identifiant restaurant exposé sur l'`_id` Mongo (cohérent avec `user.restaurant` et `GET /:restaurantId`). Flutter — un mode invité piloté par `UserProvider.isGuest`, persisté via une clé `guestRestaurantId` dans `SecureStorage`, qui réutilise `MainScaffold` avec une liste de destinations réduite et passe la carte en lecture seule.

**Tech Stack:** Backend Node/Express/TypeScript + Mongoose, tests Jest + supertest + mongodb-memory-server. Flutter + Provider + Dio.

---

## Référence — identifiant restaurant (IMPORTANT)

Avant ce lot, deux identifiants coexistent :
- `user.restaurant` (ObjectId) → sérialisé en `restaurantId` (string `_id`) par `GET /users/me`. C'est l'id utilisé par `GET /:restaurantId`, `GET /:restaurantId/sectors` (qui valident `Types.ObjectId.isValid`), et par `RestaurantProvider.loadRestaurant`.
- `Restaurant.restaurantId` (champ string type `"r135"`) → renvoyé par `GET /restaurants` (à cause de la projection `-_id`).

Le picker se base sur `GET /restaurants` mais alimente `loadRestaurant`, qui exige l'`_id`. **La Task 2 corrige cette incohérence** en faisant renvoyer l'`_id` Mongo par `GET /restaurants` (clé JSON `restaurantId` conservée → modèle Flutter inchangé). Tout le lot s'aligne ensuite sur l'`_id` Mongo.

## File Structure

**Backend (`backend/src/`)**
- `routes/ru/ru.routes.ts` — retirer `auth` des routes de consultation (modif).
- `routes/ginko/ginko.routes.ts` — retirer `auth` de `/info` (modif).
- `routes/ru/ru.controller.ts` — `getRestaurants` renvoie l'`_id` (modif).
- `routes/auth/auth.controller.ts` — `registerUser` accepte `restaurantId` optionnel (modif).
- `routes/user/user.controller.ts` — nouveau `updateRestaurant` (modif).
- `routes/user/user.routes.ts` — route `PUT /update-restaurant` (modif).
- `routes/ru/ru-public.spec.ts` — nouveau (accès public + mapping `_id`).
- `routes/ginko/ginko.spec.ts` — ajouter un test « sans token » (modif).
- `routes/auth/register-restaurant.spec.ts` — nouveau.
- `routes/user/update-restaurant.spec.ts` — nouveau.

**Flutter (`flutter/lib/`)**
- `services/secure_storage.dart` — clé `guestRestaurantId` (modif).
- `providers/user_provider.dart` — `isGuest` + intégration `init` (modif).
- `services/auth_service.dart` — `register` gagne `restaurantId` (modif).
- `services/user_service.dart` — `updateRestaurant` (modif).
- `services/api_client.dart` — pas d'en-tête `Authorization` si token nul (modif).
- `widgets/welcome/restaurant_picker.dart` — nouveau widget.
- `widgets/welcome/welcome.dart` — bouton « Continuer sans compte » (modif).
- `widgets/welcome/login.dart` + `welcome/register.dart` — nettoyage mode invité (modif).
- `widgets/welcome/register.dart` — register 2 étapes (modif).
- `widgets/navigation/main_destinations.dart` — `kGuestDestinations` (modif).
- `main.dart` — logique `home` invité (modif).
- `widgets/main_scaffold.dart` — actions invité (Se connecter / Changer de RU) (modif).
- `widgets/map_widget.dart` — mode lecture seule (modif).
- `widgets/settings_widget.dart` — câbler `update-restaurant` + init resto réel (modif).

## Notes de test
- **Backend** : TDD strict (Jest). Lancer une suite : `cd backend && npx jest <chemin> --silent`.
- **Flutter** : pas d'infra de test active (cf. `AUDIT.md` ; les widget tests ne compilent pas sur la VM). Vérification de chaque task Flutter = `cd flutter && flutter analyze` (aucune **nouvelle** erreur) + checklist manuelle finale (Task 15). C'est volontaire et documenté.

---

# PHASE A — Backend

### Task 1: Rendre publiques les routes de consultation

**Files:**
- Modify: `backend/src/routes/ru/ru.routes.ts`
- Modify: `backend/src/routes/ginko/ginko.routes.ts`
- Test: `backend/src/routes/ru/ru-public.spec.ts` (créé en Task 2, qui valide aussi l'accès public ; ici on vérifie surtout que `sectors-sessions` reste protégé)

- [ ] **Step 1: Retirer `auth` des routes de consultation `ru`**

Dans `backend/src/routes/ru/ru.routes.ts`, remplacer le contenu des routes par (le `:restaurantId` reste en dernier ; `sectors-sessions` GARDE `auth`) :

```ts
import auth from '../../middleware/auth.js';
import { Router } from 'express';
import { getMenus, getApiDoc, getSectors, getRestaurants, getSectorsSessions, getAllSectorsSessions, getRestaurantInfo, getRestaurantByOwnId } from './ru.controller.js';
const router = Router();

router.get('/', getApiDoc);

router.get('/:restaurantId/sectors', getSectors);

router.get('/menus', getMenus);

router.get('/restaurants', getRestaurants);

// Restent protégés : sessions = identités d'utilisateurs
router.get('/:restaurantId/sectors-sessions', auth, getSectorsSessions);
router.get('/:restaurantId/sectors-sessions/all', auth, getAllSectorsSessions);

router.get('/:restaurantId/info', getRestaurantInfo);

router.get('/:restaurantId', getRestaurantByOwnId);

export default router;
```

- [ ] **Step 2: Retirer `auth` de `ginko /info`**

Dans `backend/src/routes/ginko/ginko.routes.ts`, la ligne `router.get('/info', auth, getSchedules);` devient :

```ts
router.get('/info', getSchedules);
```

L'import `auth` devient inutilisé dans ce fichier — le supprimer pour ne pas casser le lint (`import auth from '../../middleware/auth.js';`).

- [ ] **Step 3: Vérifier la compilation TypeScript**

Run: `cd backend && npx tsc --noEmit`
Expected: aucune erreur.

- [ ] **Step 4: Vérifier que la suite ginko existante passe toujours**

Run: `cd backend && npx jest routes/ginko/ginko.spec.ts --silent`
Expected: PASS (le test existant envoie un header `authorization`, désormais ignoré — toujours 200).

- [ ] **Step 5: Commit**

```bash
cd backend && git add src/routes/ru/ru.routes.ts src/routes/ginko/ginko.routes.ts
git commit -m "feat(backend): rendre publics les endpoints de consultation (menus, ginko, restaurants, sectors)"
```

---

### Task 2: `GET /restaurants` renvoie l'`_id` Mongo

**Files:**
- Modify: `backend/src/routes/ru/ru.controller.ts` (fonction `getRestaurants`)
- Test: `backend/src/routes/ru/ru-public.spec.ts` (créé)

- [ ] **Step 1: Écrire le test (accès public + `_id`)**

Créer `backend/src/routes/ru/ru-public.spec.ts` :

```ts
import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let restaurantObjectId: string;

describe('RU public endpoints', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const resto = await Restaurant.create({
            restaurantId: 'r135',
            name: 'RU Test',
            address: '1 rue du test',
            description: 'desc',
        });
        restaurantObjectId = resto._id.toString();
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('GET /api/ru/restaurants sans token -> 200 et expose _id comme restaurantId', async () => {
        const res = await request(app).get('/api/ru/restaurants');
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.restaurants)).toBe(true);
        expect(res.body.restaurants[0].restaurantId).toBe(restaurantObjectId);
        expect(res.body.restaurants[0].name).toBe('RU Test');
    });

    it('GET /api/ru/:id/sectors sans token -> 200', async () => {
        const res = await request(app).get(`/api/ru/${restaurantObjectId}/sectors`);
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body.sectors)).toBe(true);
    });

    it('GET /api/ru/:id/sectors-sessions sans token -> 401 (reste protégé)', async () => {
        const res = await request(app).get(`/api/ru/${restaurantObjectId}/sectors-sessions`);
        expect(res.statusCode).toBe(401);
    });
});
```

- [ ] **Step 2: Lancer le test, vérifier l'échec attendu**

Run: `cd backend && npx jest routes/ru/ru-public.spec.ts --silent`
Expected: le 1er test ÉCHOUE — `restaurants[0].restaurantId` vaut `"r135"` (champ string) au lieu de l'`_id`.

- [ ] **Step 3: Modifier `getRestaurants`**

Dans `backend/src/routes/ru/ru.controller.ts`, remplacer le corps de `getRestaurants` :

```ts
const getRestaurants = async (req: Request, res: Response) => {
    try {
        const restaurants = await Restaurant.find().select('name').limit(10);
        if (!restaurants || restaurants.length === 0) {
            return res.status(404).json({ error: 'No restaurants found' });
        }
        return res.json({
            restaurants: restaurants.map((r) => ({ restaurantId: r._id, name: r.name })),
        });
    } catch (error) {
        logger.error('Erreur lors de la récupération des restaurants:', error);
        return res.status(500).json({ error: 'Erreur lors de la récupération des restaurants' });
    }
};
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd backend && npx jest routes/ru/ru-public.spec.ts --silent`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd backend && git add src/routes/ru/ru.controller.ts src/routes/ru/ru-public.spec.ts
git commit -m "feat(backend): GET /restaurants expose l'_id Mongo (aligne picker/carte/register)"
```

---

### Task 3: `register` accepte un `restaurantId` optionnel

**Files:**
- Modify: `backend/src/routes/auth/auth.controller.ts` (fonction `registerUser`)
- Test: `backend/src/routes/auth/register-restaurant.spec.ts` (créé)

- [ ] **Step 1: Écrire le test**

Créer `backend/src/routes/auth/register-restaurant.spec.ts` :

```ts
import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let restaurantObjectId: string;

describe('register avec restaurantId', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const resto = await Restaurant.create({
            restaurantId: 'r135', name: 'RU Test', address: 'a', description: 'd',
        });
        restaurantObjectId = resto._id.toString();
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('register avec restaurantId valide -> /me renvoie ce restaurantId', async () => {
        const reg = await request(app).post('/api/auth/register').send({
            username: 'withresto', password: 'password123', restaurantId: restaurantObjectId,
        });
        expect(reg.statusCode).toBe(201);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${reg.body.accessToken}`);
        expect(me.statusCode).toBe(200);
        expect(me.body.user.restaurantId).toBe(restaurantObjectId);
    });

    it('register sans restaurantId -> compte créé, pas de restaurant', async () => {
        const reg = await request(app).post('/api/auth/register').send({
            username: 'noresto', password: 'password123',
        });
        expect(reg.statusCode).toBe(201);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${reg.body.accessToken}`);
        expect(me.body.user.restaurantId).toBeUndefined();
    });

    it('register avec restaurantId inexistant -> 400', async () => {
        const fakeId = new mongoose.Types.ObjectId().toString();
        const reg = await request(app).post('/api/auth/register').send({
            username: 'badresto', password: 'password123', restaurantId: fakeId,
        });
        expect(reg.statusCode).toBe(400);
    });
});
```

- [ ] **Step 2: Lancer le test, vérifier l'échec attendu**

Run: `cd backend && npx jest routes/auth/register-restaurant.spec.ts --silent`
Expected: ÉCHOUE — `me.body.user.restaurantId` est `undefined` même avec un `restaurantId` fourni.

- [ ] **Step 3: Modifier `registerUser`**

Dans `backend/src/routes/auth/auth.controller.ts`, ajouter les imports en haut (après l'import de `User`) :

```ts
import { Types } from 'mongoose';
import Restaurant from '../../models/restaurant.js';
```

Puis remplacer le bloc création d'utilisateur dans `registerUser` (entre la vérification `existingUser` et `generateTokens`) :

```ts
        // Create new user
        const user = new User({ username, password });

        // Restaurant optionnel (onboarding)
        const { restaurantId } = req.body;
        if (restaurantId) {
            if (!Types.ObjectId.isValid(restaurantId)) {
                return res.status(400).json({ error: { message: 'Invalid restaurant ID', field: 'restaurantId' } });
            }
            const restaurant = await Restaurant.findById(restaurantId);
            if (!restaurant) {
                return res.status(400).json({ error: { message: 'Restaurant not found', field: 'restaurantId' } });
            }
            user.restaurant = restaurant._id;
        }

        await user.save();
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `cd backend && npx jest routes/auth/register-restaurant.spec.ts --silent`
Expected: PASS (3 tests).

- [ ] **Step 5: Vérifier la non-régression de la suite auth existante**

Run: `cd backend && npx jest routes/auth --silent`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd backend && git add src/routes/auth/auth.controller.ts src/routes/auth/register-restaurant.spec.ts
git commit -m "feat(backend): register accepte un restaurantId optionnel (onboarding)"
```

---

### Task 4: `PUT /users/update-restaurant`

**Files:**
- Modify: `backend/src/routes/user/user.controller.ts` (nouvelle fonction + export)
- Modify: `backend/src/routes/user/user.routes.ts` (route)
- Test: `backend/src/routes/user/update-restaurant.spec.ts` (créé)

- [ ] **Step 1: Écrire le test**

Créer `backend/src/routes/user/update-restaurant.spec.ts` :

```ts
import request from 'supertest';
import app, { setupRoutes } from '../../app.js';
import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import Restaurant from '../../models/restaurant.js';
import logger from '../../utils/logger.js';

let mongoServer: MongoMemoryServer;
let accessToken: string;
let restaurantObjectId: string;

describe('PUT /api/users/update-restaurant', () => {
    beforeAll(async () => {
        logger.info = jest.fn();
        logger.error = jest.fn();
        setupRoutes(app);
        mongoServer = await MongoMemoryServer.create();
        await mongoose.connect(mongoServer.getUri());
        const resto = await Restaurant.create({
            restaurantId: 'r135', name: 'RU Test', address: 'a', description: 'd',
        });
        restaurantObjectId = resto._id.toString();
        const reg = await request(app).post('/api/auth/register')
            .send({ username: 'updresto', password: 'password123' });
        accessToken = reg.body.accessToken;
    });

    afterAll(async () => {
        await mongoose.disconnect();
        await mongoose.connection.close();
        await mongoServer.stop();
    });

    it('sans token -> 401', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .send({ restaurantId: restaurantObjectId });
        expect(res.statusCode).toBe(401);
    });

    it('id invalide -> 400', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: 'pas-un-objectid' });
        expect(res.statusCode).toBe(400);
    });

    it('restaurant inexistant -> 404', async () => {
        const fakeId = new mongoose.Types.ObjectId().toString();
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: fakeId });
        expect(res.statusCode).toBe(404);
    });

    it('succès -> 200 et /me reflète le nouveau restaurant', async () => {
        const res = await request(app).put('/api/users/update-restaurant')
            .set('authorization', `Bearer ${accessToken}`)
            .send({ restaurantId: restaurantObjectId });
        expect(res.statusCode).toBe(200);
        expect(res.body.restaurantId).toBe(restaurantObjectId);
        const me = await request(app).get('/api/users/me')
            .set('authorization', `Bearer ${accessToken}`);
        expect(me.body.user.restaurantId).toBe(restaurantObjectId);
    });
});
```

- [ ] **Step 2: Lancer le test, vérifier l'échec attendu**

Run: `cd backend && npx jest routes/user/update-restaurant.spec.ts --silent`
Expected: ÉCHOUE — la route n'existe pas (404 sur tous, dont le test « sans token » attend 401).

- [ ] **Step 3: Ajouter le contrôleur**

Dans `backend/src/routes/user/user.controller.ts`, ajouter les imports manquants en haut :

```ts
import { Types } from 'mongoose';
import Restaurant from '../../models/restaurant.js';
```

Ajouter la fonction (par ex. après `updateStatus`) :

```ts
const updateRestaurant = async (req: Request, res: Response) => {
    try {
        const { restaurantId } = req.body;
        if (!restaurantId || !Types.ObjectId.isValid(restaurantId)) {
            return res.status(400).json({ error: 'Invalid restaurant ID' });
        }
        const restaurant = await Restaurant.findById(restaurantId);
        if (!restaurant) {
            return res.status(404).json({ error: 'Restaurant not found' });
        }
        const user = await User.findById(req.user.id);
        if (user === null) {
            return res.status(404).json({ error: 'User not found' });
        }
        user.restaurant = restaurant._id;
        await user.save();
        return res.json({ restaurantId: user.restaurant.toString() });
    } catch (err: unknown) {
        logger.error(`Could not update restaurant : ${err}`);
        return res.status(500).json({ error: 'An error has occured' });
    }
};
```

Ajouter `updateRestaurant` à l'export en bas du fichier (l'export liste les fonctions, ex. `export { ..., updateStatus, updateRestaurant, ... }` — insérer le nom dans la liste existante).

- [ ] **Step 4: Ajouter la route**

Dans `backend/src/routes/user/user.routes.ts` :
- ajouter `updateRestaurant` à l'import depuis `./user.controller.js` ;
- ajouter la route après `update-status` :

```ts
router.put('/update-restaurant', auth, updateRestaurant);
```

- [ ] **Step 5: Lancer le test, vérifier le succès**

Run: `cd backend && npx jest routes/user/update-restaurant.spec.ts --silent`
Expected: PASS (4 tests).

- [ ] **Step 6: Vérifier toute la suite backend + types**

Run: `cd backend && npx tsc --noEmit && npm test`
Expected: PASS (toutes suites), `tsc` propre.

- [ ] **Step 7: Commit**

```bash
cd backend && git add src/routes/user/user.controller.ts src/routes/user/user.routes.ts src/routes/user/update-restaurant.spec.ts
git commit -m "feat(backend): PUT /users/update-restaurant (changer son RU)"
```

---

# PHASE B — Flutter (fondations)

> Vérification de chaque task : `cd flutter && flutter analyze` sans nouvelle erreur, puis commit.

### Task 5: Persistance du restaurant invité

**Files:**
- Modify: `flutter/lib/services/secure_storage.dart`

- [ ] **Step 1: Ajouter les méthodes guest**

Dans `flutter/lib/services/secure_storage.dart`, ajouter avant `clearTokens` :

```dart
  Future<void> storeGuestRestaurantId(String restaurantId) async {
    await _secureStorage.write(key: 'guestRestaurantId', value: restaurantId);
  }

  Future<String?> getGuestRestaurantId() async {
    return await _secureStorage.read(key: 'guestRestaurantId');
  }

  Future<void> clearGuestRestaurantId() async {
    await _secureStorage.delete(key: 'guestRestaurantId');
  }
```

- [ ] **Step 2: Analyser**

Run: `cd flutter && flutter analyze lib/services/secure_storage.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd flutter && git add lib/services/secure_storage.dart
git commit -m "feat(flutter): persistance guestRestaurantId dans SecureStorage"
```

---

### Task 6: Mode invité dans `UserProvider`

**Files:**
- Modify: `flutter/lib/providers/user_provider.dart`

- [ ] **Step 1: Ajouter l'état + la transition guest**

Dans `flutter/lib/providers/user_provider.dart`, ajouter le champ et le getter (sous `_isConnected`) :

```dart
  bool _isGuest = false;
  bool get isGuest => _isGuest;
```

Ajouter la méthode (après `init`) :

```dart
  /// Active le mode invité (pas de compte). Le restaurant est déjà chargé
  /// par l'appelant via RestaurantProvider.
  void enterGuestMode() {
    _isGuest = true;
    _isConnected = false;
    notifyListeners();
  }
```

- [ ] **Step 2: Restaurer le mode invité au démarrage**

Dans `init`, remplacer le bloc `if (accessToken == null) { notifyListeners(); return; }` par :

```dart
    final accessToken = await secureStorage.getAccessToken();
    if (accessToken == null) {
      final guestRestaurantId = await secureStorage.getGuestRestaurantId();
      if (guestRestaurantId != null && guestRestaurantId.isNotEmpty) {
        _isGuest = true;
        await restaurantProvider.tryLoadRestaurant(guestRestaurantId);
      }
      notifyListeners();
      return;
    }
```

- [ ] **Step 3: Sortir du mode invité à la connexion**

Dans `setUser`, ajouter `_isGuest = false;` dans la branche `user != null` (avant `notifyListeners()`). Dans `clearUserData`, ajouter `_isGuest = false;`.

- [ ] **Step 4: Analyser**

Run: `cd flutter && flutter analyze lib/providers/user_provider.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
cd flutter && git add lib/providers/user_provider.dart
git commit -m "feat(flutter): UserProvider.isGuest + restauration du mode invité au démarrage"
```

---

### Task 7: Services `register(restaurantId)` et `updateRestaurant`

**Files:**
- Modify: `flutter/lib/services/auth_service.dart`
- Modify: `flutter/lib/services/user_service.dart`

- [ ] **Step 1: `AuthService.register` gagne un paramètre optionnel**

Dans `flutter/lib/services/auth_service.dart`, remplacer la signature et le `data` du POST de `register` :

```dart
  Future<Map<String, dynamic>> register(
      String username, String password, {String? restaurantId}) async {
    try {
      final Response response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
        if (restaurantId != null) 'restaurantId': restaurantId,
      });
```

(Le reste de la méthode est inchangé.)

> Note : `AuthApiCall` (typedef de `auth_form.dart`) reste `(String, String)`. La Task 13 passe le `restaurantId` via une closure, donc cet ajout de paramètre **nommé optionnel** ne casse pas l'usage `apiCall: authService.register` ailleurs.

- [ ] **Step 2: `UserService.updateRestaurant`**

Dans `flutter/lib/services/user_service.dart`, ajouter (après `updateStatus`) :

```dart
  Future<bool> updateRestaurant(String restaurantId) async {
    try {
      final Response response = await _dio.put('/users/update-restaurant', data: {
        'restaurantId': restaurantId,
      });
      if (response.statusCode == 200) {
        logger.i('Restaurant updated: $restaurantId');
        return true;
      }
      logger.e('Invalid response: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to update restaurant: $e');
      return false;
    }
  }
```

- [ ] **Step 3: Analyser**

Run: `cd flutter && flutter analyze lib/services/auth_service.dart lib/services/user_service.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd flutter && git add lib/services/auth_service.dart lib/services/user_service.dart
git commit -m "feat(flutter): register(restaurantId) + UserService.updateRestaurant"
```

---

### Task 8: Intercepteur Dio — pas d'en-tête si token nul

**Files:**
- Modify: `flutter/lib/services/api_client.dart`

- [ ] **Step 1: Ne pas attacher `Authorization` quand le token est nul**

Dans `flutter/lib/services/api_client.dart`, dans `onRequest`, remplacer le bloc d'ajout du token :

```dart
          if (!options.path.contains('/login') &&
              !options.path.contains('/register')) {
            final token = await secureStorage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
```

- [ ] **Step 2: Analyser**

Run: `cd flutter && flutter analyze lib/services/api_client.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd flutter && git add lib/services/api_client.dart
git commit -m "fix(flutter): ne pas envoyer Authorization: Bearer null (mode invité)"
```

---

# PHASE C — Flutter (UI & flux)

### Task 9: Widget `RestaurantPicker`

**Files:**
- Create: `flutter/lib/widgets/welcome/restaurant_picker.dart`

- [ ] **Step 1: Créer le widget**

Créer `flutter/lib/widgets/welcome/restaurant_picker.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/services/restaurant_service.dart';

/// Écran de sélection d'un restaurant. Réutilisé par l'onboarding invité,
/// l'inscription et le changement de RU invité.
class RestaurantPicker extends StatefulWidget {
  const RestaurantPicker({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onSelected,
    this.initialRestaurantId,
  });

  final String title;
  final String confirmLabel;
  final String? initialRestaurantId;

  /// Appelé avec l'_id Mongo du restaurant choisi.
  final Future<void> Function(BuildContext context, String restaurantId) onSelected;

  @override
  State<RestaurantPicker> createState() => _RestaurantPickerState();
}

class _RestaurantPickerState extends State<RestaurantPicker> {
  List<RestaurantPartial> _restaurants = [];
  String? _selectedId;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialRestaurantId;
    _load();
  }

  Future<void> _load() async {
    final service = Provider.of<RestaurantService>(context, listen: false);
    try {
      final restaurants = await service.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _loading = false;
        if (_selectedId == null && restaurants.isNotEmpty) {
          _selectedId = restaurants.first.restaurantId;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les restaurants.';
      });
    }
  }

  Future<void> _confirm() async {
    final id = _selectedId;
    if (id == null) return;
    setState(() => _submitting = true);
    await widget.onSelected(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Choisissez votre restaurant universitaire',
                          style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Restaurant universitaire',
                        ),
                        initialValue: _selectedId,
                        items: _restaurants
                            .map((r) => DropdownMenuItem<String>(
                                  value: r.restaurantId,
                                  child: Text(r.name),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedId = value),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_selectedId == null || _submitting) ? null : _confirm,
                        child: _submitting
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(widget.confirmLabel),
                      ),
                    ],
                  ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/welcome/restaurant_picker.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd flutter && git add lib/widgets/welcome/restaurant_picker.dart
git commit -m "feat(flutter): widget RestaurantPicker réutilisable"
```

---

### Task 10: Destinations invité + logique `home`

**Files:**
- Modify: `flutter/lib/widgets/navigation/main_destinations.dart`
- Modify: `flutter/lib/main.dart`

- [ ] **Step 1: Ajouter `kGuestDestinations`**

Dans `flutter/lib/widgets/navigation/main_destinations.dart`, ajouter l'import en haut :

```dart
import 'package:ru_project/widgets/bus_widget.dart';
```

Ajouter à la fin du fichier :

```dart
/// Destinations réduites pour le mode invité : consultation seule.
final List<MainDestination> kGuestDestinations = [
  MainDestination(
    label: 'Carte',
    icon: Icons.map_outlined,
    builder: (_) => const SimpleMapWidget(),
  ),
  MainDestination(
    label: 'Menu',
    icon: Icons.restaurant_menu_outlined,
    builder: (_) => const MenuWidget(),
  ),
  MainDestination(
    label: 'Bus',
    icon: Icons.directions_bus_outlined,
    builder: (_) => const TransportTimeWidget(),
  ),
];
```

- [ ] **Step 2: Choisir le bon `home` au démarrage**

Dans `flutter/lib/main.dart`, ajouter l'import :

```dart
import 'package:ru_project/widgets/navigation/main_destinations.dart';
```

Remplacer le `home:` de `MyApp.build` :

```dart
      home: userProvider.isConnected
          ? const MainScaffold()
          : userProvider.isGuest
              ? const MainScaffold(destinations: kGuestDestinations)
              : const WelcomeWidget(),
```

- [ ] **Step 3: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/navigation/main_destinations.dart lib/main.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd flutter && git add lib/widgets/navigation/main_destinations.dart lib/main.dart
git commit -m "feat(flutter): destinations invité (Carte/Menu/Bus) + home selon mode"
```

---

### Task 11: Onboarding invité depuis l'écran d'accueil

**Files:**
- Modify: `flutter/lib/widgets/welcome/welcome.dart`

- [ ] **Step 1: Ajouter le bouton « Continuer sans compte »**

Dans `flutter/lib/widgets/welcome/welcome.dart`, ajouter les imports :

```dart
import 'package:provider/provider.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';
```

Ajouter, après le `Row` contenant les deux boutons (juste avant la fermeture de la `Column` des `children`), un bouton texte :

```dart
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _continueAsGuest(context),
                      child: const Text('Continuer sans compte'),
                    ),
```

Ajouter la méthode dans `_WelcomeWidget2State` :

```dart
  void _continueAsGuest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantPicker(
          title: 'Bienvenue',
          confirmLabel: 'Continuer',
          onSelected: (pickerContext, restaurantId) async {
            final secureStorage =
                Provider.of<SecureStorage>(pickerContext, listen: false);
            final userProvider =
                Provider.of<UserProvider>(pickerContext, listen: false);
            final restaurantProvider =
                Provider.of<RestaurantProvider>(pickerContext, listen: false);
            await secureStorage.storeGuestRestaurantId(restaurantId);
            await restaurantProvider.tryLoadRestaurant(restaurantId);
            userProvider.enterGuestMode();
            if (!pickerContext.mounted) return;
            Navigator.pushReplacement(
              pickerContext,
              MaterialPageRoute(
                builder: (_) => const MainScaffold(destinations: kGuestDestinations),
              ),
            );
          },
        ),
      ),
    );
  }
```

- [ ] **Step 2: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/welcome/welcome.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd flutter && git add lib/widgets/welcome/welcome.dart
git commit -m "feat(flutter): onboarding invité (Continuer sans compte -> picker)"
```

---

### Task 12: Actions invité dans `MainScaffold` (Se connecter / Changer de RU)

**Files:**
- Modify: `flutter/lib/widgets/main_scaffold.dart`

- [ ] **Step 1: Ajouter les imports**

Dans `flutter/lib/widgets/main_scaffold.dart`, ajouter :

```dart
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/navigation/main_destinations.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';
import 'package:ru_project/widgets/welcome/welcome.dart';
```

- [ ] **Step 2: Construire les actions selon le mode**

Dans `build`, après `final totalUnread = ...`, ajouter :

```dart
    final isGuest = context.watch<UserProvider>().isGuest;
```

Remplacer `actions: const [BugReportButton()],` de l'`AppBar` par :

```dart
        actions: [
          if (isGuest)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (value) {
                if (value == 'login') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeWidget()),
                  );
                } else if (value == 'change_ru') {
                  _changeGuestRestaurant(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'login', child: Text('Se connecter')),
                PopupMenuItem(value: 'change_ru', child: Text('Changer de RU')),
              ],
            ),
          const BugReportButton(),
        ],
```

- [ ] **Step 3: Ajouter le handler de changement de RU**

Ajouter la méthode dans `_MainScaffoldState` :

```dart
  void _changeGuestRestaurant(BuildContext context) {
    final secureStorage = Provider.of<SecureStorage>(context, listen: false);
    final restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RestaurantPicker(
          title: 'Changer de RU',
          confirmLabel: 'Valider',
          initialRestaurantId: restaurantProvider.restaurant?.restaurantId,
          onSelected: (pickerContext, restaurantId) async {
            await secureStorage.storeGuestRestaurantId(restaurantId);
            await restaurantProvider.tryLoadRestaurant(restaurantId);
            if (!pickerContext.mounted) return;
            Navigator.pop(pickerContext);
            setState(() {}); // rebuild de l'onglet courant
          },
        ),
      ),
    );
  }
```

> Note : `restaurantProvider.restaurant?.restaurantId` correspond ici au champ
> string `"r135"` du `RestaurantTmp` chargé (pas l'_id) ; il sert juste de valeur
> initiale d'affichage. La liste du picker (basée sur l'_id, cf. Task 2) re-sélectionne
> par défaut le premier item si l'initial ne matche pas — comportement acceptable.
> Le rechargement effectif utilise l'_id renvoyé par le picker. La carte se rafraîchit
> en revenant sur l'onglet Carte (FloorPlan se reconstruit).

- [ ] **Step 4: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/main_scaffold.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
cd flutter && git add lib/widgets/main_scaffold.dart
git commit -m "feat(flutter): actions invité (Se connecter / Changer de RU) dans MainScaffold"
```

---

### Task 13: Carte en lecture seule pour l'invité

**Files:**
- Modify: `flutter/lib/widgets/map_widget.dart`

- [ ] **Step 1: Calculer `isGuest` et conditionner le chargement des sessions**

Dans `_FloorPlanState`, ajouter un champ :

```dart
  late final bool isGuest;
```

Dans `initState`, après `userProvider = Provider.of<UserProvider>(context, listen: false);`, ajouter :

```dart
    isGuest = userProvider.isGuest;
```

Remplacer `getRestaurantData = machin();` par :

```dart
    getRestaurantData = isGuest ? Future<void>.value() : machin();
```

(En invité on ne charge pas les sessions ; `sectorSessions` reste `null`.)

- [ ] **Step 2: Masquer le FAB « Sessions » en invité**

Dans `build`, remplacer le bloc `Positioned(... FloatingActionButton.extended ... 'Sessions' ...)` par une version conditionnelle :

```dart
                if (!isGuest)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SectorsSessionsWidget(
                              restaurantId: restaurant.restaurantId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.groups),
                      label: const Text('Sessions'),
                    ),
                  ),
```

- [ ] **Step 3: Masquer le check-in dans le détail de secteur en invité**

`SectorInfoWidget` reçoit déjà `userProvider`. Dans son `build`, englober le bloc
`if (widget.sector.occupiedByMe) ... else ...` (les boutons « Se lever » / « S'assoir ici ? »)
par une garde non-invité. Concrètement, remplacer :

```dart
            // Bouton d'action: se lever si je suis assis, sinon s'asseoir
            if (widget.sector.occupiedByMe)
```

par :

```dart
            // Bouton d'action (masqué pour les invités): se lever / s'asseoir
            if (!widget.userProvider.isGuest && widget.sector.occupiedByMe)
```

et le `else` correspondant :

```dart
            else if (!widget.userProvider.isGuest)
```

(La section « Amis dans le secteur » reste : en invité `sessionsForSector` est `null`
et `friendsInArea` est vide → s'affiche « Aucun ami dans ce secteur. ». Pour éviter ce
message en invité, englober tout le bloc `if (isLoading) ... else if ... else ...` final
par `if (!widget.userProvider.isGuest) ...`, sinon afficher un `SizedBox.shrink()`.)

Appliquer cette dernière garde : remplacer le `if (isLoading)` final par :

```dart
            if (widget.userProvider.isGuest)
              const SizedBox.shrink()
            else if (isLoading)
```

- [ ] **Step 4: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/map_widget.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
cd flutter && git add lib/widgets/map_widget.dart
git commit -m "feat(flutter): carte en lecture seule pour le mode invité"
```

---

### Task 14: Inscription en 2 étapes (onboarding restaurant)

**Files:**
- Modify: `flutter/lib/widgets/welcome/register.dart`
- Modify: `flutter/lib/widgets/welcome/login.dart`

- [ ] **Step 1: Register en 2 étapes**

Remplacer tout le contenu de `flutter/lib/widgets/welcome/register.dart` par :

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/auth_service.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/widgets/main_scaffold.dart';
import 'package:ru_project/widgets/welcome/auth_form.dart';
import 'package:ru_project/widgets/welcome/restaurant_picker.dart';

/// Inscription en 2 étapes : 1) choix du restaurant, 2) identifiants.
class RegisterWidget extends StatefulWidget {
  const RegisterWidget({super.key, this.initialRestaurantId});

  /// Pré-sélection (ex: depuis le mode invité).
  final String? initialRestaurantId;

  @override
  State<RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget> {
  String? _restaurantId;

  @override
  void initState() {
    super.initState();
    _restaurantId = widget.initialRestaurantId;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Étape 2 : identifiants. La closure capture le restaurantId choisi.
    if (_restaurantId != null) {
      return AuthFormWidget(
        title: 'S\'inscrire',
        buttonText: 'S\'inscrire',
        apiCall: (username, password) =>
            authService.register(username, password, restaurantId: _restaurantId),
        onSuccess: (response, context) async {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final restaurantProvider =
              Provider.of<RestaurantProvider>(context, listen: false);
          final secureStorage =
              Provider.of<SecureStorage>(context, listen: false);
          final User user = response['user'];
          userProvider.setUser(user);
          await secureStorage.clearGuestRestaurantId();
          await restaurantProvider.tryLoadRestaurant(user.restaurantId);
          if (!context.mounted) return;
          Provider.of<ChatConnection>(context, listen: false).connect();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScaffold()),
          );
        },
      );
    }

    // Étape 1 : choix du restaurant.
    return RestaurantPicker(
      title: 'S\'inscrire',
      confirmLabel: 'Suivant',
      onSelected: (pickerContext, restaurantId) async {
        setState(() => _restaurantId = restaurantId);
      },
    );
  }
}
```

> `RestaurantPicker` est un `Scaffold` ; ici il est rendu directement comme corps de
> la page d'inscription (qui est déjà poussée avec son propre `Scaffold`/AppBar par
> `welcome.dart`). Cela produit un AppBar imbriqué acceptable ; si tu préfères, retire
> l'AppBar de `RegisterWidget`'s parent — non requis pour la correction fonctionnelle.

- [ ] **Step 2: Nettoyer le mode invité à la connexion (login)**

Dans `flutter/lib/widgets/welcome/login.dart`, dans `onSuccess`, ajouter après
`userProvider.setUser(user);` :

```dart
        final secureStorage = Provider.of<SecureStorage>(context, listen: false);
        await secureStorage.clearGuestRestaurantId();
```

Ajouter l'import en haut :

```dart
import 'package:ru_project/services/secure_storage.dart';
```

- [ ] **Step 3: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/welcome/register.dart lib/widgets/welcome/login.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd flutter && git add lib/widgets/welcome/register.dart lib/widgets/welcome/login.dart
git commit -m "feat(flutter): inscription en 2 étapes avec onboarding restaurant"
```

---

### Task 15: Câbler le changement de RU dans les réglages (connecté)

**Files:**
- Modify: `flutter/lib/widgets/settings_widget.dart`

- [ ] **Step 1: Initialiser sur le resto réel + persister à la sélection**

Remplacer le contenu de `flutter/lib/widgets/settings_widget.dart` par :

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/user_service.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  List<RestaurantPartial> _restaurants = [];
  String? _selectedRestaurantId;
  bool _saving = false;
  late final RestaurantService _restaurantService;
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _restaurantService = Provider.of<RestaurantService>(context, listen: false);
    _userService = Provider.of<UserService>(context, listen: false);
    // Initialise sur le restaurant réel de l'utilisateur (_id Mongo).
    _selectedRestaurantId =
        Provider.of<UserProvider>(context, listen: false).user?.restaurantId;
    _loadRestaurants();
  }

  void _loadRestaurants() async {
    try {
      final restaurants = await _restaurantService.getRestaurants();
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        // Si l'utilisateur n'a pas de resto, défaut = premier de la liste.
        if (_selectedRestaurantId == null && restaurants.isNotEmpty) {
          _selectedRestaurantId = restaurants.first.restaurantId;
        }
      });
    } catch (e) {
      // En cas d'erreur, la liste reste vide
    }
  }

  Future<void> _onChanged(String? value) async {
    if (value == null) return;
    setState(() {
      _selectedRestaurantId = value;
      _saving = true;
    });
    final ok = await _userService.updateRestaurant(value);
    if (ok && mounted) {
      await Provider.of<RestaurantProvider>(context, listen: false)
          .loadRestaurant(value);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Restaurant mis à jour' : 'Échec de la mise à jour'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paramètres'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choix de votre restaurant universitaire',
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Restaurant universitaire',
                ),
                initialValue: _selectedRestaurantId,
                items: _restaurants.map((restaurant) {
                  return DropdownMenuItem<String>(
                    value: restaurant.restaurantId,
                    child: Text(restaurant.name),
                  );
                }).toList(),
                onChanged: _saving ? null : _onChanged,
              ),
            ),
            if (_saving) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Analyser**

Run: `cd flutter && flutter analyze lib/widgets/settings_widget.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd flutter && git add lib/widgets/settings_widget.dart
git commit -m "feat(flutter): câbler le changement de RU dans les réglages (persiste via update-restaurant)"
```

---

### Task 16: Vérification finale (analyse globale + checklist manuelle)

**Files:** aucun (vérification)

- [ ] **Step 1: Analyse globale Flutter**

Run: `cd flutter && flutter analyze`
Expected: aucune **nouvelle** erreur introduite par ce lot (comparer au baseline d'`AUDIT.md`).

- [ ] **Step 2: Suite backend complète**

Run: `cd backend && npx tsc --noEmit && npm test`
Expected: toutes les suites PASS, `tsc` propre.

- [ ] **Step 3: Checklist manuelle (app lancée)**

Vérifier :
1. Premier lancement sans compte → « Continuer sans compte » → choix resto → 3 onglets (Carte/Menu/Bus).
2. Carte invité : plan visible, **pas** de bouton s'asseoir/se lever, **pas** de FAB Sessions, **pas** de liste d'amis.
3. Menu et Bus accessibles en invité.
4. Menu « compte » (icône) → « Se connecter » → login → bascule vers l'app complète (5 onglets).
5. Relancement en invité → arrive directement sur l'app (resto mémorisé), pas de ré-onboarding.
6. « Changer de RU » (invité) → choix → retour Carte rafraîchie.
7. Inscription : étape 1 (resto) → étape 2 (identifiants) → compte créé ; `Profil`/Carte reflètent le bon RU.
8. Connecté : Réglages → changer de RU → snackbar succès → persiste après redémarrage de l'app.

- [ ] **Step 4: Commit éventuel de corrections**

Si la checklist révèle un défaut, le corriger et committer avec un message `fix(flutter): ...`.

---

## Self-Review (rempli par l'auteur du plan)

**1. Couverture de la spec :**
- §3.1 routes publiques → Task 1 ✅ ; §3.2 register restaurantId → Task 3 ✅ ; §3.3 update-restaurant → Task 4 ✅
- §4.1 persistance → Task 5 ✅ ; §4.2 isGuest → Task 6 ✅ ; §4.3 dio null token → Task 8 ✅
- §5.1 RestaurantPicker → Task 9 ✅ ; §5.2 onboarding invité → Task 11 ✅ ; §5.3 register 2 étapes → Task 14 ✅
- §6 nav invité (3 onglets + Se connecter + Changer de RU) → Tasks 10 & 12 ✅
- §7 carte lecture seule → Task 13 ✅
- §8 réglages câblés → Task 15 ✅
- §9 tests → backend Tasks 1-4 + Task 16 ✅
- **Incohérence d'identifiant restaurant** (non explicite dans la spec mais bloquante) → traitée Task 2 ✅

**2. Placeholders :** aucun TODO/TBD ; tout le code des steps est fourni.

**3. Cohérence des types/signatures :** `restaurantId` = `_id` Mongo partout après Task 2 ; `register(username, password, {restaurantId})` cohérent entre Task 7 (déf), Task 14 (closure) ; `updateRestaurant(String)` Task 7 ↔ Task 15 ; `enterGuestMode()` Task 6 ↔ Task 11 ; `kGuestDestinations` Task 10 ↔ Tasks 11/12.
