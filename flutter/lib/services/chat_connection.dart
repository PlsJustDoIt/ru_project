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
  void onConnectError(void Function(dynamic error) handler);
}

/// Implémentation réelle : enveloppe un `io.Socket`.
class IoChatSocket implements ChatSocket {
  IoChatSocket(String token)
      : _socket = io.io(Config.serverUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          // Token dans le handshake (et non dans l'URL, qui finit dans les logs).
          'auth': {'token': token},
          // Connexion neuve à chaque ouverture : le token est propre à cette
          // socket (changement de compte, token rafraîchi).
          'forceNew': true,
        });

  final io.Socket _socket;

  @override
  void connect() => _socket.connect();
  @override
  void disconnect() => _socket.dispose();
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
  @override
  void onConnectError(void Function(dynamic error) handler) =>
      _socket.onConnectError(handler);
}

typedef ChatSocketFactory = ChatSocket Function(String token);

const _socketEvents = [
  'receive_message',
  'receive_delete_message',
  'receive_delete_all_messages',
  'notify_message',
  'error',
];

/// Connexion Socket.IO unique et persistante de l'appli.
class ChatConnection extends ChangeNotifier {
  ChatConnection({
    required Future<String?> Function() tokenProvider,
    Future<String?> Function()? tokenRefresher,
    ChatSocketFactory? socketFactory,
  })  : _tokenProvider = tokenProvider,
        _tokenRefresher = tokenRefresher,
        _socketFactory = socketFactory ?? ((token) => IoChatSocket(token));

  final Future<String?> Function() _tokenProvider;
  final Future<String?> Function()? _tokenRefresher;
  final ChatSocketFactory _socketFactory;

  ChatSocket? _socket;
  bool _connecting = false;
  String? _currentRoom;

  /// Dernier `join_*` émis, rejoué à chaque (re)connexion : le serveur oublie
  /// les rooms d'une socket déconnectée.
  void Function()? _rejoin;
  bool _isConnected = false;
  bool _hasConnectedOnce = false;
  bool _authRetried = false;

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  Stream<ChatEvent> get events => _events.stream;
  bool get isConnected => _isConnected;
  String? get currentRoom => _currentRoom;

  static String privateRoomName(String a, String b) =>
      ([a, b]..sort()).join('_');

  /// Le serveur a refusé le handshake et le refresh n'a pas suffi : la
  /// socket est inutilisable, le prochain [connect] la recrée.
  bool _authFailed = false;

  Future<void> connect() async {
    if (_connecting) return;
    final dead = _socket;
    if (dead != null) {
      if (!_authFailed) return;
      _socket = null;
      _closeSocket(dead);
    }
    _authFailed = false;
    _authRetried = false;
    _connecting = true;
    try {
      final token = await _tokenProvider();
      if (token == null) {
        logger.w('ChatConnection: pas de token, connexion ignorée');
        return;
      }
      _open(token);
    } finally {
      _connecting = false;
    }
  }

  void _open(String token) {
    final socket = _socketFactory(token);
    _socket = socket;
    socket.onConnect(() {
      if (!identical(_socket, socket)) return;
      final isReconnection = _hasConnectedOnce;
      _hasConnectedOnce = true;
      _isConnected = true;
      _authRetried = false;
      notifyListeners();
      // Rejoint la room ouverte ; après une coupure, l'écran recharge
      // l'historique pour récupérer les messages manqués.
      final room = _currentRoom;
      if (room != null) {
        _rejoin?.call();
        if (isReconnection) _events.add(ChatResynced(room));
      }
    });
    socket.onDisconnect(() {
      if (!identical(_socket, socket)) return;
      _isConnected = false;
      notifyListeners();
    });
    socket.onConnectError((error) => _onConnectError(socket, error));
    socket.on('receive_message', _onReceiveMessage);
    socket.on('receive_delete_message', _onDeleteMessage);
    socket.on('receive_delete_all_messages', _onDeleteAll);
    socket.on('notify_message', _onNotifyMessage);
    socket.on('error', (data) => logger.e('Socket error: $data'));
    socket.connect();
  }

