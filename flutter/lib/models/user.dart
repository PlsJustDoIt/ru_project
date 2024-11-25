class User {
  String id;
  String username;
  String status; // status : en ligne, au ru, absent
  List<String>? friendIds;

  String? avatarUrl;

  User({required this.id, required this.username, required this.status, required this.friendIds, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      username: json['username'],
      status: json['status'],
      avatarUrl: json['avatarUrl'],
      friendIds: json['friendIds'],
    );
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

  
}
