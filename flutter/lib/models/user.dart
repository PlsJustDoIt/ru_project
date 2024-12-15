import 'package:ru_project/services/logger.dart';

class User {
  String id;
  String username;
  String status; // status : en ligne, au ru, absent
  List<String>? friendIds;

  String avatarUrl;

  User({required this.id, required this.username, required this.status, this.friendIds, required this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] ?? '',
        username: json['username'] ?? 'ton pere',
        status: json['status'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        friendIds: json['friendIds'] ?? [],
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
      'friends': friendIds?.map((friend) => friend).toList(),
    };
  }

  @override
  String toString() {
    return 'User{id: $id, username: $username, status: $status, avatarUrl: $avatarUrl, friendIds: $friendIds}';
  }

  
}
