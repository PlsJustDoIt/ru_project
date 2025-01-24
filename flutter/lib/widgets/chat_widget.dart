import 'package:flutter/material.dart';
import 'package:ru_project/widgets/chat_ui.dart';
import 'package:ru_project/models/user.dart';

class ChatWidget extends StatelessWidget {
  final String roomname;
  final User actualUser;
  final List<User>? friends;

  const ChatWidget(
      {super.key,
      required this.roomname,
      required this.actualUser,
      this.friends});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Chat'),
      ),
      body:
          ChatUi(roomName: roomname, actualUser: actualUser, friends: friends),
    );
  }
}
