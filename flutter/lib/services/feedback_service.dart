import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:ru_project/config.dart';
import 'package:ru_project/services/logger.dart';

class FeedbackService {
  final Dio _dio;

  FeedbackService({required Dio dio}) : _dio = dio;

  Future<bool> sendFeedback(UserFeedback feedback) async {
    try {
      String timestamp = DateFormat('ddMMyyyy_HHmmss').format(DateTime.now());
      String filename = 'bug_screenshot_$timestamp.png';
      FormData formData = FormData.fromMap({
        'description': feedback.text,
        'screenshot': MultipartFile.fromBytes(feedback.screenshot,
            filename: filename, contentType: DioMediaType('image', 'png')),
        'extra': feedback.extra,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'app_version': Config.appVersion,
      });

      final response =
          await _dio.post('/users/send-bug-report', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      logger.e('Failed to send feedback: ${response.data["error"]}');
      return false;
    } catch (e) {
      logger.e('Error sending feedback: $e');
      return false;
    }
  }
}
