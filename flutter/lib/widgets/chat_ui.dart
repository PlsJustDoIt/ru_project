import 'package:ru_project/services/secure_storage.dart';
import 'package:ru_project/services/socket_service.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart' as ru_project;
import 'package:ru_project/models/message.dart' as ru_project;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/services/logger.dart';
import 'package:cross_cache/cross_cache.dart';
import 'audio_player_widget.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:uuid/uuid.dart';
import 'package:flutter_lorem/flutter_lorem.dart';
import 'dart:math';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_chat_core/src/models/builders.dart';
import 'package:flutter_chat_core/src/models/message_group_status.dart';

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

class ChatUiState extends State<ChatUi> {
  CrossCache? _crossCache = CrossCache();
  final _uuid = const Uuid();
  late final List<types.Message> initialMessages;
  List<types.Message> _messages = [];
  late final ApiService apiService;
  io.Socket? socket;
  //chat controller
  late final types.ChatController chatController;

  final _record = AudioRecorder();
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    socketService = Provider.of<SocketService>(context, listen: false);
    secureStorage = Provider.of<SecureStorage>(context, listen: false);

    //initialisation du chat controller
    chatController = types.InMemoryChatController();

    //récupérer les messages de la room
    _initializeMessages();

    //conexion au serveur
    connectToServer();
  }

  Future<void> _startRecording() async {
    if (await _record.hasPermission()) {
      final path =
          '/tmp/${_uuid.v4()}.mp3'; // tu peux adapter selon ta plateforme
      await _record.start(
          const RecordConfig(
            encoder: kIsWeb
                ? AudioEncoder.wav // Web → wav (PCM)
                : AudioEncoder.aacLc, // Mobile → AAC
          ),
          path: path);
      _recordPath = kIsWeb ? null : path;
    }
  }

  Future<void> _stopRecording() async {
    final pathOrUri =
        await _record.stop(); // Mobile = path | Web = blob:... URL
    if (pathOrUri == null) return;

    final player = AudioPlayer();
    Duration duration = Duration.zero;

    if (!kIsWeb) {
      // --- MOBILE ---
      await player.setFilePath(pathOrUri);
      duration = player.duration ?? Duration.zero;

      final file = File(pathOrUri);
      final audioMessage = types.AudioMessage(
          id: _uuid.v4(),
          authorId: widget.user.id,
          createdAt: DateTime.now(),
          duration: duration,
          source: pathOrUri,
          size: await file.length(),
          waveform: [2, 3, 5, 6]);

      setState(() {
        _messages.insert(0, audioMessage);
        chatController.insertMessage(audioMessage);
      });

      // 👉 Upload si besoin
      // await apiService.sendAudioToRoom(widget.roomName, file);
    } else {
      // --- WEB ---
      // pathOrUri est une URL de type "blob:...."
      await player.setUrl(pathOrUri);
      duration = player.duration ?? Duration.zero;

      final audioMessage = types.AudioMessage(
        id: _uuid.v4(),
        authorId: widget.user.id,
        createdAt: DateTime.now(),
        duration: duration,
        source: pathOrUri, // <- blob utilisable directement avec <audio>
        size: 0, // pas dispo en web
      );

      setState(() {
        _messages.insert(0, audioMessage);
        chatController.insertMessage(audioMessage);
      });

      // 👉 Upload côté web : tu envoies le blobUrl,
      // ton backend devra recevoir le blob via JS/HTML (pas possible direct Flutter)
    }

    await player.dispose();
  }

  void connectToServer() async {
    try {
      socket = io.io(Config.serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'query': {
          'token': await secureStorage.getAccessToken(),
        },
        // 'withCredentials': true,
      });
      socket?.connect();
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
              chatController.insertMessage(incoming);
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
        //TODO ?
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
            final index =
                _messages.indexWhere((m) => m.id == data['messageId']);
            if (index != -1) {
              final messageToRemove = chatController.messages[index];
              chatController.removeMessage(messageToRemove);
              _messages.removeAt(index);
            }
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
        chatController.insertAllMessages(_messages);
      });
    }
  }

  Future<List<types.Message>> setMessages() async {
    List<types.Message> messagesList = [];
    List<ru_project.Message>? messagesReceived =
        await socketService.getMessagesFromRoom(widget.roomName);
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
        return types.User(
            id: id, name: 'John Doe'); //TODO fetch user info from server?
      },
      chatController: chatController,
      onMessageSend: (text) {
        _addItem(text);
      },
      onMessageTap: (context, message, {TapUpDetails? details, index = 0}) {
        logger.i('Message tapped: ${details}, index: $index');
        _removeItem(message);
      },
      onAttachmentTap: () async {
        // Ici on déclenche l’enregistrement audio
        await _startRecording();

        // on attend que l’utilisateur relâche le bouton (par ex. via un dialogue)
        await Future.delayed(const Duration(seconds: 8));
        await _stopRecording();
      },
      builders: Builders(
        audioMessageBuilder: (
          BuildContext context,
          types.AudioMessage message,
          int index, {
          required bool isSentByMe,
          MessageGroupStatus? groupStatus,
        }) {
          // You may want to use index, isSentByMe, groupStatus for custom UI
          return Container(
            // Example: fixed width or from message metadata
            width: 250,
            child: AudioPlayerWidget(message: message),
          );
        },
      ),

      // builders: audioMessageBuilder(
      //   customMessageBuilder: (message, {required int messageWidth}) {
      //     if (message is types.CustomMessage &&
      //         message.metadata?['type'] == 'audio') {
      //       final player = AudioPlayer();
      //       final uri = message.metadata!['uri'] as String;

      //       return Row(
      //         children: [
      //           IconButton(
      //             icon: const Icon(Icons.play_arrow),
      //             onPressed: () async {
      //               await player.setFilePath(uri);
      //               await player.play();
      //             },
      //           ),
      //           const Text("Message audio"),
      //         ],
      //       );
      //     }
      //     return const SizedBox();
      //   },
      // ),
    );
  }

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

    chatController.insertMessage(message);
    if (mounted) {
      setState(() {
        _messages.insert(0, message);
      });
    }

    try {
      ru_project.Message? response =
          await socketService.sendMessageToRoom(widget.roomName, text);
      if (response != null) {
        final nextMessage = message.copyWith(
          id: response.id,
          createdAt: response.createdAt,
        );
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == tempId);
            if (idx != -1) _messages[idx] = nextMessage;
            chatController.updateMessage(message, nextMessage);
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

  // this feature is disabled for now
  // void _handleAttachmentTap() async {
  //   final picker = ImagePicker();

  //   final image = await picker.pickImage(source: ImageSource.gallery);

  //   if (image == null) return;

  //   final bytes = await image.readAsBytes();
  //   // Saves image to persistent cache using image.path as key
  //   await _crossCache?.set(image.path, bytes);

  //   final id = _uuid.v4();

  //   final bytesLength = bytes.length;
  //   final types.ImageMessage imageMessage = types.ImageMessage(
  //     id: id,
  //     authorId: widget.user.id,
  //     createdAt: DateTime.now(),
  //     source: image.path,
  //     size: bytesLength,
  //   );

  //   // Insert message to UI before uploading (local)
  //   setState(() {
  //     _messages.insert(0, imageMessage);
  //   });

  //   //envoyer l'image au serveur avec apiService
  // }

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
                  chatController.removeMessage(item);
                });

                bool res =
                    await socketService.deleteMessage(item.id, widget.roomName);
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

  // deprecated
  // Future<void> _showDeleteConfirmationDialog(types.Message item) async {
  //   return showDialog<void>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Delete Message'),
  //         content: const Text('Are you sure you want to delete this message?'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('Cancel'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //           TextButton(
  //             child: const Text('Delete'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _removeItem(item);
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
}
