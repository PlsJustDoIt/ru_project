import 'package:ru_project/services/logger.dart';

String? validateUsername(String? value) {
  if (value == null || value.isEmpty) {
    return 'Veuillez entrer un nom d\'utilisateur (3-32 caractères)';
  }
  if (value.trim().isEmpty) {
    return 'Veuillez entrer un nom d\'utilisateur valide';
  }
  if (value.length > 32) {
    return 'Le nom d\'utilisateur doit comporter moins de 32 caractères';
  }
  if (value.length < 3) {
    return 'Le nom d\'utilisateur doit comporter au moins 3 caractères';
  }
  return null;
}

String? validatePassword(String? value, {String? apiError}) {
  if (apiError != null && apiError.isNotEmpty) {
    return apiError;
  }
  if (value == null || value.isEmpty) {
    return 'Veillez entrer un mot de passe (3-32 caractères)';
  }
  if (value.trim().isEmpty) {
    return 'Veillez entrer un mot de passe valide';
  }
  if (value.length < 3) {
    return 'Le mot de passe doit comporter au moins 3 caractères';
  }
  if (value.length > 32) {
    return 'Le mot de passe doit comporter moins de 32 caractères';
  }
  return null;
}
