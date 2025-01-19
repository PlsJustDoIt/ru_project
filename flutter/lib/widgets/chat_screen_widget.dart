import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:ru_project/models/room.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  io.Socket? socket;
  TextEditingController messageController = TextEditingController();
  List<Message> messages = [];
  late String roomId;
  late ApiService apiService;

  String replaceSmileysWithEmojisUsingRegex(String input) {
    final Map<String, String> smileyToEmoji = {
      '<3': '❤️', // Cœur
      ':D': '😃', // Visage heureux avec grand sourire
      ':)': '😊', // Visage souriant
      ':(': '😢', // Visage triste
      ':P': '😜', // Tirant la langue
      ';)': '😉', // Clin d'œil
      'XD': '😆', // Rire
      ':o': '😮', // Surpris
      'B)': '😎', // Lunettes de soleil
      ':/': '😕', // Embarrassé / Mécontent
      ':\'(': '😭', // Pleure
      ':|': '😐', // Neutre
      ':*': '😘', // Envoie un baiser
      '<\\3': '💔', // Cœur brisé
      ':@': '😡', // En colère
      'O:)': '😇', // Ange
      '>:)': '😈', // Diable
      'D:': '😱', // Cri
      ':\$': '😳', // Gêné
      ':^)': '🤡', // Clown
      '<(^_^)>': '🎉', // Célébration
      ':3': '😺', // Visage de chat souriant
      ':L': '😣', // Frustré
      ':#': '🤐', // Bouche fermée
      ':thumbs_up:': '👍',
    };

    final smileyRegex = RegExp(
        r"(<3|:\)|:\(|:D|:P|;\)|XD|:O|B\)|:/|:\'\(|:\||:\*|<\\3|:@|O:\)|>:\)|D:|:\$|:\^\)|<\(\^_\^\)>|:3|:L|:#)",
        caseSensitive: false);

    return input.replaceAllMapped(smileyRegex, (match) {
      return smileyToEmoji[match.group(0)?.toLowerCase() ?? match.group(0)!] ??
          match.group(0)!;
    });
  }

  @override
  void initState() {
    apiService = Provider.of<ApiService>(context, listen: false);
    apiService.getMessagesChatRoom().then((value) {
      if (value == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch messages'),
          ),
        );
      }

      value = value!.map((message) {
        message.content = replaceSmileysWithEmojisUsingRegex(message.content);
        return message;
      }).toList();

      setState(() {
        messages = value ?? [];
      });
    });

    connectToServer();

    super.initState();
  }

  @override
  void dispose() {
    logger.i('dispose');
    messageController.dispose();
    disconnectFromServer();
    super.dispose();
  }

  void disconnectFromServer() {
    socket?.off('receive_message');
    socket?.disconnect();
    socket?.emit(('leave_room'), roomId);
    socket?.dispose(); // Dispose the socket
    socket = null;
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
      socket?.emit("join_global_room", "test");
      socket?.on('receive_message', (response) {
        try {
          Map<String, dynamic> data = response[0];
          logger.i('Received_message: $data');
          Message message = Message.fromJson(data['message']);
          message.content = replaceSmileysWithEmojisUsingRegex(message.content);
          if (mounted) {
            setState(() {
              messages.add(message);
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
        logger.i('Room joined: ${data['roomId']}');

        logger.i('Room joined: ${data['roomId']}');
        setState(() {
          roomId = data['roomId'];
        });
      });
    } catch (e) {
      logger.e('Error connecting to server: $e');
    }
  }

  Future<void> sendMessage(String message) async {
    Message? messageCreated = await apiService.sendMessageChatRoom(message);

    if (messageCreated == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
          ),
        );
      }
      return;
    }

    messageCreated.content =
        replaceSmileysWithEmojisUsingRegex(messageCreated.content);
    setState(() {
      messages.add(messageCreated);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Socket.IO Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              apiService.deleteMessages(roomId).then((value) {
                if (value == false && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete messages'),
                    ),
                  );
                } else {
                  setState(() {
                    messages = [];
                  });
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message.content),
                  subtitle: Text(message.sender),
                  trailing: Text(timeAgo(message.createdAt)),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    hintText: 'Tape ton putain de message',
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  if (messageController.text.isNotEmpty) {
                    sendMessage(messageController.text);
                    messageController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => false; // TODO a voir
}
