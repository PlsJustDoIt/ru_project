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

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_lorem/flutter_lorem.dart';
import 'dart:math';

class ChatUi extends StatefulWidget {
  ChatUi(
      {super.key,
      required this.roomName,
      required this.actualUser,
      this.friends})
      : user = User(
          id: actualUser.username,
          firstName: actualUser.username,
        );

  final ru_project.User actualUser;
  final List<ru_project.User>? friends;
  final User user;
  final String roomName;

  @override
  ChatUiState createState() => ChatUiState();
}

//TODO
class ChatUiState extends State<ChatUi> {
  CrossCache? _crossCache = CrossCache();
  final _uuid = const Uuid();
  late final List<Message> initialMessages;
  ChatController? _chatController;
  late final ApiService apiService;
  io.Socket? socket;

  @override
  void initState() {
    super.initState();
    apiService = Provider.of<ApiService>(context, listen: false);

    //récupérer les messages de la room
    _initializeMessages();

    //conexion au serveur
    connectToServer();
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
        socket?.emit("join_room", {participants});
      }
      socket?.on('receive_message', (response) {
        try {
          Map<String, dynamic> data = response[0];
          logger.i('Received_message: $data');
          ru_project.Message message =
              ru_project.Message.fromJson(data['message']);
          if (mounted) {
            setState(() {
              _chatController?.insert(Message.text(
                  id: message.id,
                  author: User(
                    id: message.sender,
                    firstName: message.sender,
                  ),
                  text: message.content,
                  createdAt: message.createdAt));
            });
          }
        } catch (e) {
          logger.e('Error parsing message data: $e');
        }
      });

      socket?.on('userOnline', (response) {
        Map<String, dynamic> data = response[0] ?? {};
        logger.i('User online: $data');
      });

      socket?.on('room_joined', (response) {
        Map<String, dynamic> data = response[0];
        logger.i("room joined, data: $data");
        logger.i('Room joined: ${data['roomName']}');
      });

      socket?.on('receive_delete_all_messages', (response) {
        logger.i('All messages deleted');
        if (mounted) {
          _chatController?.set([]);
        }
      });

      socket?.on('receive_delete_message', (response) {
        Map<String, dynamic> data = response[0];
        logger.i('Message deleted: ${data['messageId']}');
        if (mounted) {
          Message? message = _chatController?.messages.firstWhere(
            (element) => element.id == data['messageId'],
          );
          if (message != null) _chatController?.remove(message);
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
        _chatController = InMemoryChatController(messages: initialMessages);
      });
    }
  }

  //todo demander a leo pour les messages
  Future<List<Message>> setMessages() async {
    List<Message> messagesList = [];
    List<ru_project.Message>? messagesReceived =
        await apiService.getMessagesFromRoom(widget.roomName);
    if (messagesReceived != null) {
      for (ru_project.Message message in messagesReceived) {
        messagesList.add(Message.text(
          id: message.id,
          author: User(
            id: message.sender,
            firstName: message.sender,
          ),
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
    _chatController?.dispose();
    _chatController = null;
    _crossCache?.dispose();
    _crossCache = null;
    super.dispose();
  }

  void disconnectFromServer() {
    socket?.off('receive_message');
    socket?.disconnect();
    socket?.emit(('leave_room'), widget.roomName);
    socket?.dispose(); // Dispose the socket
    socket = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_chatController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chat(
      builders: Builders(
        textMessageBuilder: (context, message, index) =>
            FlyerChatTextMessage(message: message, index: index),
        imageMessageBuilder: (context, message, index) =>
            FlyerChatImageMessage(message: message, index: index),
        inputBuilder: (context) => ChatInput(
          topWidget: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: () => _addItem(null),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () async {
                  if (mounted) {
                    await _chatController!.set([]);
                    //TODO retirer les messages du serveur avec apiService
                    apiService.deleteMessages(widget.roomName).then((value) {
                      if (value == false && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete messages'),
                          ),
                        );
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      chatController: _chatController!,
      crossCache: _crossCache,
      user: widget.user,
      onMessageSend: _addItem,
      onMessageTap: _removeItem,
      onAttachmentTap: _handleAttachmentTap,
      theme: ChatTheme.fromThemeData(Theme.of(context)),
      themeMode: ThemeMode.light,
    );
  }

  //TODO refléchire a une fonction create message
  void _addItem(String? text) async {
    text ??=
        lorem(paragraphs: 1, words: Random().nextInt(30) + 1); //text aléatoire
    logger.i('Adding text $text to chat');

    final tempId = _uuid.v4();
    final message = Message.text(
      id: tempId,
      author: widget.user,
      createdAt: DateTime.now(),
      text: text,
    );

    if (mounted) {
      //ajout du message dans le chat local
      await _chatController!.insert(message);
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
        await _chatController!.update(message, nextMessage);
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

    final imageMessage = ImageMessage(
      id: id,
      author: widget.user,
      createdAt: DateTime.now().toUtc(),
      source: image.path,
    );

    // Insert message to UI before uploading (local)
    await _chatController!.insert(imageMessage);

    //TODO envoyer l'image au serveur avec apiService
  }

  void _removeItem(Message item) async {
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
                await _chatController!.remove(item);
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

  Future<void> _showDeleteConfirmationDialog(Message item) async {
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
