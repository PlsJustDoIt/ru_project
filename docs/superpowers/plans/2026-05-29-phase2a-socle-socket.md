# Phase 2a — Socle chat (socket unique persistante) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sortir la socket Socket.IO de l'état du widget `ChatUi` vers un service dédié persistant (`ChatConnection`), pour supprimer le churn de reconnexion par écran, corriger les bugs (jointure de room privée cassée, « John Doe », fallback *lorem*) et retirer le hack vocal.

**Architecture :** Nouveau service `ChatConnection` (`ChangeNotifier`) qui possède l'unique `io.Socket`, ouvert une fois par session. Il expose un `Stream<ChatEvent>` et les méthodes `joinGlobal` / `joinPrivate` / `leave`. Une couche d'abstraction `ChatSocket` (avec impl réelle `IoChatSocket` + fake en test) rend la logique testable sans vraie socket. `ChatUi` devient un simple consommateur ; `SocketService` (REST) est inchangé. Le `ChatWidget` est supprimé.

**Tech Stack :** Flutter 3.35, Provider, `socket_io_client 3.x`, `flutter_chat_ui 2.x`, tests `flutter_test`.

**Spec :** [`docs/superpowers/specs/2026-05-29-phase2a-socle-socket-design.md`](../specs/2026-05-29-phase2a-socle-socket-design.md)

---

## Note de conception (raffinement du spec)

