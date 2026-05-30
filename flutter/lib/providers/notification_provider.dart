import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';

/// Suit les messages non lus par conversation et émet des bandeaux in-app.
/// Alimenté par la socket persistante via [ChatConnection] (événements
/// [MessageNotified], indépendants de la room ouverte).
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._connection) {
    _sub = _connection.events.listen(_onEvent);
  }

  final ChatConnection _connection;
  StreamSubscription<ChatEvent>? _sub;

  final Map<String, int> _unread = {};
  String? _currentRoom;

  /// Pseudo de l'utilisateur courant, pour ignorer ses propres messages
  /// (le Global est diffusé à tout le monde, expéditeur compris).
  String? currentUsername;

  final StreamController<MessageNotified> _banners =
      StreamController<MessageNotified>.broadcast();

  /// Un nouvel arrivé dans une conversation non ouverte -> bandeau « X t'a écrit ».
  Stream<MessageNotified> get banners => _banners.stream;

  int get totalUnread => _unread.values.fold(0, (a, b) => a + b);
  int unreadFor(String room) => _unread[room] ?? 0;

  /// La conversation actuellement à l'écran (ses messages ne comptent pas).
  void setCurrentRoom(String? room) {
    _currentRoom = room;
    if (room != null) markRead(room);
  }

  void markRead(String room) {
    if ((_unread[room] ?? 0) != 0) {
      _unread[room] = 0;
      notifyListeners();
    }
  }

  void _onEvent(ChatEvent event) {
    if (event is! MessageNotified) return;
    if (currentUsername != null && event.message.sender == currentUsername) {
      return;
    }
    if (event.roomName == _currentRoom) return;

    _unread[event.roomName] = (_unread[event.roomName] ?? 0) + 1;
    notifyListeners();
    _banners.add(event);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _banners.close();
    super.dispose();
  }
}
