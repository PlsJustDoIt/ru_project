# Audit — ru_project

Audit du **2026-10-05** (backend Node/Express/TS + app Flutter), centré sur les
parcours utilisateur, le mode invité et le chat. Il remplace l'audit du
2026-05-29, dont les points de sécurité prioritaires ont été traités depuis
(voir « Suivi de l'audit précédent » en bas).

**État global après cette passe :**
- Backend : `tsc --noEmit` et `eslint` propres, **198 tests** Jest passent (24 suites).
- Flutter : `flutter analyze` = **0 problème**, **36 tests** passent, `flutter build web` OK.

Légende : ✅ corrigé dans cette passe · 🔶 ouvert (à planifier).

---

## 🔴 Chat — sécurité (backend)

| # | Constat | Statut |
|---|---|---|
| 1 | **Aucun contrôle d'accès aux rooms.** `GET /socket/messages`, `POST /send-message`, `/send-audio`, `DELETE /delete-message`, `/delete-all-messages` ne vérifiaient pas que l'utilisateur fait partie de la room : n'importe quel compte pouvait lire/écrire dans une conversation privée en devinant son nom (`idA_idB`, ids visibles via la recherche d'amis). | ✅ `resolveRoomForUser` (`socket.service.ts`) : Global ouvert à tous, room privée réservée à ses 2 participants (403 sinon). |
| 2 | **Suppression de n'importe quel message.** `delete-message` supprimait par id sans vérifier l'auteur ni la room. | ✅ Auteur uniquement (ou admin/modérateur), et le message doit appartenir à la room. |
| 3 | **Vider le Global** était possible pour tout utilisateur. | ✅ Réservé au staff ; une conversation privée peut être vidée par ses participants. |
| 4 | **`join_room` sans vérification** : on pouvait rejoindre (et donc écouter en temps réel) la room de deux autres utilisateurs. | ✅ L'émetteur doit être l'un des participants ; création d'une room privée seulement entre amis. |
| 5 | **Admin UI Socket.IO exposée sans auth** (`instrument(io, { auth: false })`), y compris en production : liste des sockets, rooms et événements. | ✅ Activée uniquement hors production. |
| 6 | Pas de limite de taille des messages. | ✅ Texte « trimé », 1–2000 caractères (400 sinon). |

## 🟠 Chat — fiabilité