La socket est **persistante** (ouverte une fois, survit aux changements d'écran → fin du churn de reconnexion), mais l'**appartenance aux rooms suit l'écran actif** : `ChatUi` rejoint sa room au `initState` et la quitte au `dispose`. On ne pré-rejoint **pas** Global au démarrage. Raison : le backend n'inclut pas `roomName` dans le payload `receive_message` (`socket.service.ts:105` n'émet que `{ message }`). Tant qu'**une seule room est active à la fois**, `ChatConnection` peut estampiller chaque événement avec sa room courante (`_currentRoom`) sans ambiguïté ni changement backend. La conscience multi-rooms (rester joint partout) est explicitement repoussée en **2c** (qui ajoutera le tag `roomName` côté backend). Cela préserve exactement la sémantique « une socket = une room active » de l'ancien code, en lui retirant juste la reconnexion.

## Structure de fichiers

- **Créer** `flutter/lib/services/chat_event.dart` — type tagué `ChatEvent` (`MessageReceived` / `MessageDeleted` / `AllMessagesDeleted`).
- **Créer** `flutter/lib/services/chat_connection.dart` — abstraction `ChatSocket`, impl `IoChatSocket`, service `ChatConnection`.
- **Créer** `flutter/test/chat_connection_test.dart` — `FakeChatSocket` + tests de routage/parsing/jointure.
- **Modifier** `flutter/lib/main.dart` — instancier `ChatConnection`, l'enregistrer en provider, `connect()` si session active.
- **Modifier** `flutter/lib/widgets/welcome/login.dart` & `register.dart` — `connect()` au succès d'auth.
- **Modifier** `flutter/lib/widgets/more_widget.dart` — `disconnect()` à la déconnexion.
- **Modifier** `flutter/lib/widgets/chat_ui.dart` — consommer `ChatConnection`, retirer socket/record/lorem/cross_cache/attachment.
- **Modifier** `flutter/lib/widgets/friends_widget.dart` — remplacer `ChatWidget` par une page `ChatUi`.
- **Supprimer** `flutter/lib/widgets/chat_widget.dart`.
- **Modifier** `flutter/pubspec.yaml` — retirer `flutter_lorem`, `record`, `cross_cache` (uniquement utilisés par `chat_ui.dart`).

> Toutes les commandes `flutter` se lancent depuis `flutter/` (`cd flutter`).

---

### Task 1 : Type d'événement `ChatEvent`

**Files:**
- Create: `flutter/lib/services/chat_event.dart`
- Test: (couvert par `chat_connection_test.dart` en Task 2 ; pas de test isolé — type de données pur)

- [ ] **Step 1 : Créer le type tagué**

Créer `flutter/lib/services/chat_event.dart` :
```dart
import 'package:ru_project/models/message.dart';

/// Événement temps-réel d'une room, estampillé avec son [roomName].
sealed class ChatEvent {
  const ChatEvent(this.roomName);
  final String roomName;
}

class MessageReceived extends ChatEvent {
  const MessageReceived(super.roomName, this.message);
  final Message message;
}

class MessageDeleted extends ChatEvent {
  const MessageDeleted(super.roomName, this.messageId);
  final String messageId;
}

class AllMessagesDeleted extends ChatEvent {
  const AllMessagesDeleted(super.roomName);
}
```

- [ ] **Step 2 : Vérifier l'analyse**

Run: `cd flutter && flutter analyze lib/services/chat_event.dart`
Expected: pas d'erreur.

- [ ] **Step 3 : Commit**

```bash
git add flutter/lib/services/chat_event.dart
git commit -m "feat(flutter): type d'événement chat (ChatEvent)"
```

---

### Task 2 : Service `ChatConnection` + abstraction socket (TDD)

**Files:**
- Create: `flutter/lib/services/chat_connection.dart`
- Test: `flutter/test/chat_connection_test.dart`

- [ ] **Step 1 : Écrire les tests qui échouent**

Créer `flutter/test/chat_connection_test.dart` :
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';

/// Fausse socket : enregistre les emits et permet de déclencher les handlers.
class FakeChatSocket implements ChatSocket {
  final List<({String event, dynamic data})> emitted = [];
  final Map<String, void Function(dynamic)> handlers = {};
  void Function()? _onConnect;
  bool connectCalled = false;
  bool disconnectCalled = false;

  @override
  void connect() => connectCalled = true;
  @override
  void disconnect() => disconnectCalled = true;
  @override
  void emit(String event, [dynamic data]) =>
      emitted.add((event: event, data: data));
  @override
  void on(String event, void Function(dynamic) handler) =>
      handlers[event] = handler;
  @override
  void off(String event) => handlers.remove(event);
  @override
  void onConnect(void Function() handler) => _onConnect = handler;
  @override
  void onDisconnect(void Function() handler) {}

  void fireConnect() => _onConnect?.call();
  void fire(String event, dynamic data) => handlers[event]?.call(data);
}

ChatConnection makeConnection(FakeChatSocket fake) => ChatConnection(
      tokenProvider: () async => 'tok',
      socketFactory: (_) => fake,
    );

Map<String, dynamic> sampleMessageJson(String id) => {
      'id': id,
      'content': 'coucou',
      'username': 'alice',
      'createdAt': '2026-05-29T10:00:00.000Z',
    };

void main() {
  test('connect() construit la socket, enregistre les handlers et connecte',
      () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    expect(fake.connectCalled, isTrue);
    expect(fake.handlers.keys, contains('receive_message'));
    fake.fireConnect();
    expect(conn.isConnected, isTrue);
  });

  test('joinPrivate émet un tableau de 2 ids (régression bug Map)', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinPrivate('b', 'a');
    final last = fake.emitted.last;
    expect(last.event, 'join_room');
    expect(last.data, isA<List>());
    expect((last.data as List).length, 2);
    expect(last.data, ['b', 'a']);
  });

  test('joinGlobal puis receive_message émet MessageReceived taggé Global',
      () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    expect(fake.emitted.last.event, 'join_global_room');

    final future = conn.events.first;
    fake.fire('receive_message', [
      {'message': sampleMessageJson('m1')}
    ]);
    final event = await future;
    expect(event, isA<MessageReceived>());
    expect(event.roomName, 'Global');
    expect((event as MessageReceived).message.id, 'm1');
    expect(event.message.sender, 'alice');
  });

  test('receive_delete_message émet MessageDeleted', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinPrivate('a', 'b');
    final future = conn.events.first;
    fake.fire('receive_delete_message', [
      {'messageId': 'm9'}
    ]);
    final event = await future;
    expect(event, isA<MessageDeleted>());
    expect(event.roomName, 'a_b');
    expect((event as MessageDeleted).messageId, 'm9');
  });

  test('leave efface la room courante et émet leave_room', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    conn.leave('Global');
    expect(fake.emitted.last.event, 'leave_room');
    expect(fake.emitted.last.data, 'Global');
  });

  test('connect() ignoré si pas de token', () async {
    var built = false;
    final conn = ChatConnection(
      tokenProvider: () async => null,
      socketFactory: (_) {
        built = true;
        return FakeChatSocket();
      },
    );
    await conn.connect();
    expect(built, isFalse);
    expect(conn.isConnected, isFalse);
  });
}
```

- [ ] **Step 2 : Lancer les tests → échec**

Run: `cd flutter && flutter test test/chat_connection_test.dart`
Expected: FAIL (`chat_connection.dart` introuvable).

- [ ] **Step 3 : Implémenter le service**

Créer `flutter/lib/services/chat_connection.dart` :
```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/logger.dart';

