import 'dart:async';
import 'dart:ui_web';

import 'package:flutter/material.dart';
//import 'package:ru_project/models/user.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_image_message/flyer_chat_image_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:cross_cache/cross_cache.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ru_project/services/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_lorem/flutter_lorem.dart';
import 'dart:math';

//WIP pour le momment tout sera en statique
class ChatUi extends StatefulWidget {
  ChatUi({super.key});
  User user = User(
    id: '1234',
    firstName: 'Test1',
    lastName: 'Test2',
  ); //TODO utiliser notre propre user qui sera passé en paramètre
  final String chatId =
      '4567'; //TODO utiliser id room qui sera passé en paramètre

  //ici on simule des utilisateurs qui enverront des messages
  static final User otherUserA = User(
    id: '5678',
    firstName: 'Toto',
    lastName: 'LAPOINTE',
  );
  static final User otherUserB = User(
    id: '5678',
    firstName: 'Jacques',
    lastName: 'SELAIRE',
  );
  final List<Message> initialMessages = [
    Message.text(
      id: '1',
      author: otherUserA,
      createdAt: DateTime(2021, 1, 1),
      text: "Hello!",
    ),
    Message.text(
      id: '2',
      author: otherUserB,
      createdAt: DateTime(2021, 1, 1),
      text: "Hi!",
    )
  ];
  //TODO on passera aussi une instance de apiService plus tard

  @override
  ChatUiState createState() => ChatUiState();
}

//TODO
class ChatUiState extends State<ChatUi> {
  final CrossCache _crossCache = CrossCache();
  final _uuid = const Uuid();

  late final ChatController _chatController;

  @override
  void initState() {
    super.initState();
    _chatController = InMemoryChatController(messages: widget.initialMessages);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _crossCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    await _chatController.set([]);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      chatController: _chatController,
      crossCache: _crossCache,
      user: widget.user,
      onMessageSend: _addItem,
      onMessageTap: _removeItem,
      onAttachmentTap: _handleAttachmentTap,
    );
  }

  // InputActionBar(
  //           buttons: [
  //             InputActionButton(
  //               icon: Icons.shuffle,
  //               title: 'Send random text msg',
  //               onPressed: () => _addItem(null),
  //             ),
  //             InputActionButton(
  //               icon: Icons.delete_sweep,
  //               title: 'Clear all',
  //               onPressed: () async {
  //                 if (mounted) {
  //                   await _chatController.set([]);
  //                 }
  //               },
  //               destructive: true,
  //             ),
  //           ],
  //         )

  //TODO
  void _addItem(String? text) async {
    text ??=
        lorem(paragraphs: 1, words: Random().nextInt(30) + 1); //text aléatoire
    logger.i('Adding text $text to chat');
    final message = Message.text(
      id: _uuid.v4(),
      author: widget.user,
      createdAt: DateTime.now(),
      text: text!,
    );

    if (mounted) {
      //ajout du message dans le chat local
      await _chatController.insert(message);
    }

    //TODO envoyer le message au serveur avec apiService
  }

  void _handleAttachmentTap() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final bytes = await image.readAsBytes();
    // Saves image to persistent cache using image.path as key
    await _crossCache.set(image.path, bytes);

    final id = _uuid.v4();

    final imageMessage = ImageMessage(
      id: id,
      author: widget.user,
      createdAt: DateTime.now().toUtc(),
      source: image.path,
    );

    // Insert message to UI before uploading (local)
    await _chatController.insert(imageMessage);

    //TODO envoyer l'image au serveur avec apiService
  }

  void _removeItem(Message item) async {
    await _chatController.remove(item); // retirer le message du chat local

    //TODO retirer le message du serveur avec apiService
  }
}
