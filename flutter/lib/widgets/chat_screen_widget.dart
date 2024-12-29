import 'package:flutter/material.dart';
import 'package:ru_project/services/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:ru_project/config.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  io.Socket? socket;
  TextEditingController messageController = TextEditingController();
  List<String> messages = [];

  @override
  void initState() {
    connectToServer();
    super.initState();
  }

  @override
  void dispose() {
    socket?.disconnect();
    super.dispose();
  }

  void connectToServer() {
    socket = io.io(Config.serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket?.connect();
    socket?.on('receive_message', (data) {
      if (data is String) {
        logger.i('Message received: $data');
        setState(() {
          messages.add(data);
        });
      }

      if (data is List) {
        logger.i('Message received: $data'); // data is an array
        logger.i(data.runtimeType);
        logger.i(data.length);
        setState(() {
          messages.add(data[0]);
        });
      }
      // logger.i('Message received: $data'); // data is an array
      // logger.i(data.runtimeType);
      // setState(() {
      //   messages.add(data[0]);
      // });
    });
  }

  void sendMessage() {
    String message = messageController.text.trim();
    if (message.isNotEmpty) {
      socket?.emit('send_message', message);
      messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Socket.IO Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(messages[index]),
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
                onPressed: sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
