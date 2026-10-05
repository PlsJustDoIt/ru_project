import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/message.dart';

void main() {
  group('timeAgo', () {
    final now = DateTime(2026, 10, 5, 12, 0);
    test('formats courts', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
          'à l\'instant');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
          '5 min');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3 h');
      expect(timeAgo(now.subtract(const Duration(hours: 30)), now: now), 'hier');
      expect(timeAgo(now.subtract(const Duration(days: 4)), now: now), '4 j');
      expect(timeAgo(DateTime(2026, 9, 1, 8), now: now), '01/09');
    });
  });

  test('Message.fromJson tolère un expéditeur supprimé et une durée décimale',
      () {
    final m = Message.fromJson({
      'id': 'x',
      'content': '',
      'username': null,
      'createdAt': '2026-05-29T10:00:00.000Z',
      'audioUrl': 'uploads/audio/a.webm',
      'duration': 3.6,
    });
    expect(m.sender, 'Utilisateur supprimé');
    expect(m.senderId, isNull);
    expect(m.authorKey, 'username:Utilisateur supprimé');
    expect(m.isAudio, isTrue);
    expect(m.duration, 4);
  });
}
