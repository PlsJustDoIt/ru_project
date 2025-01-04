import 'user.dart';

class Room {
  final String id;
  final String name;
  final List<User>? participants;
  final DateTime createdAt;

  const Room({
    required this.id,
    required this.name,
    this.participants,
    required this.createdAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      name: json['name'],
      participants: (json['participants'] as List)
          .map((e) => User.fromJson(e))
          .toList(), // return empty array if null
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (participants != null)
        'participants': participants!.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  bool isMember(String userId) {
    return participants?.any((p) => p.id == userId) ?? false;
  }
}
