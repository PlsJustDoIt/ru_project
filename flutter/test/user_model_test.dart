import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/user.dart';

void main() {
  test('fromJson sans restaurantId → null (plus de défaut r135)', () {
    final user = User.fromJson({
      'id': '1',
      'username': 'bob',
      'status': 'absent',
      'avatarUrl': 'a.png',
    });
    expect(user.restaurantId, isNull);
  });

  test('fromJson conserve un restaurantId fourni', () {
    final user = User.fromJson({'restaurantId': 'abc'});
    expect(user.restaurantId, 'abc');
  });
}