/// Couture testable au-dessus du client socket.io.
abstract class ChatSocket {
  void connect();
  void disconnect();
  void emit(String event, [dynamic data]);
  void on(String event, void Function(dynamic data) handler);
  void off(String event);
  void onConnect(void Function() handler);
  void onDisconnect(void Function() handler);
}

/// Implémentation réelle : enveloppe un `io.Socket`.
class IoChatSocket implements ChatSocket {
  IoChatSocket(String token)
      : _socket = io.io(Config.serverUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'query': {'token': token},
        });

  final io.Socket _socket;

  @override
  void connect() => _socket.connect();
  @override
  void disconnect() => _socket.disconnect();
  @override
  void emit(String event, [dynamic data]) =>
      data == null ? _socket.emit(event) : _socket.emit(event, data);
  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);
  @override
  void off(String event) => _socket.off(event);
  @override
  void onConnect(void Function() handler) =>
      _socket.onConnect((_) => handler());
  @override
  void onDisconnect(void Function() handler) =>
      _socket.onDisconnect((_) => handler());
}

typedef ChatSocketFactory = ChatSocket Function(String token);

/// Connexion Socket.IO unique et persistante de l'appli.
class ChatConnection extends ChangeNotifier {
  ChatConnection({
    required Future<String?> Function() tokenProvider,
    ChatSocketFactory? socketFactory,
  })  : _tokenProvider = tokenProvider,
        _socketFactory = socketFactory ?? ((token) => IoChatSocket(token));

  final Future<String?> Function() _tokenProvider;
  final ChatSocketFactory _socketFactory;

  ChatSocket? _socket;
  String? _currentRoom;
  bool _isConnected = false;

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _events.stream;
  bool get isConnected => _isConnected;

