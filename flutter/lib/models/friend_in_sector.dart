import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

class FriendsInSectors {
  final Map<String, List<FriendInSector>> data;

  FriendsInSectors(this.data);

  factory FriendsInSectors.fromJson(Map<String, dynamic> json) {
    try {
      final map = <String, List<FriendInSector>>{};
      json.forEach((key, value) {
        // value = tab
        map[key] = (value as List)
            .map((item) => FriendInSector.fromJson(item))
            .toList();
      });
      return FriendsInSectors(map);
    } catch (e) {
      logger.i('Error parsing FriendsInSectors: $e');
      // Handle parsing error
      return FriendsInSectors({});
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    data.forEach((key, value) {
      map[key] = value.map((item) => item.toJson()).toList();
    });
    return map;
  }

  @override
  String toString() {
    return 'FriendsInSectors{data: $data}';
  }
}

class FriendInSector {
  final Friend friend;
  final DateTime expiresAt;

  FriendInSector({required this.friend, required this.expiresAt});

  factory FriendInSector.fromJson(Map<String, dynamic> json) {
    try {
      logger.i('FriendInSector.fromJson: $json');
      return FriendInSector(
        friend: Friend.fromJson(json['friend']),
        expiresAt: DateTime.parse(json['expiresAt']),
      );
    } catch (e) {
      logger.i('Error parsing FriendInSector: $e');
      // Handle parsing error
    }
    return FriendInSector(
      friend: Friend.fromJson(json['friend']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friend': friend.toJson(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FriendInSector{friend: $friend, expiresAt: $expiresAt}';
  }
}
