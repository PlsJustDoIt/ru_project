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