  static String privateRoomName(String a, String b) =>
      ([a, b]..sort()).join('_');

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _tokenProvider();
    if (token == null) {
      logger.w('ChatConnection: pas de token, connexion ignorée');
      return;
    }
    final socket = _socketFactory(token);
    _socket = socket;
    socket.onConnect(() {
      _isConnected = true;
      notifyListeners();
    });
    socket.onDisconnect(() {
      _isConnected = false;
      notifyListeners();
    });
    socket.on('receive_message', _onReceiveMessage);
    socket.on('receive_delete_message', _onDeleteMessage);
    socket.on('receive_delete_all_messages', _onDeleteAll);
    socket.on('error', (data) => logger.e('Socket error: $data'));
    socket.connect();
  }

  void joinGlobal() {
    _currentRoom = 'Global';
    _socket?.emit('join_global_room');
  }

  void joinPrivate(String myId, String friendId) {
    _currentRoom = privateRoomName(myId, friendId);
    _socket?.emit('join_room', [myId, friendId]);
  }

  void leave(String roomName) {
    _socket?.emit('leave_room', roomName);
    if (_currentRoom == roomName) _currentRoom = null;
  }

  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    socket.off('receive_message');
    socket.off('receive_delete_message');
    socket.off('receive_delete_all_messages');
    socket.off('error');
    socket.disconnect();
    _socket = null;
    _currentRoom = null;
    _isConnected = false;
    notifyListeners();
  }

  void _onReceiveMessage(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    try {
      final Map<String, dynamic> payload = (data as List).first;
      final message = Message.fromJson(payload['message']);
      _events.add(MessageReceived(room, message));
    } catch (e) {
      logger.e('ChatConnection: parse receive_message: $e');
    }
  }

  void _onDeleteMessage(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    try {
      final Map<String, dynamic> payload = (data as List).first;
      _events.add(MessageDeleted(room, payload['messageId']));
    } catch (e) {
      logger.e('ChatConnection: parse delete: $e');
    }
  }

  void _onDeleteAll(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    _events.add(AllMessagesDeleted(room));
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
    super.dispose();
  }
}
```

- [ ] **Step 4 : Lancer les tests → succès**

Run: `cd flutter && flutter test test/chat_connection_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5 : Commit**

```bash
git add flutter/lib/services/chat_connection.dart flutter/test/chat_connection_test.dart
git commit -m "feat(flutter): ChatConnection — socket unique persistante testable"
```

---

### Task 3 : Câbler `ChatConnection` dans le cycle de vie de session

Pas de test automatisé (wiring de providers) — vérifié par `flutter analyze` puis en Task 7.

**Files:**
- Modify: `flutter/lib/main.dart`
- Modify: `flutter/lib/widgets/welcome/login.dart:33` (bloc succès)
- Modify: `flutter/lib/widgets/welcome/register.dart:29` (bloc succès)
- Modify: `flutter/lib/widgets/more_widget.dart` (`_logout`)

- [ ] **Step 1 : Instancier + connecter dans `main.dart`**

Dans `flutter/lib/main.dart` :
- Ajouter l'import : `import 'package:ru_project/services/chat_connection.dart';`
- Après la ligne `final socketService = SocketService(dio: apiClient.dio);` (≈43), ajouter :
```dart
  final chatConnection =
      ChatConnection(tokenProvider: secureStorage.getAccessToken);
```
- Après `await userProvider.init(...)` (≈50), ajouter :
```dart
  if (userProvider.isConnected) {
    await chatConnection.connect();
  }
```
- Dans la liste `providers:` du `MultiProvider`, ajouter après la ligne `Provider<SocketService>.value(value: socketService),` :
```dart
        ChangeNotifierProvider<ChatConnection>.value(value: chatConnection),
```

- [ ] **Step 2 : Connecter au succès du login**

Dans `flutter/lib/widgets/welcome/login.dart`, dans le bloc de succès (avant `Navigator.pushReplacement`, ≈ligne 33), ajouter :
```dart
        Provider.of<ChatConnection>(context, listen: false).connect();
```
Ajouter l'import en tête : `import 'package:ru_project/services/chat_connection.dart';`

- [ ] **Step 3 : Connecter au succès du register**

Idem dans `flutter/lib/widgets/welcome/register.dart` (bloc succès, ≈ligne 29) :
```dart
        Provider.of<ChatConnection>(context, listen: false).connect();
```
Ajouter l'import : `import 'package:ru_project/services/chat_connection.dart';`

- [ ] **Step 4 : Déconnecter au logout**

Dans `flutter/lib/widgets/more_widget.dart`, méthode `_logout`, juste après `await authService.logout();` ajouter :
```dart
    Provider.of<ChatConnection>(context, listen: false).disconnect();
```
Ajouter l'import : `import 'package:ru_project/services/chat_connection.dart';`

