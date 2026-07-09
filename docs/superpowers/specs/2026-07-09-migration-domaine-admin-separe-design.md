# Migration de domaine + séparation de l'admin

**Date :** 2026-07-09
**Statut :** validé (design)

## Contexte

Passage en prod du domaine `ru.api.mehmetates.fr` vers `api.ru.leomaugeri.fr`.
C'est l'occasion de :
1. sortir AdminJS (dashboard back-office) de l'API principale, pour le servir
   sur `admin.ru.leomaugeri.fr`,
2. nettoyer les routes/CORS/rate-limiting liés à cette séparation,
3. mettre à jour la config Flutter vers le nouveau domaine.

## Constat sur le code actuel

- `backend/src/server.ts` fait tourner **un seul process** Express + Socket.IO
  (port 5000) qui monte à la fois l'API (`/api/*`), AdminJS (`/admin`, via
  `modules/admin.ts`) et Socket.IO (path par défaut `/socket.io/`).
- `modules/admin.ts` contient un `customRouter` déclaré mais **jamais monté**
  (dead code) — l'AdminJS router est en fait monté directement dans
  `adminJsSetup` via `app.use(admin.options.rootPath, adminRouter)`.
- `app.ts` a déjà, en dur, des routes `handleImageRequest` en double : préfixées
  `/admin/...` et `/admin/api/...`, et des variantes bare `/resources/...` /
  `/api/resources/...` — seules les deux premières sont utilisées aujourd'hui
  (rootPath AdminJS = `/admin`).
- Le rate-limiter global (`app.ts`) exclut `/admin` de sa limite (`skip`), et
  `/admin/login` a son propre `authLimiter`.
