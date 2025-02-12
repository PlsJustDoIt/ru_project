String timeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays > 1) {
    return "${difference.inDays} jours";
  } else if (difference.inHours > 1) {
    return "${difference.inHours} heures";
  } else if (difference.inMinutes > 1) {
    return "${difference.inMinutes} minutes";
  } else {
    return "un l'instant";
  }
}

class Message {
  final String id;
  String content;
  final String sender;
  final DateTime createdAt; // TODO : faire bien parce que voila

  Message({
    required this.id,
    required this.content,
    required this.sender,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'],
        content: json['content'],
        sender: json['username'],
        createdAt: DateTime.parse((json['createdAt'])),
      );
    } catch (e) {
      throw Exception('Error parsing message data: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'username': sender,
      'createdAt': createdAt,
    };
  }

  @override
  String toString() {
    return 'Message{id: $id, content: $content, sender: $sender, createdAt: $createdAt}';
  }
}