| # | Constat | Statut |
|---|---|---|
| 7 | **Historique figé** : `getMessagesByRoomId` triait par date croissante puis `limit(50)` → renvoyait les 50 **premiers** messages. Au-delà de 50 messages, les nouveaux n'apparaissaient plus au rechargement. | ✅ 50 plus récents (tri décroissant puis remis en ordre) + pagination `?before=` / `hasMore`. |
| 8 | **Conversation vide = spinner infini** (`if (_messages.isEmpty) CircularProgressIndicator`) : impossible d'envoyer le premier message à un ami. | ✅ État de chargement distinct, écran vide « Dis bonjour 👋 », écran d'erreur avec « Réessayer ». |
| 9 | **Un simple tap supprimait le message** (y compris celui des autres, côté UI). | ✅ Appui long → feuille « Copier / Supprimer » (suppression seulement de ses messages, avec confirmation et restauration si échec). |
| 10 | Suppression temps réel : index de `_messages` (ordre inversé) utilisé sur `chatController.messages` → mauvais message retiré. « Tout supprimer » ne vidait pas le contrôleur. | ✅ Suppression par id ; liste unique (le contrôleur). |
| 11 | Envoi optimiste sans retour d'échec : un message non envoyé restait affiché comme envoyé. | ✅ Statuts *envoi / envoyé / échec* ; un message en échec se touche pour « Réessayer » ou « Annuler l'envoi ». |
| 12 | **Diffusion dépendante de la socket de l'expéditeur** : `emitToRoom` passait par `socket.to(room)` de l'expéditeur ; s'il n'était pas connecté en temps réel (web, socket tombée), personne ne recevait le message. | ✅ `io.to(room).except(user:<id>)`. |
| 13 | **Une seule socket par utilisateur** (`Map<userId, socketId>`) : un 2ᵉ appareil/onglet écrasait le 1ᵉʳ (notifications perdues), et la déconnexion de l'un marquait l'utilisateur hors ligne. | ✅ Room personnelle `user:<id>` + `Map<userId, Set<socketId>>` ; `userOffline` émis à la dernière socket fermée. Doublon de handler `disconnect` supprimé. |
| 14 | **Reconnexion sans re-join** : après une coupure, le serveur oubliait la room → plus aucun message temps réel. | ✅ `ChatConnection` rejoue le dernier `join_*` à chaque connexion et émet `ChatResynced` → l'écran recharge l'historique manqué. |
| 15 | **Token expiré (1 h) au handshake** : socket refusée définitivement. Token passé dans l'URL (`query`). | ✅ `connect_error` d'auth → refresh du token puis réouverture (une fois) ; token dans `auth`. Une socket refusée est recréée au prochain `connect()`. |
| 16 | « Mes » messages identifiés par **pseudo** : après un changement de pseudo, ses anciens messages passaient « à gauche » et comptaient comme non-lus. | ✅ Payload enrichi (`userId`, `avatarUrl`, `roomName`) ; identification par id. |
| 17 | Global : impossible de savoir qui parle (ni pseudo ni avatar). | ✅ Pseudo + avatar des autres participants dans le Global. |
| 18 | Inbox : aperçus figés jusqu'au retour sur l'onglet, ordre fixe, « alice : … » même pour ses propres messages, `timeAgo` erroné (« un l'instant », « 1 jours »). | ✅ Aperçus en direct, tri par dernière activité, « Toi : … », pull-to-refresh qui recharge aussi les amis, `timeAgo` corrigé. |
| 19 | Textes d'erreur en anglais (« Failed to fetch messages »), composer « Type a message ». | ✅ Français. |

## 🟠 Mode invité

| # | Constat | Statut |
|---|---|---|
| 20 | **Signaler un bug échouait toujours en invité** (route protégée) ; le nom de fichier de capture utilisait `req.user.id` → crash serveur sans compte. | ✅ `POST /users/send-bug-report` accepte l'anonyme (`optionalAuth`, limiteur dédié 10/15 min) ; `BugReport.user` optionnel. |
| 21 | « On y mange ? » affiché aux invités mais **sans effet**. | ✅ Remplacé par « Crée un compte pour prévenir tes amis » (RU déjà choisi repris). |
| 22 | **Carte figée sur l'ancien RU** après « Changer de RU » (FloorPlan mémorisait le restaurant). | ✅ `FloorPlan` reconstruit à chaque changement de RU. |
| 23 | Menu : en changeant de RU, l'ancien menu restait affiché pendant le chargement et la page du jour pouvait dépasser la nouvelle liste. | ✅ Spinner + retour au 1ᵉʳ jour ; réponses obsolètes ignorées ; bouton « Actualiser » sur l'écran vide. |
| 24 | Invité → « Se connecter » remplaçait l'appli invitée par l'accueil (retour impossible) ; `RegisterWidget(initialRestaurantId)` existait mais **n'était jamais utilisé** : il fallait re-choisir son RU. | ✅ Menu de compte : *Se connecter*, *Créer un compte* (RU pré-rempli), *Changer de RU*, *Quitter le mode invité* ; pages empilées au-dessus de l'appli invitée. |
| 25 | Messages d'aide inadaptés (« Choisis ton RU dans Plus › Paramètres » alors que l'invité n'a pas d'onglet Plus) ; aucune explication de ce qui nécessite un compte. | ✅ Textes adaptés, bandeau invité masquable, indication dans la fiche secteur et sur l'accueil. |

## 🟠 Parcours & session