- [ ] **Step 5 : Vérifier l'analyse**

Run: `cd flutter && flutter analyze lib/main.dart lib/widgets/welcome/login.dart lib/widgets/welcome/register.dart lib/widgets/more_widget.dart`
Expected: pas de nouvelle erreur.

- [ ] **Step 6 : Commit**

```bash
git add flutter/lib/main.dart flutter/lib/widgets/welcome/login.dart flutter/lib/widgets/welcome/register.dart flutter/lib/widgets/more_widget.dart
git commit -m "feat(flutter): ouvrir/fermer ChatConnection selon la session"
```

---

### Task 4 : Refondre `ChatUi` en consommateur de `ChatConnection`

Réécriture ciblée du widget : on retire la socket propre, l'enregistrement audio, le fallback *lorem*, `cross_cache`, et on s'abonne au flux partagé.

**Files:**
- Modify: `flutter/lib/widgets/chat_ui.dart`

- [ ] **Step 1 : Remplacer les imports**

En tête de `flutter/lib/widgets/chat_ui.dart`, remplacer le bloc d'imports par :
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart' as ru_project;
import 'package:ru_project/models/message.dart' as ru_project;
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/widgets/audio_player_widget.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:uuid/uuid.dart';
```
(On retire : `secure_storage`, `dart:io`, `foundation`, `socket_io_client`, `config`, `cross_cache`, `flutter_lorem`, `dart:math`, `record`, `just_audio`.)

- [ ] **Step 2 : Nettoyer l'état + initState**

Dans `ChatUiState`, supprimer les champs `_crossCache`, `secureStorage`, `socket`, `_record`, `initialMessages` (gardés : `_uuid`, `_messages`, `socketService`, `chatController`). Ajouter :
```dart
  StreamSubscription<ChatEvent>? _sub;
  late final ChatConnection chatConnection;
```
Remplacer `initState` par :
```dart
  @override
  void initState() {
    super.initState();
    socketService = Provider.of<SocketService>(context, listen: false);
    chatConnection = Provider.of<ChatConnection>(context, listen: false);
    chatController = types.InMemoryChatController();

    if (widget.roomName == 'Global') {
      chatConnection.joinGlobal();
    } else if (widget.friends != null && widget.friends!.isNotEmpty) {
      chatConnection.joinPrivate(
          widget.actualUser.id, widget.friends!.first.id);
    }

    _sub = chatConnection.events
        .where((e) => e.roomName == widget.roomName)
        .listen(_onChatEvent);

    _initializeMessages();
  }
```

- [ ] **Step 3 : Gérer les événements + supprimer la socket propre**

Supprimer entièrement les méthodes `connectToServer`, `disconnectFromServer`, `_startRecording`, `_stopRecording`. Ajouter le handler d'événements :
```dart
  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case MessageReceived(:final message):
        final incoming = types.TextMessage(
          id: message.id,
          authorId: message.sender,
          text: message.content,
          createdAt: message.createdAt,
        );
        setState(() {
          _messages.insert(0, incoming);
          chatController.insertMessage(incoming);
        });
      case MessageDeleted(:final messageId):
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final toRemove = chatController.messages[index];
            chatController.removeMessage(toRemove);
            _messages.removeAt(index);
          }
        });
      case AllMessagesDeleted():
        setState(() {
          _messages.clear();
        });
    }
  }
```

- [ ] **Step 4 : Adapter `_initializeMessages`, `dispose`, `_addItem`, `resolveUser`**

Remplacer `_initializeMessages` par (sans `initialMessages`) :
```dart
  Future<void> _initializeMessages() async {
    final messages = await setMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
        chatController.insertAllMessages(_messages);
      });
    }
  }
