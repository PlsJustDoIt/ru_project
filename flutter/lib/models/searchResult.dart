// Modèle de résultat de recherche avec score de pertinence pour search_user_widget.dart
import 'package:ru_project/models/user.dart';
import '../services/logger.dart';

class SearchResult {
  final User user;
  final double relevanceScore;

  SearchResult({
    required this.user,
    required this.relevanceScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'relevanceScore': relevanceScore,
    };
  }

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    try {
      return SearchResult(
        user: User.fromJson(json['user']),
        relevanceScore: json['relevanceScore'],
      );
    } catch (e) {
      logger.e(e);
      rethrow;
    }
  }

  @override
  String toString() {
    return 'SearchResult{user: $user, relevanceScore: $relevanceScore}';
  }
}