| # | Constat | Statut |
|---|---|---|
| 26 | **La déconnexion ne supprimait pas les tokens** : au redémarrage, l'utilisateur était reconnecté automatiquement. La socket de chat restait ouverte et les non-lus survivaient (suppression de compte idem). | ✅ `SessionManager` : un seul point pour ouvrir/fermer une session (tokens, RU invité, socket, non-lus, état utilisateur). Confirmation avant déconnexion. |
| 27 | **Pile de navigation incohérente** : `pushReplacement` depuis une page empilée laissait l'accueil sous l'appli (bouton retour → écran d'accueil, ou appli connectée sous l'accueil après déconnexion). | ✅ `navigation/app_navigation.dart` : `goToHome` / `goToGuestHome` / `goToWelcome` vident la pile. |
| 28 | **Mauvais mot de passe = erreur 500** côté serveur, et l'appli n'affichait que « Erreur de connexion » (Dio lève une exception sur 4xx, les branches d'erreur d'`AuthService` étaient mortes). « Pseudo déjà pris » n'était jamais affiché non plus. | ✅ Login → 401 `{ message, field }` (même message que le pseudo existe ou non) ; erreurs serveur traduites et affichées sous le bon champ. |
| 29 | Login : un échec du chargement des amis (non bloquant) faisait **afficher une erreur alors que la connexion avait réussi**. | ✅ Chargements annexes best-effort dans `SessionManager.openSession`. |
| 30 | Formulaire : double soumission possible, pas d'indicateur de chargement, erreur serveur collée au champ même après correction, pas d'affichage du mot de passe. | ✅ Bouton désactivé + spinner, erreurs effacées à la saisie, œil afficher/masquer, autofill, « Entrée » pour valider. |
| 31 | Intercepteur HTTP : refresh tenté sur les erreurs du login, refresh concurrents multiples, boucle potentielle, session expirée = `clearUserData` seul (tokens et socket conservés). | ✅ Pas de refresh sur `/auth/*`, refresh partagé, une seule ré-tentative, session expirée → nettoyage complet + retour à l'accueil avec message. |
| 32 | **Rate limiting partagé par tous derrière nginx** : sans `trust proxy`, `req.ip` = IP du proxy → 50 req/min et 10 tentatives de login / 15 min **pour toute l'appli**. | ✅ `trust proxy` = 1 en production (surcharge : `TRUST_PROXY`). |
| 33 | Réglages : après un changement de RU, les Réglages rouverts réaffichaient l'ancien. | ✅ `user.restaurantId` mis à jour localement. |

---

## 🔶 Points ouverts

- **Démarrage hors ligne** : `UserProvider.init` traite un échec réseau sur `/users/me` comme une session invalide → l'accueil s'affiche (les tokens restent, l'appli se reconnecte au lancement suivant). Distinguer « réseau » de « session refusée ».
- **Bandeaux in-app du Global** : chaque message du Global déclenche un bandeau et un non-lu ; à grande échelle ce sera bruyant (prévoir une sourdine du Global).
- **`getConversationsSummary`** fait une requête par room (N+1) ; à agréger quand le nombre d'amis grandira.
- **Pagination par date** : deux messages à la même milliseconde à la frontière d'une page peuvent être sautés (pagination par `_id` plus robuste).
- **Swagger** : documente encore `/socket/chat-room` et `/socket/send-chat-room`, qui n'existent pas.
- **Carte** : l'image de fond `map_r135.jpg` est utilisée pour tous les RU.
- **Politique de mot de passe** : 3–32 caractères, sans règle de complexité.
- **Tests Flutter** : couverture unitaire (connexion chat, notifications, modèles, navigation) mais aucun test d'intégration des écrans de chat / connexion.
- **Présence globale** : `getAllSectorsSessions` expose la présence de tous les utilisateurs à tout compte authentifié (à confirmer côté produit).

## Suivi de l'audit précédent (2026-05-29)

Vérifiés corrigés : secrets/tokens retirés des logs, échappement de la regex de recherche, nom de fichier d'upload assaini, bypass d'auth par sous-chaîne, erreur brute renvoyée au client, CORS restreint en production, secret de repli `'truc'`, rate limiting de l'admin, requête `tmp_sectorsSessions` gâchée, fichiers Flutter morts (`web_socket_service.dart`, `old_map_widget_2.dart`, …), `flutter analyze` à 0.