- `@socket.io/admin-ui` (`instrument()` dans `utils/socket.ts`) est un outil
  **différent** d'AdminJS — un dashboard de monitoring pour Socket.IO
  (https://admin.socket.io). Il reste inchangé, attaché au process API.
- Flutter (`flutter/lib/config.dart`) code en dur `ru.api.mehmetates.fr` pour
  `apiUrl` et `serverUrl` (ce dernier utilisé aussi pour la connexion
  Socket.IO dans `chat_connection.dart`, via `io.io(Config.serverUrl, ...)`).
- Les routes REST du chat (`/api/socket/*`, via `socket.routes.ts`) et la
  connexion websocket elle-même (path par défaut `/socket.io/`) n'ont **aucun
  bug** : elles restent sur le même domaine que l'API, dans le même process —
  pas de changement structurel nécessaire ici, juste la même mise à jour de
  domaine que le reste de l'API.

## Décisions validées

- **Admin dans un process Node séparé** (pas un simple routage par Host sur le
  même process) : nouveau point d'entrée `backend/src/adminServer.ts` dans le
  même repo/dossier backend (réutilise `config.ts`, les modèles Mongoose, la
  connexion Mongo — pas de duplication de code). Nouveau process pm2
  `ru_project_admin`, port dédié `5001` (variable d'env `ADMIN_PORT`).
- **rootPath AdminJS devient `/`** (au lieu de `/admin`) puisque le sous-domaine
  lui est entièrement dédié : URLs `admin.ru.leomaugeri.fr` directement.
- **Sockets restent sur `api.ru.leomaugeri.fr`**, même process que l'API, path
  par défaut `/socket.io/` inchangé — pas de sous-domaine dédié (n'aurait de
  sens que si le socket tournait sur un process séparé, ce qui n'est pas le
  cas).
- **`@socket.io/admin-ui` n'est pas touché** — reste sur le process API.
- **nginx** : deux `server{}` blocks fournis en annexe de ce doc (à poser côté
  serveur, hors scope de cette session — pas d'accès au serveur de prod
  depuis ici).

## Changements — backend

### `backend/src/adminServer.ts` (nouveau)
Mini serveur Express dédié à l'admin :
- `helmet`, `compression`, `morgan` (log dédié, ex. `logs/admin-access.log` en
  prod) — repris à l'identique du pattern de `server.ts`/`app.ts` mais sans
  CORS (pas d'appel cross-origin attendu : l'admin est self-contained, servi
  et consommé depuis le même host).
- Connexion Mongoose propre (même `mongoUri`).
- Monte `adminJsSetup` (voir ci-dessous) à la racine.
- Monte les 2 routes `handleImageRequest` nécessaires en variante bare :
  `/resources/:model/records/:recordId/uploads/*path` et
  `/resources/uploads/*path`.
- `app.listen(process.env.ADMIN_PORT || 5001, ...)`.
- Pas de Socket.IO, pas de routes `/api/*`, pas de swagger.

### `backend/src/modules/admin.ts`
- `rootPath: '/'` au lieu de `'/admin'`.
- Suppression du `customRouter` mort (jamais utilisé).
- Le rate-limiting spécifique au login admin (actuellement `authLimiter` sur
  `/admin/login` dans `app.ts`) doit être recréé dans `adminServer.ts` sur
  `/login` (nouveau rootPath).
- Reste inchangé : `authenticate` importé directement depuis
  `routes/auth/auth.service.js` (pas d'appel HTTP, juste un import de
  fonction — fonctionne tel quel dans le nouveau process car même repo).

### `backend/src/app.ts` / `backend/src/server.ts`
- Suppression : import + appel de `adminJsSetup`.
- Suppression : les 8 lignes `handleImageRequest` liées à `/admin*` /
  `/api/resources/*` (dead une fois l'admin sorti du process API — les
  variantes bare partent dans `adminServer.ts`, pas ici).
- Suppression : `app.use('/admin/login', authLimiter)`.
- Suppression : le `skip` sur `/admin` dans le rate-limiter global (plus de
  trafic `/admin` sur ce process).

### `package.json`
- Nouveau script `"dev:admin": "tsx watch src/adminServer.ts"`.
- Le build existant (`tsc -p tsconfig.build.json`) compile déjà tout `src/`,
  donc `dist/adminServer.js` sera généré automatiquement — pas de script de
  build séparé nécessaire.

### Variables d'environnement (prod, à poser manuellement sur le serveur — pas
dans ce repo)
- `ADMIN_PORT=5001`
- `CORS_ORIGINS` de l'API principale : mettre à jour avec
  `https://api.ru.leomaugeri.fr` (et toute origine frontend web existante).
  Rien à ajouter côté admin (same-origin).

## Changements — Flutter

`flutter/lib/config.dart` :
```dart
apiUrl    = "https://api.ru.leomaugeri.fr/api"
serverUrl = "https://api.ru.leomaugeri.fr/"
```
Aucun autre fichier ne référence l'ancien domaine (vérifié par recherche
globale — seul `config.dart` contenait `mehmetates`).

## nginx (à poser côté serveur, hors scope de cette session)

Deux `server{}` blocks distincts, un par sous-domaine, chacun avec son propre
certificat TLS (ex. via certbot) :

- `api.ru.leomaugeri.fr` → proxy `127.0.0.1:5000`, avec en plus un `location
  /socket.io/ { ... }` dédié qui propage les en-têtes d'upgrade websocket
  (`Upgrade`, `Connection: upgrade`, HTTP/1.1).
- `admin.ru.leomaugeri.fr` → proxy `127.0.0.1:5001`, proxy HTTP classique (pas
  de websocket).

Le contenu exact des blocks sera fourni en pièce jointe au plan
d'implémentation (fichier `nginx/*.conf.example` dans le repo, à copier
manuellement sur le serveur — cette session n'a pas accès au serveur de
prod).

## Hors scope

- `@socket.io/admin-ui` (monitoring Socket.IO) : inchangé.
- Aucun bug fonctionnel connu sur les routes socket : pas de changement de
  path/événements, juste le changement de domaine.
- Déploiement effectif (DNS, certbot, `pm2 start`, mise à jour du `.env` prod) :
  documenté mais pas exécuté depuis cette session.

## Tests

- Tests backend existants (`npm test`) ne doivent pas référencer les routes
  `/admin` retirées de `app.ts`/`server.ts` — à vérifier après coup.
- Pas de nouveau test automatisé prévu pour `adminServer.ts` (pas de suite
  existante pour AdminJS aujourd'hui) — vérification manuelle (`npm run
  dev:admin` + connexion au dashboard) suffisante.
