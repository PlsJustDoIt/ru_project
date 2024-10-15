import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/user.dart';
import '../models/menu.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// class TokenManager {
//   final _storage = const FlutterSecureStorage();

//   Future<void> storeToken(String token) async {
//     await _storage.write(key: 'jwt', value: token);
//   }

//   Future<String?> getToken() async {
//     return await _storage.read(key: 'jwt');
//   }

//   Future<void> deleteToken() async {
//     await _storage.delete(key: 'jwt');
//   }

//   // Future<bool> isTokenValid() async {
//   // final token = await _storage.read(key: 'jwt');
//   // if (token == null) return false;

//   // // Décoder la partie payload du JWT (2e partie du token séparée par des points)
//   // final parts = token.split('.');
//   // if (parts.length != 3) return false;

//   // // Le payload est en base64
//   // final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

//   // // Vérification de la date d'expiration
//   // final exp = payload['exp'];
//   // final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);

//   // return DateTime.now().isBefore(expirationDate);  // Retourne true si le token n'est pas expiré
//   //}
// }

class MenuProvider with ChangeNotifier {
  Map<String,dynamic> menuRawData = {};
  List<Menu> menus = [];
}
