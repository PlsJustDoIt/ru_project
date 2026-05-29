# Audit — ru_project

Audit complet (backend Node/Express/TS + app Flutter), réalisé le **2026-05-29**.

**État global au moment de l'audit :** sain.
- Backend : `tsc --noEmit` propre, **153 tests** Jest passent (15 suites).
- Flutter : `flutter analyze` = **55 problèmes, 0 erreur** (warnings/info).

Les points ci-dessous sont de la **dette préexistante**, pas des régressions. Priorité indiquée par section. Chaque entrée référence le fichier concerné pour faciliter la correction.

---

## 🔴 Sécurité — backend (priorité haute)

1. **Secrets loggés en clair.** `server.ts` logge `MONGO_URI` (avec identifiants) et `GINKO_API_KEY` en niveau info ; `auth.controller.ts` logge les refresh/access tokens bruts. Ces données atterrissent dans `logs/` et `access.log`.
   → Retirer tout log de secret/token.
2. **Production en HTTP simple.** Le bloc HTTPS est commenté dans `server.ts` ; côté Flutter, `config.dart` pointe vers `http://86.219.194.18:5000` (IP en dur). Mots de passe et JWT transitent en clair.
   → Mettre du TLS (reverse proxy, ou réactiver le serveur https commenté).
3. **Injection regex / ReDoS.** `user.controller.ts` `searchUsers` construit `new RegExp(query, 'i')` à partir de l'entrée utilisateur brute.
   → Échapper l'entrée (ou `$text` / regex ancrée échappée).
4. **Traversée de chemin à l'upload de bug report.** `utils/multer.ts` (`storageScreenshotBugReport`) écrit `file.originalname` tel quel comme nom de fichier.
   → Générer/assainir le nom. (L'upload d'avatar est sûr : il utilise `userId`.)
5. **Bypass d'auth par sous-chaîne.** `middleware/auth.ts` saute l'auth quand `req.url.includes('/token')` — match de sous-chaîne, pas la route de refresh exacte.
   → Comparer le chemin exact.
6. **Erreur brute renvoyée au client.** `middleware/auth.ts` renvoie `{ error: err }` (l'objet d'erreur capturé) sur un 403.
7. **CORS grand ouvert.** `app.ts` utilise `cors()` sans config (toutes origines) ; Socket.IO retombe sur `origin: '*'` si `CLIENT_URL` n'est pas défini. CSP Helmet désactivé (`contentSecurityPolicy: false`).
8. **Secret de repli en dur.** `modules/admin.ts` : le secret cookie/session retombe sur le littéral `'truc'` si `JWT_ACCESS_SECRET` est absent. Les secrets JWT ne sont pas validés au démarrage (seul `GINKO_API_KEY` l'est).
   → Valider tous les secrets requis dans `config.ts`.
9. **Admin exclu du rate limiting.** `app.ts` : `skip: req.path.startsWith('/admin')` retire toute protection anti-brute-force sur le login admin.
10. **Politique de mot de passe faible.** `auth.service.ts` impose 3–32 caractères ; le max à 32 est inhabituellement restrictif et il n'y a aucune règle de complexité.

---

## 🟠 Correction / vie privée

- **Fuite de présence.** `getAllSectorsSessions` (`ru.controller.ts`) expose la présence de **tous** les utilisateurs dans les secteurs à n'importe quel utilisateur authentifié — `getSectorsSessions` est la variante filtrée aux amis. À confirmer : est-ce voulu que ce soit public à tous ?
- **Requête DB gâchée.** `ru.controller.ts` calcule `tmp_sectorsSessions` (un `SectorSession.find().populate()` complet) puis ne l'utilise jamais, à chaque appel de `getSectorsSessions`.
- **Filtre de taille mort.** `multer.ts` `fileFilter` teste `file.size`, qui est `undefined` à ce stade — la branche est morte (c'est l'option `limits` qui applique réellement la limite).
- **Duplication.** `getSectorsSessions` et `getAllSectorsSessions` sont des pipelines d'agrégation quasi identiques — à factoriser.

---

## 🟡 Code mort / dette technique

### Flutter
- **Fichiers non référencés** (suppression possible après confirmation) : `services/web_socket_service.dart`, `services/cache_service.dart`, `widgets/old_map_widget_2.dart`, `widgets/chatgpt_map_widget.dart`, `widgets/example_search_widget.dart`.
- **Atteints seulement via imports inutilisés / l'onglet Debug** : `widgets/old_map_widget.dart`, `widgets/video_widget.dart`, `widgets/test_statefull.dart`.
- **`providers/menu_provider.dart`** : défini mais jamais enregistré dans `main.dart` ni utilisé.
- **Deux implémentations socket** : `socket_service.dart` est la vivante ; `web_socket_service.dart` est orpheline.
- `flutter analyze` (55 issues, 0 erreur) :
  - `use_build_context_synchronously` à travers des `await` (risque de crash réel) : `welcome/auth_form.dart`, `friends_request_widget.dart`, `friends_widget.dart`.
  - Dépréciations : `withOpacity` (→ `withValues`), FormField `value` (→ `initialValue`), `dart:html` dans `audio_player_widget.dart`.
  - `chat_ui.dart` : import dupliqué, champ `_recordPath` inutilisé, imports d'implémentation `lib/src`.
  - Nombreux imports inutilisés (`tab_bar_widget.dart`, `auth_form.dart`, `debug_widget.dart`, …) → `dart fix --apply`.

### Backend
- **ESLint : 12 erreurs / 3 warnings** (non bloquant) — surtout `preserve-caught-error` (re-throw sans `cause`) dans `models/user.ts`, `ginko/ginko.service.ts`, `socket/socket.service.ts`, `utils/fileSystem.ts` ; variables inutilisées (`tmp_sectorsSessions`, `isProduction` dans `ginko.controller.ts`) ; un souci de style dans `multer.ts`.
- **Blocs commentés morts** laissés dans `utils/socket.ts` (doublon `emitToUser`), `server.ts` (bloc https), `config.ts`.
- **Couverture de tests inégale** : `routes/sector` ~31 %, `utils/fileSystem.ts` 0 %, `utils/multer.ts` ~63 % ; bien couverts : `routes/socket` et `routes/user` (~85 %+).

---

## Suggestions de séquencement

1. **Rapide & fort impact** : retirer les secrets/tokens des logs (#1), assainir le nom de fichier d'upload (#4), corriger le bypass d'auth par sous-chaîne (#5).
2. **Config/infra** : TLS en prod (#2), valider les secrets au démarrage + supprimer le repli `'truc'` (#8), restreindre CORS (#7).
3. **Robustesse** : échapper la regex de recherche (#3), confirmer/protéger l'endpoint de présence globale, supprimer la requête `tmp_sectorsSessions` gâchée.
4. **Nettoyage** : supprimer le code mort Flutter, lancer `dart fix --apply`, corriger les `use_build_context_synchronously`, résoudre les erreurs ESLint.