```
Remplacer `dispose` par :
```dart
  @override
  void dispose() {
    _sub?.cancel();
    chatConnection.leave(widget.roomName);
    chatController.dispose();
    super.dispose();
  }
```
Dans `_addItem`, changer la signature en non-nullable et retirer le fallback *lorem* :
```dart
  void _addItem(String text) async {
    logger.i('Adding text $text to chat');
    final tempId = _uuid.v4();
    final types.TextMessage message = types.TextMessage(
      id: tempId,
      authorId: widget.user.id,
      text: text,
      createdAt: DateTime.now(),
    );
    // ... (corps existant : insertMessage, setState, envoi REST, réconciliation — inchangé)
```
Dans `build`, dans `resolveUser`, remplacer la ligne de retour par :
```dart
        return types.User(id: id, name: id);
```

- [ ] **Step 5 : Retirer l'attachement/vocal de `build`**

Dans le `ui.Chat(...)`, **supprimer** le paramètre `onAttachmentTap: () async { ... },` en entier. Garder `onMessageSend: (text) => _addItem(text)`, `onMessageTap`, et le `builders: types.Builders(audioMessageBuilder: ...)` (rendu des éventuels messages audio d'historique via `AudioPlayerWidget`). Supprimer les gros blocs commentés en fin de fichier (`_handleAttachmentTap`, `_showDeleteConfirmationDialog`, le `builders` commenté).

- [ ] **Step 6 : Vérifier l'analyse**

Run: `cd flutter && flutter analyze lib/widgets/chat_ui.dart`
Expected: aucune erreur, aucun import inutilisé. Si `audio_player_widget`/`uuid`/`socket_service` deviennent inutilisés, les retirer ; s'ils servent encore, les garder.

- [ ] **Step 7 : Commit**

```bash
git add flutter/lib/widgets/chat_ui.dart
git commit -m "refactor(flutter): ChatUi consomme ChatConnection, fin de John Doe/lorem/vocal-hack"
```

---

### Task 5 : Brancher le chat privé sur `ChatUi` et supprimer `ChatWidget`

**Files:**
- Modify: `flutter/lib/widgets/friends_widget.dart:282`
- Delete: `flutter/lib/widgets/chat_widget.dart`

- [ ] **Step 1 : Remplacer la navigation `ChatWidget` → `ChatUi`**

Dans `flutter/lib/widgets/friends_widget.dart`, dans le `onPressed` de l'`IconButton` message (≈ligne 277), remplacer le `MaterialPageRoute` qui construit `ChatWidget(...)` par une page poussée enveloppant `ChatUi` :
```dart
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => Scaffold(
                                            appBar: AppBar(
                                              title: Text(friend.username),
                                            ),
                                            body: ChatUi(
                                              roomName: generatePrivateRoomName(
                                                  userProvider.user!.id,
                                                  friend.id),
                                              actualUser: userProvider.user!,
                                              friends: [friend],
                                            ),
                                          ),
                                        ),
                                      );
