import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/services/chat_connection.dart';

import 'chat_connection_test.dart' show FakeChatSocket;

Map<String, dynamic> notify(String room, {String? userId, String user = 'bob'}) => {
      'roomName': room,
      'message': {
        'id': 'id-${DateTime.now().microsecondsSinceEpoch}',
        'content': 'yo',
        'username': user,
        if (userId != null) 'userId': userId,
        'createdAt': '2026-05-29T10:00:00.000Z',
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // HapticFeedback passe par un canal plateforme : on le neutralise.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<(FakeChatSocket, NotificationProvider)> setup(
      {String? myId = 'me', String? myName = 'moi'}) async {
    final fake = FakeChatSocket();
    final conn = ChatConnection(
      tokenProvider: () async => 'tok',
      socketFactory: (_) => fake,
    );
    await conn.connect();
    final provider = NotificationProvider(
      conn,
      currentUserId: () => myId,
      currentUsername: () => myName,
    );
    return (fake, provider);
  }

  test('compte les non-lus par room et ignore la room ouverte', () async {
    final (fake, provider) = await setup();
    fake.fire('notify_message', [notify('a_b', userId: 'bob')]);
    fake.fire('notify_message', [notify('a_b', userId: 'bob')]);
    provider.setCurrentRoom('Global');
    fake.fire('notify_message', [notify('Global', userId: 'bob')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.unreadFor('a_b'), 2);
    expect(provider.unreadFor('Global'), 0);
    expect(provider.totalUnread, 2);
  });

  test('ignore ses propres messages (par id, même après changement de pseudo)',
      () async {
    final (fake, provider) = await setup(myId: 'me', myName: 'nouveau-pseudo');
    fake.fire('notify_message', [notify('Global', userId: 'me', user: 'ancien')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.totalUnread, 0);
  });

  test('reset efface les non-lus (déconnexion)', () async {
    final (fake, provider) = await setup();
    fake.fire('notify_message', [notify('a_b', userId: 'bob')]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.totalUnread, 1);
    provider.reset();
    expect(provider.totalUnread, 0);
  });
}
