import 'package:ru_project/models/message.dart';

/// Événement temps-réel d'une room, estampillé avec son [roomName].
sealed class ChatEvent {
  const ChatEvent(this.roomName);
  final String roomName;
}

class MessageReceived extends ChatEvent {
  const MessageReceived(super.roomName, this.message);
  final Message message;
}

class MessageDeleted extends ChatEvent {
  const MessageDeleted(super.roomName, this.messageId);
  final String messageId;
}

class AllMessagesDeleted extends ChatEvent {
  const AllMessagesDeleted(super.roomName);
}

/// Notif cross-room : un message est arrivé dans [roomName], que l'utilisateur
/// la regarde ou non. Sert aux non-lus et au bandeau in-app.
class MessageNotified extends ChatEvent {
  const MessageNotified(super.roomName, this.message);
  final Message message;
}
