class FriendRequest {
  final String requestId;
  final Map<String,dynamic> sender;
  final String status;
  final String createdAt;

  FriendRequest({
    required this.requestId,
    required this.sender,
    required this.status,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    try {
      return FriendRequest(
        requestId: json['id'],
        sender: json['sender'],
        status: json['status'],
        createdAt: json['createdAt'],
      );
    } catch (e) {
      throw Exception('Failed to load friends request : $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': requestId,
      'sender': sender,
      'status': status,
      'createdAt': createdAt,
    };
  }
}