import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/logger.dart';

/// Couture testable au-dessus du client socket.io.
abstract class ChatSocket {
  void connect();
  void disconnect();
  void emit(String event, [dynamic data]);
  void on(String event, void Function(dynamic data) handler);
  void off(String event);
  void onConnect(void Function() handler);
  void onDisconnect(void Function() handler);
}

/// Implémentation réelle : enveloppe un `io.Socket`.
class IoChatSocket implements ChatSocket {
  IoChatSocket(String token)
      : _socket = io.io(Config.serverUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'query': {'token': token},
        });

  final io.Socket _socket;

  @override
  void connect() => _socket.connect();
  @override
  void disconnect() => _socket.disconnect();
  @override
  void emit(String event, [dynamic data]) =>
      data == null ? _socket.emit(event) : _socket.emit(event, data);
  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);
  @override
  void off(String event) => _socket.off(event);
  @override
  void onConnect(void Function() handler) =>
      _socket.onConnect((_) => handler());
  @override
  void onDisconnect(void Function() handler) =>
      _socket.onDisconnect((_) => handler());
}

typedef ChatSocketFactory = ChatSocket Function(String token);

/// Connexion Socket.IO unique et persistante de l'appli.
class ChatConnection extends ChangeNotifier {
  ChatConnection({
    required Future<String?> Function() tokenProvider,
    ChatSocketFactory? socketFactory,
  })  : _tokenProvider = tokenProvider,
        _socketFactory = socketFactory ?? ((token) => IoChatSocket(token));

  final Future<String?> Function() _tokenProvider;
  final ChatSocketFactory _socketFactory;

  ChatSocket? _socket;
  String? _currentRoom;
  bool _isConnected = false;

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _events.stream;
  bool get isConnected => _isConnected;

  static String privateRoomName(String a, String b) =>
      ([a, b]..sort()).join('_');

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _tokenProvider();
    if (token == null) {
      logger.w('ChatConnection: pas de token, connexion ignorée');
      return;
    }
    final socket = _socketFactory(token);
    _socket = socket;
    socket.onConnect(() {
      _isConnected = true;
      notifyListeners();
    });
    socket.onDisconnect(() {
      _isConnected = false;
      notifyListeners();
    });
    socket.on('receive_message', _onReceiveMessage);
    socket.on('receive_delete_message', _onDeleteMessage);
    socket.on('receive_delete_all_messages', _onDeleteAll);
    socket.on('error', (data) => logger.e('Socket error: $data'));
    socket.connect();
  }

  void joinGlobal() {
    _currentRoom = 'Global';
    _socket?.emit('join_global_room');
  }

  void joinPrivate(String myId, String friendId) {
    _currentRoom = privateRoomName(myId, friendId);
    // Une List nue serait étalée par socket_io_client sur plusieurs arguments
    // (le backend ne recevrait que le 1er id) ; on enveloppe dans une Map.
    _socket?.emit('join_room', {
      'participants': [myId, friendId]
    });
  }

  void leave(String roomName) {
    _socket?.emit('leave_room', roomName);
    if (_currentRoom == roomName) _currentRoom = null;
  }

  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    socket.off('receive_message');
    socket.off('receive_delete_message');
    socket.off('receive_delete_all_messages');
    socket.off('error');
    socket.disconnect();
    _socket = null;
    _currentRoom = null;
    _isConnected = false;
    notifyListeners();
  }

  void _onReceiveMessage(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    try {
      final Map<String, dynamic> payload = (data as List).first;
      final message = Message.fromJson(payload['message']);
      _events.add(MessageReceived(room, message));
    } catch (e) {
      logger.e('ChatConnection: parse receive_message: $e');
    }
  }

  void _onDeleteMessage(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    try {
      final Map<String, dynamic> payload = (data as List).first;
      _events.add(MessageDeleted(room, payload['messageId']));
    } catch (e) {
      logger.e('ChatConnection: parse delete: $e');
    }
  }

  void _onDeleteAll(dynamic data) {
    final room = _currentRoom;
    if (room == null) return;
    _events.add(AllMessagesDeleted(room));
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
    super.dispose();
  }
}
