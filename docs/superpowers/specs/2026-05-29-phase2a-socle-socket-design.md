# Phase 2a — Socle chat : socket unique persistante — Design

**Date :** 2026-05-29
**Type :** spec d'implémentation (premier sous-chantier de la Phase 2)
**Statut :** validée — à décomposer en plan d'implémentation

---

## Contexte

La Phase 2 (chat) de la [feuille de route](2026-05-29-roadmap-ameliorations-appli-ru-design.md) regroupe 4 sous-chantiers : **2a socle**, 2b boîte de réception unifiée, 2c notifs in-app, 2d vocal complet. Ce spec ne couvre que **2a**, la fondation qui capte ~70 % du bénéfice technique. Les autres sous-chantiers auront chacun leur cycle spec → plan → implémentation.

### État actuel (vérifié dans le code)

- `flutter/lib/services/socket_service.dart` est **uniquement un wrapper REST** (Dio) : `getMessagesFromRoom`, `sendMessageToRoom`, `deleteMessage`, `deleteMessages`. Il **ne gère pas** la connexion Socket.IO.
- La socket vivante est créée **dans l'état du widget `ChatUi`** (`initState` → `connectToServer`, `dispose` → `disconnectFromServer`). Conséquences : reconnexion + spinner « Chargement… » à chaque écran ; l'appli est aveugle aux autres rooms dès qu'on change d'écran.
- Deux points d'entrée : l'onglet **Messages** (`main_destinations.dart` → `ChatUi(roomName: 'Global')`) et l'onglet **Amis** (`friends_widget.dart:282` → `ChatWidget`, plein écran avec AppBar retour).

### Bugs réels mis au jour (à corriger en 2a)

1. **Jointure de room privée cassée.** `ChatUi.connectToServer` émet `join_room` avec une **Map** `{'participants': [moi, ...tousLesAmis]}`, alors que le backend (`socket.service.ts:52`) attend un **tableau de exactement 2 éléments** (`if (data.length !== 2) throw`). Les chats privés ne rejoignent donc pas la bonne room aujourd'hui.
2. **« John Doe ».** `resolveUser` renvoie `name: 'John Doe'` en dur, alors que les messages portent déjà le vrai `username` comme `authorId` (`Message.fromJson` mappe `json['username']` → `sender`). Aucun appel serveur nécessaire.
3. **Fallback *lorem ipsum*.** `_addItem` génère du texte aléatoire quand `text == null` (`flutter_lorem`).
4. **Vocal bouchonné.** `onAttachmentTap` enregistre, attend **8 s en dur**, insère un `AudioMessage` **local jamais uploadé** (invisible pour les autres).

### Décisions verrouillées (issues du brainstorming)

- **Périmètre :** 2a seul (socle socket). 2b/2c/2d plus tard.
- **Vocal :** **retirer** complètement le bouton pièce jointe et l'enregistrement audio en 2a ; le vocal reviendra propre en 2d.
- **Architecture :** service dédié `ChatConnection` (option 1), pas de fusion dans `SocketService` ni dans `UserProvider`.
- **`ChatConnection` est transport-only :** pas de cache de messages par room (ça relève de 2b/2c).

---

## Architecture

Service dédié `ChatConnection` (`ChangeNotifier`) qui possède **l'unique** `io.Socket`. Le `SocketService` REST existant est conservé tel quel (historique, envoi, suppression passent toujours par HTTP ; le serveur diffuse ensuite sur la socket). `ChatUi` cesse de posséder une socket : il rejoint sa room et s'abonne à un flux d'événements filtré par `roomName`. Séparation nette : **transport** (`ChatConnection`) / **REST** (`SocketService`) / **UI** (`ChatUi`).

```
login/startup ──connect()──> ChatConnection (1 socket)
                                  │  join_global / join_private / leave
                                  │  Stream<ChatEvent>  (tagué roomName)
ChatUi(room) ──join + REST history + stream.where(room)──> UI
envoi ── REST POST (SocketService) ──> serveur persiste + broadcast receive_message ──> autres clients via Stream
logout ──disconnect()
```

---

## Composants

### Nouveau — `flutter/lib/services/chat_connection.dart`

`class ChatConnection extends ChangeNotifier`

- Possède un `io.Socket` (transport `websocket`, token via `SecureStorage`). **Injectable** : le constructeur prend une *fabrique de socket* (`io.Socket Function()` ou seam équivalent) pour permettre l'injection d'une fausse socket en test.
- **Cycle de vie :** `connect()` quand une session est active ; `disconnect()` à la déconnexion. Plus de connect/disconnect par écran.
- **Méthodes :**
  - `joinGlobal()` → `emit('join_global_room')`.
  - `joinPrivate(String myId, String friendId)` → `emit('join_room', [myId, friendId])` (**tableau de 2 éléments** — corrige le bug de la Map).
  - `leave(String roomName)` → `emit('leave_room', roomName)`.
- **Flux :** un seul `Stream<ChatEvent>` *broadcast*. `ChatEvent` est un type tagué :
  - `MessageReceived(String roomName, Message message)`
  - `MessageDeleted(String roomName, String messageId)`
  - `AllMessagesDeleted(String roomName)`
  - Les handlers socket (`receive_message`, `receive_delete_message`, `receive_delete_all_messages`) sont enregistrés **une fois** et poussent dans ce flux.