```
Remplacer l'import `import 'package:ru_project/widgets/chat_widget.dart';` par `import 'package:ru_project/widgets/chat_ui.dart';` (s'il n'est pas déjà importé).

- [ ] **Step 2 : Supprimer l'ancien wrapper**

```bash
git rm flutter/lib/widgets/chat_widget.dart
```

- [ ] **Step 3 : Vérifier l'analyse**

Run: `cd flutter && flutter analyze`
Expected: aucune référence résiduelle à `ChatWidget`, pas de nouvelle erreur.

- [ ] **Step 4 : Commit**

```bash
git add flutter/lib/widgets/friends_widget.dart
git commit -m "refactor(flutter): chat privé via ChatUi, suppression de ChatWidget"
```

---

### Task 6 : Retirer les dépendances mortes + suite complète

`flutter_lorem`, `record` et `cross_cache` n'étaient utilisés que par `chat_ui.dart` (vérifié : `grep -rln` ne renvoie que ce fichier). `just_audio`/`uuid`/`socket_io_client` restent utilisés ailleurs — **ne pas** les retirer.

**Files:**
- Modify: `flutter/pubspec.yaml`

- [ ] **Step 1 : Retirer les 3 dépendances**

Dans `flutter/pubspec.yaml`, supprimer les lignes `record: ^6.1.1`, `cross_cache: ^1.0.4`, `flutter_lorem: ^2.0.0`.

- [ ] **Step 2 : Récupérer les paquets**

Run: `cd flutter && flutter pub get`
Expected: succès, pas d'erreur de résolution.

- [ ] **Step 3 : Analyse complète**

Run: `cd flutter && flutter analyze`
Expected: pas de nouvelle erreur ni d'import cassé.

- [ ] **Step 4 : Suite de tests complète**

Run: `cd flutter && flutter test`
Expected: tous les tests PASS (les 9 existants + `chat_connection_test.dart`).

- [ ] **Step 5 : Commit**

```bash
git add flutter/pubspec.yaml flutter/pubspec.lock
git commit -m "chore(flutter): retirer flutter_lorem/record/cross_cache (inutilisés)"
```

---

### Task 7 : Vérification manuelle

Pas de test automatisé — on regarde l'app tourner (web et/ou mobile).

- [ ] **Step 1 : Lancer le backend puis l'app**

Backend : `cd backend && npx tsx watch src/server.ts`. App : `cd flutter && flutter run`.

- [ ] **Step 2 : Contrôler la check-list**

- **Messages (Global)** : la liste s'ouvre, les messages affichent le **vrai pseudo** de l'auteur (plus de « John Doe »).
- Envoyer un message → il apparaît ; depuis un 2e compte, le message arrive en temps réel.
- **Pas de bouton pièce jointe / micro** dans la barre de saisie.
- **Amis → 💬** : ouvre la conversation privée (AppBar = pseudo de l'ami, bouton retour), rejoint la **bonne** room (les messages privés des deux comptes se voient).
- **Changer d'onglet puis revenir** : pas de reconnexion socket visible (logs : une seule connexion) ; au plus un bref chargement d'historique REST.
- **Déconnexion** (Plus → Déconnexion) puis reconnexion : la socket se ferme et se rouvre proprement.

- [ ] **Step 3 :** Si tout est bon, rien à committer. Sinon, corriger le point fautif et committer le correctif.

---

## Auto-revue (effectuée)

- **Couverture du spec :** socket unique persistante → `ChatConnection` (Tasks 2/3) ; un seul `ChatUi` paramétré par room → Tasks 4/5 ; fix jointure room privée (tableau de 2) → `joinPrivate` + test de régression (Task 2) ; fin « John Doe » → `resolveUser` (Task 4 Step 4) ; fin *lorem* → `_addItem` non-nullable (Task 4) ; retrait vocal/attachement → Task 4 Step 5 ; suppression `ChatWidget` → Task 5 ; transport-only (pas de cache) → `ChatConnection` n'expose qu'un flux ; aucun changement backend → confirmé (correctif côté payload client).
- **Placeholders :** aucun ; le seul `// ... (corps existant ...)` en Task 4 Step 4 renvoie à du code déjà présent et inchangé de `_addItem`, explicitement délimité.
- **Cohérence des types :** `ChatEvent`/`MessageReceived`/`MessageDeleted`/`AllMessagesDeleted` (Task 1) consommés à l'identique dans `_onChatEvent` (Task 4) et le service (Task 2) ; `ChatSocket`/`ChatConnection`/`ChatSocketFactory` définis en Task 2, injectés en Task 3, lus en Task 4 ; `events`/`isConnected`/`joinGlobal`/`joinPrivate`/`leave`/`connect`/`disconnect` stables entre tasks.
- **Raffinement documenté :** jointure par écran (pas de pré-join Global au démarrage) — justifié dans « Note de conception ».
