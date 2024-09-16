class User {
  String id;
  String username;
  String status;
  List<User>? friends;

  User({required this.id, required this.username, required this.status, this.friends});

  factory User.fromJson(Map<String, dynamic> json) {
    if (json['friends'] != null) {
      var friendObjsJson = json['friends'] as List;
      List<User> _friends = friendObjsJson.map((friendJson) => User.fromJson(friendJson)).toList();
      return User(
        id: json['_id'],
        username: json['username'],
        status: json['status'],
        friends: _friends,
      );
    }
    return User(
      id: json['_id'],
      username: json['username'],
      status: json['status']
    );
  }
}
