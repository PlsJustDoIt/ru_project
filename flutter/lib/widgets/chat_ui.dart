import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart' as ru_project;
import 'package:ru_project/models/message.dart' as ru_project;
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/chat_event.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/widgets/audio_player_widget.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as ui;
import 'package:uuid/uuid.dart';

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
  final List<ru_project.Friend>? friends;
  final types.User user;
  final String roomName;

  @override
  ChatUiState createState() => ChatUiState();
}

class ChatUiState extends State<ChatUi> {
  final _uuid = const Uuid();
  List<types.Message> _messages = [];
  late final SocketService socketService;
  late final ChatConnection chatConnection;
  StreamSubscription<ChatEvent>? _sub;
  late final types.ChatController chatController;

  @override
  void initState() {
    super.initState();
    socketService = Provider.of<SocketService>(context, listen: false);
    chatConnection = Provider.of<ChatConnection>(context, listen: false);
    chatController = types.InMemoryChatController();

    if (widget.roomName == 'Global') {
      chatConnection.joinGlobal();
    } else if (widget.friends != null && widget.friends!.isNotEmpty) {
      chatConnection.joinPrivate(
          widget.actualUser.id, widget.friends!.first.id);
    }

    _sub = chatConnection.events
        .where((e) => e.roomName == widget.roomName)
        .listen(_onChatEvent);

    _initializeMessages();
  }

  void _onChatEvent(ChatEvent event) {
    if (!mounted) return;
    switch (event) {
      case MessageReceived(:final message):
        final incoming = types.TextMessage(
          id: message.id,
          authorId: message.sender,
          text: message.content,
          createdAt: message.createdAt,
        );
        setState(() {
          _messages.insert(0, incoming);
          chatController.insertMessage(incoming);
        });
      case MessageDeleted(:final messageId):
        setState(() {
          final index = _messages.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final toRemove = chatController.messages[index];
            chatController.removeMessage(toRemove);
            _messages.removeAt(index);
          }
        });
      case AllMessagesDeleted():
        setState(() {
          _messages.clear();
        });
    }
  }

  Future<void> _initializeMessages() async {
    final messages = await setMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
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
    _sub?.cancel();
    chatConnection.leave(widget.roomName);
    chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return ui.Chat(
      currentUserId: widget.user.id,
      resolveUser: (types.UserID id) async {
        return types.User(id: id, name: id);
      },
      chatController: chatController,
      onMessageSend: (text) {
        _addItem(text);
      },
      onMessageTap: (context, message, {TapUpDetails? details, index = 0}) {
        logger.i('Message tapped: $details, index: $index');
        _removeItem(message);
      },
      builders: types.Builders(
        audioMessageBuilder: (
          BuildContext context,
          types.AudioMessage message,
          int index, {
          required bool isSentByMe,
          types.MessageGroupStatus? groupStatus,
        }) {
          return SizedBox(
            width: 250,
            child: AudioPlayerWidget(message: message),
          );
        },
      ),
    );
  }

  void _addItem(String text) async {
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
}
