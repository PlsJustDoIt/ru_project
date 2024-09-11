class User {
  String id;
  String username;
  String status;
  List<User> friends;

  User({required this.id, required this.username, required this.status,required this.friends});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      username: json['username'],
      status: json['status'],
      friends: json['friends'],
    );
  }
}