- **État connexion :** exposé via `notifyListeners()` (drapeau `isConnected`/`isConnecting`) pour un futur indicateur « reconnexion » — **pas d'UI en 2a**.
- **Reconnexion :** défauts socket.io ; au `reconnect`, ré-émettre la jointure de la/les room(s) active(s).
- **Enregistrement :** dans `main.dart` (MultiProvider). `connect()` appelé après `userProvider.init()` si `isConnected`, et après un login réussi ; `disconnect()` dans le chemin de déconnexion (`MoreWidget._logout`).

### Refactoré — `flutter/lib/widgets/chat_ui.dart`

À **retirer** : création de socket en `initState`, `connectToServer`, `disconnectFromServer`, l'`AudioRecorder`/`just_audio`, `_startRecording`/`_stopRecording`, `onAttachmentTap`, le fallback `flutter_lorem`, la plomberie image `cross_cache` (commentée).

À **garder/adapter** :
- `initState` : récupère `ChatConnection` via Provider ; `joinGlobal()` ou `joinPrivate(myId, friendId)` selon `roomName` ; charge l'historique via REST (inchangé) ; s'abonne à `chatConnection.stream.where((e) => e.roomName == widget.roomName)` et applique chaque `ChatEvent` au `chatController` (insert / remove / clear).
- `resolveUser` : `return User(id: id, name: id);` (l'id **est** le username → fin de « John Doe »).
- `_addItem` : ne prend que du texte réel (plus de lorem) ; garde l'insert optimiste + envoi REST + réconciliation d'id.
- `dispose` : annule l'abonnement au flux, `chatConnection.leave(roomName)`. **La socket reste ouverte.**

> Dépendances `pubspec.yaml` devenues inutiles en 2a : `flutter_lorem`, et (si plus aucun autre usage) `record`. À retirer si et seulement si aucun autre fichier ne les importe — sinon laisser.

### Supprimé — `flutter/lib/widgets/chat_widget.dart`

Le chat privé depuis l'onglet Amis (`friends_widget.dart:282`) affiche désormais `ChatUi` directement dans une page poussée avec AppBar à bouton retour (motif des sous-pages de la Phase 1, cf. Profil/Bus), au lieu de passer par `ChatWidget`. Le `ChatUi` unique sert ainsi Global **et** les rooms privées.

---

## Flux de données

1. Login / démarrage → `ChatConnection.connect()` ouvre l'unique socket, `joinGlobal()`.
2. Ouverture d'une conversation → `ChatUi` rejoint la room (Global déjà jointe ; privé → `joinPrivate`), charge l'historique via REST, s'abonne au flux filtré.
3. Envoi → POST REST (inchangé) ; le serveur persiste + diffuse `receive_message` à la room ; les autres clients le reçoivent via le flux. L'émetteur garde son message optimiste (le backend `socket.to(room)` n'auto-renvoie pas à l'émetteur).
4. Changement d'écran → abonnement annulé, room quittée ; **la socket persiste** — pas de reconnexion, pas de « Chargement… » au prochain passage.
5. Déconnexion → `disconnect()`.

---

## Gestion d'erreurs

- Échec de `connect()` : loggé, exposé via le drapeau de connexion (pas de crash). Échec de récupération d'historique : on garde le snackbar actuel.
- Auto-reconnexion : défauts socket.io ; au `reconnect`, ré-émettre la jointure de la room active.

---

## Tests

- **TDD ciblé (utile) :** tester le *parsing* de `ChatEvent` et le **routage/filtrage** du flux (n'émettre que pour la bonne room) via une **fausse socket injectée** (seam de fabrique). Test de régression : `join_room` émet bien un **tableau de 2 éléments** (et non une Map).
- **Backend :** suite Jest socket existante reste verte — **aucun changement backend en 2a** (le correctif est côté client : la forme du payload, que le backend attend déjà).
- **Widget :** test léger de `ChatUi` avec un faux `ChatConnection` *optionnel* (UI très socket-dépendante, difficile à tester — on ne le force pas).

---

## Hors périmètre 2a (explicite)

- Boîte de réception unifiée / liste de conversations (**2b**).
- Pastilles de non-lus & notifs in-app (**2c**).
- Vocal : enregistrement appui-maintien + upload + stockage backend + lecture (**2d**).
- Pré-jointure de toutes les rooms d'amis ; cache de messages dans `ChatConnection`.

---

## Auto-revue

- **Placeholders :** aucun — chaque composant a une responsabilité et une interface définies.
- **Cohérence :** `ChatConnection` (transport) / `SocketService` (REST) / `ChatUi` (UI) sans recoupement ; l'envoi reste REST partout, le flux ne porte que la réception ; le bug Map↔tableau résolu côté client, conforme à « aucun changement backend ».
- **Périmètre :** centré sur 2a ; 2b/2c/2d listés hors périmètre ; suppression de `ChatWidget` justifiée par « un seul `ChatUi` paramétré par room ».
- **Ambiguïté :** seam d'injection de socket explicité (fabrique) pour rendre le routage testable sans vraie socket.
