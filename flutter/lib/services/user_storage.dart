import 'dart:convert';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorageService {
  static const String _userKey = 'current_user';
  
  // Sauvegarder l'utilisateur
  static Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      final result = await prefs.setString(_userKey, userJson);
      logger.i('User saved successfully: ${user.toString()}');
      return result;
    } catch (e) {
      logger.e('Error saving user: $e');
      return false;
    }
  }

  // Récupérer l'utilisateur
  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson == null) {
        logger.i('No user found in storage');
        return null;
      }

      final userData = jsonDecode(userJson);
      return User.fromJson(userData);
    } catch (e) {
      logger.e('Error getting user: $e');
      return null;
    }
  }

  // Supprimer l'utilisateur
  static Future<bool> deleteUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_userKey);
      logger.i('User deleted from storage');
      return result;
    } catch (e) {
      logger.e('Error deleting user: $e');
      return false;
    }
  }

  // Vérifier si un utilisateur existe
  static Future<bool> hasUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userKey);
    } catch (e) {
      logger.e('Error checking user existence: $e');
      return false;
    }
  }
}