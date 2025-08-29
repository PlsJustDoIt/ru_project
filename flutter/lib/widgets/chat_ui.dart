import 'package:ru_project/models/user.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ru_project/models/user.dart' as ru_project;
import 'package:ru_project/models/message.dart' as ru_project;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:cross_cache/cross_cache.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:uuid/uuid.dart';
import 'package:flutter_lorem/flutter_lorem.dart';
import 'dart:math';

class ChatUi extends StatefulWidget {
  ChatUi(
      {super.key,
      required this.roomName,
      required this.actualUser,
      this.friends})
      : user = types.User(
          id: actualUser.username,
          name: actualUser.username,
        );

  final ru_project.User actualUser;
  final List<ru_project.User>? friends;
  final types.User user;
  final String roomName;

  @override
  ChatUiState createState() => ChatUiState();
}

//TODO
class ChatUiState extends State<ChatUi> {
  CrossCache? _crossCache = CrossCache();
  final _uuid = const Uuid();
  late final List<types.Message> initialMessages;
  List<types.Message> _messages = [];
  late final ApiService apiService;
  io.Socket? socket;
  //chat controller
  late final types.ChatController chatController;

  @override
  void initState() {
    super.initState();
    apiService = Provider.of<ApiService>(context, listen: false);

    //récupérer les messages de la room
    _initializeMessages();

    //conexion au serveur
    connectToServer();

    //initialisation du chat controller
    chatController = types.InMemoryChatController();
  }

  void connectToServer() async {
    try {
      socket = io.io(Config.serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'token': await apiService.secureStorage.getAccessToken(),
        },
        // 'withCredentials': true,
      });
      socket?.connect();
      //TODO change join_global_room to join_room
      if (widget.roomName == 'Global') {
        socket?.emit("join_global_room");
      } else {
        List<String> participants = [
          widget.actualUser.id,
          ...widget.friends!.map((e) => e.id)
        ];
        logger.i('Participants: $participants');
        // emit a map with participants
        socket?.emit("join_room", {'participants': participants});
      }
      socket?.on('receive_message', (response, [ack]) {
        try {
          Map<String, dynamic> data = response[0];
          logger.i('Received_message: $data');
          ru_project.Message message =
              ru_project.Message.fromJson(data['message']);
          if (ack != null) {
            ack({'status': 'ok'});
          }
          if (mounted) {
            final types.TextMessage incoming = types.TextMessage(
              id: message.id,
              authorId: message.sender,
              text: message.content,
              createdAt: message.createdAt,
            );
            setState(() {
              _messages.insert(0, incoming);
            });
          }
        } catch (e) {
          logger.e('Error parsing message data: $e');
        }
      });

      socket?.on('userOnline', (response, [ack]) {
        Map<String, dynamic> data = response[0] ?? {};
        if (ack != null) {
          ack({'status': 'ok'});
        }
        logger.i('User online: $data');
      });

      socket?.on('room_joined', (response, [ack]) {
        Map<String, dynamic> data = response[0];
        if (ack != null) {
          ack({'status': 'ok'});
        }
        logger.i("room joined, data: $data");
        logger.i('Room joined: ${data['roomName']}');
      });

      socket?.on('receive_delete_all_messages', (response, [ack]) {
        logger.i('All messages deleted');
        if (ack != null) {
          ack({'status': 'ok'});
        }
        if (mounted) {
          setState(() {
            _messages.clear();
          });
        }
      });

      socket?.on('receive_delete_message', (response, [ack]) {
        Map<String, dynamic> data = response[0];
        logger.i('Message deleted: ${data['messageId']}');
        if (ack != null) {
          ack({'status': 'ok'});
        }
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m.id == data['messageId']);
          });
        }
      });
    } catch (e) {
      logger.e('Error connecting to server: $e');
    }
  }

  Future<void> _initializeMessages() async {
    initialMessages = await setMessages();
    if (mounted) {
      setState(() {
        _messages = initialMessages;
      });
    }
  }

  //todo demander a leo pour les messages
  Future<List<types.Message>> setMessages() async {
    List<types.Message> messagesList = [];
    List<ru_project.Message>? messagesReceived =
        await apiService.getMessagesFromRoom(widget.roomName);
    if (messagesReceived != null) {
      for (ru_project.Message message in messagesReceived) {
        messagesList.add(types.TextMessage(
          id: message.id,
          authorId: message.sender,
          text: message.content,
          createdAt: message.createdAt,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch messages'),
          ),
        );
      }
      logger.e('Error getting messages from server');
    }
    return messagesList;
  }

  @override
  void dispose() {
    disconnectFromServer();
    _crossCache?.dispose();
    _crossCache = null;
    chatController.dispose();
    super.dispose();
  }

  void disconnectFromServer() {
    if (socket != null) {
      try {
        socket!.emit('leave_room', widget.roomName);
      } catch (e) {
        logger.w('Error emitting leave_room: $e');
      }
      try {
        socket!.off('receive_message');
        socket!.off('receive_delete_message');
        socket!.off('receive_delete_all_messages');
        socket!.off('userOnline');
        socket!.off('room_joined');
        socket!.disconnect();
      } catch (e) {
        logger.w('Error during socket cleanup: $e');
      }
    }
    socket = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ui.Chat(
      currentUserId: widget.user.id,
      resolveUser: (types.UserID id) async {
          return types.User(id: id, name: 'John Doe');
      },
      chatController: chatController,
    );
  }

  //TODO refléchire a une fonction create message
  void _addItem(String? text) async {
    text ??=
        lorem(paragraphs: 1, words: Random().nextInt(30) + 1); //text aléatoire
    logger.i('Adding text $text to chat');

    final tempId = _uuid.v4();
    final types.TextMessage message = types.TextMessage(
      id: tempId,
      authorId: widget.user.id,
      text: text,
      createdAt: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _messages.insert(0, message);
      });
    }

    //TODO envoyer le message au serveur avec apiService voir comme dans l'exemple
    try {
      ru_project.Message? response =
          await apiService.sendMessageToRoom(widget.roomName, text);
      if (response != null) {
        final nextMessage = message.copyWith(
          id: response.id,
          createdAt: response.createdAt,
        );
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) _messages[idx] = nextMessage;
          });
        }
        return;
      }
      logger.e('Error sending message to server');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
          ),
        );
      }
    } catch (e) {
      logger.e('Error sending message to server: $e');
    }
  }

  void _handleAttachmentTap() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final bytes = await image.readAsBytes();
    // Saves image to persistent cache using image.path as key
    await _crossCache?.set(image.path, bytes);

    final id = _uuid.v4();

    final bytesLength = bytes.length;
    final types.ImageMessage imageMessage = types.ImageMessage(
      id: id,
      authorId: widget.user.id,
      createdAt: DateTime.now(),
      source: image.path,
      size: bytesLength,
    );

    // Insert message to UI before uploading (local)
    setState(() {
      _messages.insert(0, imageMessage);
    });

    //TODO envoyer l'image au serveur avec apiService
  }

  void _removeItem(types.Message item) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer le message'),
          content:
              const Text('Etes-vous sûr de vouloir supprimer ce message ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Supprimer'),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _messages.removeWhere((m) => m.id == item.id);
                });
                bool res =
                    await apiService.deleteMessage(item.id, widget.roomName);
                if (res) {
                  logger.i('Message deleted');
                } else {
                  logger.e('Error deleting message');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(types.Message item) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _removeItem(item);
              },
            ),
          ],
        );
      },
    );
  }
}
