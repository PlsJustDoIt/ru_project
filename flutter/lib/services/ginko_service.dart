import 'package:dio/dio.dart';
import 'package:ru_project/services/logger.dart';

class GinkoService {
  final Dio _dio;

  GinkoService({required Dio dio}) : _dio = dio;

  Future<Map<String, dynamic>> getHoraires({String lieu = "crous"}) async {
    try {
      final Response response = await _dio.get('/ginko/info', queryParameters: {
        'lieu': lieu,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      logger.e(
          'Invalid response from server: ${response.statusCode} ${response.data['error']}');
      return {};
    } catch (e) {
      logger.e('Failed to get profile picture: $e');
      return {};
    }
  }
}
