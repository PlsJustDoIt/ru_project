import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/services/restaurant_service.dart';

class _FakeRestaurantProvider extends RestaurantProvider {
  _FakeRestaurantProvider() : super(RestaurantService(dio: Dio()));

  bool shouldThrow = false;
  int loadCalls = 0;
  String? lastId;

  @override
  Future<void> loadRestaurant(String restaurantId) async {
    loadCalls++;
    lastId = restaurantId;
    if (shouldThrow) {
      throw Exception('boom');
    }
  }
}

void main() {
  test('tryLoadRestaurant ne charge rien si id null', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant(null);
    expect(p.loadCalls, 0);
  });

  test('tryLoadRestaurant ne charge rien si id vide', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant('');
    expect(p.loadCalls, 0);
  });

  test('tryLoadRestaurant charge si id renseigné', () async {
    final p = _FakeRestaurantProvider();
    await p.tryLoadRestaurant('abc');
    expect(p.loadCalls, 1);
    expect(p.lastId, 'abc');
  });

  test('tryLoadRestaurant avale les erreurs (ne propage pas)', () async {
    final p = _FakeRestaurantProvider()..shouldThrow = true;
    await p.tryLoadRestaurant('abc'); // ne doit pas lever
    expect(p.loadCalls, 1);
  });
}
