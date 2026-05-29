import 'package:ru_project/services/logger.dart';

class User {
  String id;
  String username;
  String status; // status : en ligne, au ru, absent
  String avatarUrl;
  String restaurantId;

  User(
      {required this.id,
      required this.username,
      required this.status,
      required this.restaurantId,
      required this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      logger.d('User.fromJson: $json');
      return User(
        id: json['id'] ?? '',
        username: json['username'] ?? 'ton pere',
        status: json['status'] ?? 'status non défini',
        restaurantId: json['restaurantId'] ?? 'r135', // todo eviter confusion
        avatarUrl: json['avatarUrl'] ?? 'uploads/avatar/default-avatar.png',
      );
    } catch (e) {
      logger.e(e);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'status': status,
      'avatarUrl': avatarUrl,
      'restaurantId': restaurantId,
    };
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, status: $status, avatarUrl: $avatarUrl , restaurantId: $restaurantId}';
  }
}

class Friend {
  String id;
  String username;
  String status; // status : en ligne, au ru, absent
  String avatarUrl;

  Friend({
    required this.id,
    required this.username,
    required this.status,
    required this.avatarUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    try {
      return Friend(
        id: json['_id'] ?? '',
        username: json['username'] ?? 'ton pere',
        status: json['status'] ?? 'status non défini',
        avatarUrl: json['avatarUrl'] ?? 'uploads/avatar/default-avatar.png',
      );
    } catch (e) {
      logger.e(e);
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'status': status,
      'avatarUrl': avatarUrl,
    };
  }

  @override
  String toString() {
    return 'Friend{id: $id, username: $username, status: $status, avatarUrl: $avatarUrl}';
  }

  static List<Friend> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((json) => Friend.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
