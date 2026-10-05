import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/logger.dart';

/// Une page d'historique de conversation.
class MessagePage {
  const MessagePage({required this.messages, required this.hasMore});

  final List<Message> messages;

  /// Des messages plus anciens existent côté serveur.
  final bool hasMore;
}

class SocketService {
  final Dio _dio;

  SocketService({required Dio dio}) : _dio = dio;

  /// Historique d'une room : les messages les plus récents (ou ceux
  /// antérieurs à [before]), en ordre chronologique. Null en cas d'erreur.
  Future<MessagePage?> getMessagesFromRoom(String roomName,
      {DateTime? before}) async {
    try {
      final Response response =
          await _dio.get('/socket/messages', queryParameters: {
        'roomName': roomName,
        if (before != null) 'before': before.toUtc().toIso8601String(),
      });
      if (response.statusCode == 200 && response.data != null) {
        final messages = [
          for (final message in response.data['messages'])
            Message.fromJson(Map<String, dynamic>.from(message))
        ];
        return MessagePage(
          messages: messages,
          hasMore: response.data['hasMore'] == true,
        );
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return null;
    }
  }

  /// Résumé des conversations : roomName -> dernier message (ou null si vide).
  Future<Map<String, Message?>> getConversations() async {
    try {
      final Response response = await _dio.get('/socket/conversations');
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, Message?> result = {};
        for (final conv in (response.data['conversations'] as List)) {
          final last = conv['lastMessage'];
          result[conv['roomName']] =
              last == null ? null : Message.fromJson(last);
        }
        return result;
      }
      logger.e('Invalid response from server: ${response.statusCode}');
      return {};
    } catch (e) {
      logger.e('Failed to get conversations: $e');
      return {};
    }
  }

  Future<Message?> sendMessageToRoom(String roomName, String content) async {
    try {
      final Response response = await _dio.post('/socket/send-message', data: {
        'roomName': roomName,
        'content': content,
      });
      if (response.statusCode == 201) {
        return Message.fromJson(
            Map<String, dynamic>.from(response.data['message']));
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to send message: $e');
      return null;
    }
  }

  /// Upload d'un message vocal (multipart). [durationSeconds] estimé côté client.
  /// Sur web, [filePath] est une URL blob: ; on en récupère les octets.
  Future<Message?> sendAudioMessage(
      String roomName, String filePath, int durationSeconds) async {
    try {
      final MultipartFile audio;
      if (kIsWeb) {
        final bytes = await http.readBytes(Uri.parse(filePath));
        audio = MultipartFile.fromBytes(
          bytes,
          filename: 'vocal.webm',
          contentType: DioMediaType('audio', 'webm'),
        );
      } else {
        audio = await MultipartFile.fromFile(filePath);
      }
      final formData = FormData.fromMap({
        'roomName': roomName,
        'duration': durationSeconds,
        'audio': audio,
      });
      final Response response =
          await _dio.post('/socket/send-audio', data: formData);
      if (response.statusCode == 201) {
        return Message.fromJson(response.data['message']);
      }
      logger.e('Invalid response from server: ${response.statusCode}');
      return null;
    } catch (e) {
      logger.e('Failed to send audio: $e');
      return null;
    }
  }

  // router.delete('/delete-messages
  Future<bool> deleteMessages(String roomName) async {
    try {
      final Response response = await _dio.delete('/socket/delete-all-messages',
          queryParameters: {'roomName': roomName});
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to delete messages: $e');
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId, String roomName) async {
    try {
      final Response response = await _dio.delete('/socket/delete-message',
          queryParameters: {'messageId': messageId, 'roomName': roomName});
      if (response.statusCode == 200) {
        return true;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return false;
    } catch (e) {
      logger.e('Failed to delete message: $e');
      return false;
    }
  }
}
