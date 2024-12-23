import 'package:ru_project/services/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  final void Function(Map<String, dynamic> data) onWaitingTimeUpdate;

  SocketService({required this.onWaitingTimeUpdate}) {
    initSocket();
  }

  void initSocket() {
    socket = IO.io('http://votre-serveur.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
    });

    socket.onConnect((_) {
      logger.i('Connecté au serveur Socket.IO');
    });

    socket.on('initial_data', (data) {
      logger.i('Données initiales reçues');
      // Traiter les données initiales
    });

    socket.on('waiting_time_update', (data) {
      onWaitingTimeUpdate(data);
    });

    socket.onDisconnect((_) {
      logger.i('Déconnecté du serveur');
    });

    socket.onError((error) {
      logger.i('Erreur Socket.IO: $error');
    });

    socket.onReconnect((_) {
      logger.i('Reconnecté au serveur');
    });
  }

  void subscribeToLocation(String locationId) {
    socket.emit('subscribe_location', locationId);
  }

  void dispose() {
    socket.dispose();
  }
}
