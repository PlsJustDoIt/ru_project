class User {
  String id;
  String username;
  String status;

  User({required this.id, required this.username, required this.status});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      username: json['username'],
      status: json['status'],
    );
  }
}
