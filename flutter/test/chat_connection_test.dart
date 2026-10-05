import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';

/// Fausse socket : enregistre les emits et permet de déclencher les handlers.
class FakeChatSocket implements ChatSocket {
  final List<({String event, dynamic data})> emitted = [];
  final Map<String, void Function(dynamic)> handlers = {};
  void Function()? _onConnect;
  void Function()? _onDisconnect;
  void Function(dynamic)? _onConnectError;
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
  void onDisconnect(void Function() handler) => _onDisconnect = handler;
  @override
  void onConnectError(void Function(dynamic) handler) =>
      _onConnectError = handler;

  void fireConnect() => _onConnect?.call();
  void fireDisconnect() => _onDisconnect?.call();
  void fireConnectError(dynamic error) => _onConnectError?.call(error);
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

  test(
      'joinPrivate émet {participants:[...]} en arg unique '
      '(régression : socket_io_client étale les List sur plusieurs args)',
      () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinPrivate('b', 'a');
    final last = fake.emitted.last;
    expect(last.event, 'join_room');
    // Une List nue serait étalée par le vrai client → le backend ne recevrait
    // que le 1er id. Le payload doit être une Map (arg unique préservé).
    expect(last.data, isA<Map>());
    expect((last.data as Map)['participants'], ['b', 'a']);
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

  test('receive_message utilise la room indiquée dans le payload', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    final future = conn.events.first;
    fake.fire('receive_message', [
      {'roomName': 'a_b', 'message': sampleMessageJson('m2')}
    ]);
    final event = await future;
    expect(event.roomName, 'a_b');
  });

  test('message avec userId : senderId renseigné', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    final future = conn.events.first;
    fake.fire('receive_message', [
      {
        'roomName': 'Global',
        'message': {...sampleMessageJson('m3'), 'userId': 'u1'}
      }
    ]);
    final event = await future as MessageReceived;
    expect(event.message.senderId, 'u1');
    expect(event.message.authorKey, 'u1');
  });

  test(
      'reconnexion : rejoint la room ouverte et émet ChatResynced '
      '(le serveur oublie les rooms d\'une socket déconnectée)', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinPrivate('a', 'b');
    fake.fireConnect();
    fake.emitted.clear();

    fake.fireDisconnect();
    expect(conn.isConnected, isFalse);

    final future = conn.events.first;
    fake.fireConnect();
    expect(conn.isConnected, isTrue);
    expect(fake.emitted.single.event, 'join_room');
    final event = await future;
    expect(event, isA<ChatResynced>());
    expect(event.roomName, 'a_b');
  });

  test('première connexion : rejoint la room sans ChatResynced', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    final events = <ChatEvent>[];
    final sub = conn.events.listen(events.add);
    fake.fireConnect();
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    expect(fake.emitted.where((e) => e.event == 'join_global_room'),
        hasLength(2)); // émis à l'ouverture + rejoué à la connexion
    await sub.cancel();
  });

  test('token expiré au handshake : rafraîchit puis rouvre la socket',
      () async {
    final sockets = <FakeChatSocket>[];
    final tokens = <String>[];
    var refreshCalls = 0;
    final conn = ChatConnection(
      tokenProvider: () async => 'old',
      tokenRefresher: () async {
        refreshCalls++;
        return 'new';
      },
      socketFactory: (token) {
        tokens.add(token);
        final s = FakeChatSocket();
        sockets.add(s);
        return s;
      },
    );
    await conn.connect();
    conn.joinGlobal();

    sockets.first.fireConnectError({'message': 'Authentication error'});
    await Future<void>.delayed(Duration.zero);

    expect(refreshCalls, 1);
    expect(tokens, ['old', 'new']);
    expect(sockets.first.disconnectCalled, isTrue);
    expect(sockets.last.connectCalled, isTrue);

    // Un second refus ne boucle pas.
    sockets.last.fireConnectError({'message': 'Authentication error'});
    await Future<void>.delayed(Duration.zero);
    expect(refreshCalls, 1);

    // ...mais un connect() ultérieur (ouverture d'une conversation) recrée
    // la socket au lieu de rester bloqué sur une socket refusée.
    await conn.connect();
    expect(sockets, hasLength(3));
    expect(sockets[1].disconnectCalled, isTrue);
  });

  test('connect() ne recrée pas une socket saine', () async {
    var built = 0;
    final conn = ChatConnection(
      tokenProvider: () async => 'tok',
      socketFactory: (_) {
        built++;
        return FakeChatSocket();
      },
    );
    await conn.connect();
    await conn.connect();
    expect(built, 1);
  });

  test('disconnect ferme la socket et oublie la room', () async {
    final fake = FakeChatSocket();
    final conn = makeConnection(fake);
    await conn.connect();
    conn.joinGlobal();
    fake.fireConnect();
    conn.disconnect();
    expect(fake.disconnectCalled, isTrue);
    expect(fake.handlers, isEmpty);
    expect(conn.isConnected, isFalse);
    expect(conn.currentRoom, isNull);
  });
}
