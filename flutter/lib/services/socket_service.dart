import 'package:dio/dio.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/logger.dart';

class SocketService {
  final Dio _dio;

  SocketService({required Dio dio}) : _dio = dio;

  Future<List<Message>?> getMessagesChatRoom() async {
    try {
      final Response response = await _dio.get('/socket/chat-room');
      if (response.statusCode == 200 && response.data != null) {
        List<Message> messages = [
          for (Map<String, dynamic> message in response.data['messages'])
            Message.fromJson(message)
        ];
        return messages;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return null;
    }
  }

  Future<Message?> sendMessageChatRoom(String content) async {
    try {
      final Response response =
          await _dio.post('/socket/send-chat-room', data: {
        'content': content,
      });
      if (response.statusCode == 201) {
        Message message = Message.fromJson(response.data['message']);
        return message;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to send message: $e');
      return null;
    }
  }

  Future<List<Message>?> getMessagesFromRoom(String roomName) async {
    try {
      final Response response =
          await _dio.get('/socket/messages', queryParameters: {
        'roomName': roomName,
      });
      if (response.statusCode == 200 && response.data != null) {
        List<Message> messages = [
          for (Map<String, dynamic> message in response.data['messages'])
            Message.fromJson(message)
        ];
        return messages;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to get messages: $e');
      return null;
    }
  }

  Future<Message?> sendMessageToRoom(String roomName, String content) async {
    try {
      final Response response = await _dio.post('/socket/send-message', data: {
        'roomName': roomName,
        'content': content,
      });
      if (response.statusCode == 201) {
        Message message = Message.fromJson(response.data['message']);
        return message;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return null;
    } catch (e) {
      logger.e('Failed to send message: $e');
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
