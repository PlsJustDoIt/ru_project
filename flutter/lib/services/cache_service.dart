import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:ru_project/services/logger.dart'; // pour utf8

class AvatarCache {
  static Future<void> clearIfCacheTooLarge(
      Directory avatarDir, int maxFiles) async {
    final files = avatarDir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    // Si le nombre de fichiers dépasse la limite
    if (files.length > maxFiles) {
      for (var i = 0; i < files.length - maxFiles; i++) {
        await files[i].delete();
      }
    }
  }

  /// Méthode pour stocker et récupérer un fichier avatar
  static Future<File?> cacheAvatar(
      Uint8List avatarData, String fileName) async {
    try {
      // Calculer un hash unique pour identifier les données
      final hash = md5.convert(avatarData).toString();

      // Si l'application est en mode web
      if (kIsWeb) {
        return null; // Ne pas mettre en cache les avatars en mode web
      }

      // Obtenir le répertoire des documents de l'application
      final directory = await getApplicationDocumentsDirectory();

      // Créer un sous-dossier spécifique pour les avatars
      final avatarDir = Directory('${directory.path}/avatars');
      if (!await avatarDir.exists()) {
        await avatarDir.create(
            recursive: true); // Crée le dossier si nécessaire
      } else {
        await clearIfCacheTooLarge(avatarDir, 1);
      }
      // Construire le chemin complet du fichier
      final filePath = '${avatarDir.path}/$hash-$fileName';

      final file = File(filePath);

      // Vérifier si le fichier existe déjà
      if (await file.exists()) {
        return file; // Retourner le fichier existant
      }

      // Si non, écrire les données dans le fichier
      return await file.writeAsBytes(avatarData);
    } catch (e) {
      logger.e('Erreur lors de la mise en cache de l\'avatar: $e');
      return null;
    }
  }
}
