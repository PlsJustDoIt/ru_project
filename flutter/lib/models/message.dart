/// Horodatage relatif court, pour les listes (« à l'instant », « 5 min »,
/// « 2 h », « hier », « 3 j », puis la date).
String timeAgo(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final local = date.toLocal();
  final difference = reference.difference(local);

  if (difference.inMinutes < 1) return 'à l\'instant';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min';
  if (difference.inHours < 24) return '${difference.inHours} h';
  if (difference.inDays < 2) return 'hier';
  if (difference.inDays < 7) return '${difference.inDays} j';
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month';
}

class Message {
  final String id;
  String content;

  /// Pseudo de l'expéditeur au moment de la lecture.
  final String sender;

  /// Id de l'expéditeur (null pour un compte supprimé) : c'est lui qui
  /// identifie « mes » messages, le pseudo pouvant changer.
  final String? senderId;
  final String? senderAvatarUrl;
  final DateTime createdAt;
  final String? audioUrl;
  final int? duration; // secondes

  Message({
    required this.id,
    required this.content,
    required this.sender,
    required this.createdAt,
    this.senderId,
    this.senderAvatarUrl,
    this.audioUrl,
    this.duration,
  });

  bool get isAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// Identifiant d'auteur stable pour l'UI de chat.
  String get authorKey => senderId ?? 'username:$sender';

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['id'],
        content: json['content'] ?? '',
        sender: json['username'] ?? 'Utilisateur supprimé',
        senderId: json['userId'],
        senderAvatarUrl: json['avatarUrl'],
        createdAt: DateTime.parse((json['createdAt'])),
        audioUrl: json['audioUrl'],
        duration: (json['duration'] as num?)?.round(),
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
      if (senderId != null) 'userId': senderId,
      if (senderAvatarUrl != null) 'avatarUrl': senderAvatarUrl,
      'createdAt': createdAt.toIso8601String(),
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (duration != null) 'duration': duration,
    };
  }

  @override
  String toString() {
    return 'Message{id: $id, content: $content, sender: $sender, createdAt: $createdAt}';
  }
}
