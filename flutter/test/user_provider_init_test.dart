import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/friend_service.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/user_service.dart';

class _FakeSecureStorage implements SecureStorage {
  String? accessToken;
  String? guestRestaurantId;

  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<void> storeTokens(String accessToken, String refreshToken) async {}
  @override
  Future<void> storeAccessToken(String accessToken) async {}
  @override
  Future<void> storeRefreshToken(String refreshToken) async {}
  @override
  Future<Map<String, String?>> getTokens() async => {};
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> clearTokens() async {}
  @override
  Future<void> storeGuestRestaurantId(String restaurantId) async {
    guestRestaurantId = restaurantId;
  }
  @override
  Future<String?> getGuestRestaurantId() async => guestRestaurantId;
  @override
  Future<void> clearGuestRestaurantId() async {
    guestRestaurantId = null;
  }
}

class _FakeUserService extends UserService {
  _FakeUserService() : super(dio: Dio());
  User? userToReturn;
  @override
  Future<User?> getUser() async => userToReturn;
}

class _FakeFriendService extends FriendService {
  _FakeFriendService() : super(dio: Dio());
  bool shouldThrow = false;
  List<Friend> friends = [];
  @override
  Future<List<Friend>> getFriends() async {
    if (shouldThrow) throw Exception('friends boom');
    return friends;
  }
}

class _FakeRestaurantProvider extends RestaurantProvider {
  _FakeRestaurantProvider() : super(RestaurantService(dio: Dio()));
  bool shouldThrow = false;
  int loadCalls = 0;
  @override
  Future<void> loadRestaurant(String restaurantId) async {
    loadCalls++;
    if (shouldThrow) throw Exception('resto boom');
  }
}

User _user() => User(
      id: '1',
      username: 'bob',
      status: 'absent',
      avatarUrl: 'a.png',
      restaurantId: 'resto1',
    );

void main() {
  late _FakeSecureStorage storage;
  late _FakeUserService userService;
  late _FakeFriendService friendService;
  late _FakeRestaurantProvider restaurantProvider;
  late UserProvider provider;

  setUp(() {
    storage = _FakeSecureStorage();
    userService = _FakeUserService();
    friendService = _FakeFriendService();
    restaurantProvider = _FakeRestaurantProvider();
    provider = UserProvider(secureStorage: storage);
  });

  test('pas de token → non connecté', () async {
    storage.accessToken = null;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, false);
    expect(provider.user, isNull);
  });

  test('token mais getUser null → non connecté', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = null;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, false);
  });

  test('REGRESSION: getUser OK mais loadRestaurant échoue → reste connecté',
      () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    restaurantProvider.shouldThrow = true;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
    expect(provider.user, isNotNull);
  });

  test('getUser OK mais getFriends échoue → reste connecté', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    friendService.shouldThrow = true;
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
  });

  test('cas nominal → connecté, amis + resto chargés', () async {
    storage.accessToken = 'tok';
    userService.userToReturn = _user();
    friendService.friends = [
      Friend(id: '2', username: 'al', status: 'absent', avatarUrl: 'b.png'),
    ];
    await provider.init(userService, friendService, restaurantProvider);
    expect(provider.isConnected, true);
    expect(provider.friends.length, 1);
    expect(restaurantProvider.loadCalls, 1);
  });
}