  /// Le serveur refuse le handshake si l'access token a expiré (1 h) : on le
  /// rafraîchit une fois et on rouvre la socket avec le nouveau token.
  Future<void> _onConnectError(ChatSocket socket, dynamic error) async {
    if (!identical(_socket, socket)) return;
    final message = error is Map ? error['message'] : error?.toString();
    final isAuthError = '$message'.contains('Authentication error');
    if (!isAuthError) {
      logger.w('ChatConnection: connexion impossible ($message)');
      return;
    }
    if (_authRetried || _tokenRefresher == null) {
      logger.w('ChatConnection: connexion refusée ($message)');
      _authFailed = true;
      return;
    }
    _authRetried = true;
    final newToken = await _tokenRefresher();
    if (!identical(_socket, socket)) return;
    if (newToken == null) {
      _authFailed = true;
      return;
    }
    _closeSocket(socket);
    _open(newToken);
  }

  void joinGlobal() {
    _currentRoom = 'Global';
    _rejoin = () => _socket?.emit('join_global_room');
    _rejoin!();
  }

  void joinPrivate(String myId, String friendId) {
    _currentRoom = privateRoomName(myId, friendId);
    // Une List nue serait étalée par socket_io_client sur plusieurs arguments
    // (le backend ne recevrait que le 1er id) ; on enveloppe dans une Map.
    _rejoin = () => _socket?.emit('join_room', {
          'participants': [myId, friendId]
        });
    _rejoin!();
  }

  void leave(String roomName) {
    _socket?.emit('leave_room', roomName);
    if (_currentRoom == roomName) {
      _currentRoom = null;
      _rejoin = null;
    }
  }

  void _closeSocket(ChatSocket socket) {
    for (final event in _socketEvents) {
      socket.off(event);
    }
    socket.disconnect();
  }

  void disconnect() {
    final socket = _socket;
    _currentRoom = null;
    _rejoin = null;
    _hasConnectedOnce = false;
    _authRetried = false;
    _authFailed = false;
    if (socket == null) return;
    _socket = null;
    _closeSocket(socket);
    _isConnected = false;
    notifyListeners();
  }

  /// Room ciblée par un événement : le serveur la précise désormais dans le
  /// payload ; à défaut (ancien serveur) on suppose la room ouverte.
  String? _roomOf(Map<String, dynamic> payload) =>
      payload['roomName'] as String? ?? _currentRoom;

  Map<String, dynamic> _payload(dynamic data) {
    final raw = data is List ? data.first : data;
    return Map<String, dynamic>.from(raw as Map);
  }

  void _onReceiveMessage(dynamic data) {
    try {
      final payload = _payload(data);
      final room = _roomOf(payload);
      if (room == null) return;
      final message =
          Message.fromJson(Map<String, dynamic>.from(payload['message']));
      _events.add(MessageReceived(room, message));
    } catch (e) {
      logger.e('ChatConnection: parse receive_message: $e');
    }
  }

  // notify_message porte sa propre roomName (cross-room) : sert aux non-lus.
  void _onNotifyMessage(dynamic data) {
    try {
      final payload = _payload(data);
      final room = payload['roomName'] as String;
      final message =
          Message.fromJson(Map<String, dynamic>.from(payload['message']));
      _events.add(MessageNotified(room, message));
    } catch (e) {
      logger.e('ChatConnection: parse notify_message: $e');
    }
  }

  void _onDeleteMessage(dynamic data) {
    try {
      final payload = _payload(data);
      final room = _roomOf(payload);
      if (room == null) return;
      _events.add(MessageDeleted(room, payload['messageId']));
    } catch (e) {
      logger.e('ChatConnection: parse delete: $e');
    }
  }

  void _onDeleteAll(dynamic data) {
    String? room;
    try {
      room = _roomOf(_payload(data));
    } catch (_) {
      room = _currentRoom;
    }
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
