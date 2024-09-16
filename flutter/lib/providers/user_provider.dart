import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/menu.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  final _storage = const FlutterSecureStorage();

  Future<void> storeToken(String token) async {
    await _storage.write(key: 'jwt', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt');
  }

    // Future<bool> isTokenValid() async {
    // final token = await _storage.read(key: 'jwt');
    // if (token == null) return false;

    // // Décoder la partie payload du JWT (2e partie du token séparée par des points)
    // final parts = token.split('.');
    // if (parts.length != 3) return false;

    // // Le payload est en base64
    // final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    
    // // Vérification de la date d'expiration
    // final exp = payload['exp'];
    // final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    
    // return DateTime.now().isBefore(expirationDate);  // Retourne true si le token n'est pas expiré
    //}

}

class UserProvider with ChangeNotifier {
  User? _user;
  String? _token;
  List<User> _friends = [];

  // Getters
  User? get user => _user;
  String? get token => _token;
  List<User> get friends => _friends;


  Future<bool> isConnected() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final expirationTime = prefs.getString('tokenExpiration');

  if (token == null || expirationTime == null) {
    return false; // Pas de token ou pas d'heure d'expiration
  }

  final expirationDate = DateTime.parse(expirationTime);

  // Comparer l'heure actuelle avec l'heure d'expiration
  if (DateTime.now().isAfter(expirationDate)) {
    // Token expiré, supprimer le token
    await prefs.remove('token');
    await prefs.remove('tokenExpiration');
    return false;
  }

  return true; // Token toujours valide
}

  Future<void> storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    // Stocker le token
    await prefs.setString('token', token);

    // Stocker l'heure d'expiration (1 heure après l'heure actuelle)
    final expirationTime = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
    await prefs.setString('tokenExpiration', expirationTime);
  }

  // Méthode pour se connecter
  Future<void> login(String username, String password) async {
    final token = await ApiService.login(username, password); //response is dynamic //TODO géré les erreurs
    if (token != null) {
      _token = token;
      await fetchUserData();
      notifyListeners();
    } else {
      _token = null;
      _user = null;
      handleLoginError();
      notifyListeners();
    }
  }

  Future<String?> register(String username, String password) async {
    final token = await ApiService.register(username, password);
    if (token != null) {
      _token = token;
      await fetchUserData();
      notifyListeners();
      return "Inscription réussie";
    } else {
      _token = null;
      _user = null;
      handleLoginError();
      notifyListeners();
      return "Erreur d'inscription";
    }
  }

   // Méthode pour récupérer les données utilisateur après la connexion
  Future<void> fetchUserData() async {
    if (_token != null) {
      final userData = await ApiService.getUser(_token!);
      if (userData != null) {
        _user = User.fromJson(userData);
      } else {
        _user = null;
        _token = null;
      }
      notifyListeners();
      
    }
  }

  // Méthode pour mettre à jour l'état de l'utilisateur
  Future<void> updateStatus(String newStatus) async {
    if (_token == null || _user == null) return;

    final success = await ApiService.updateStatus(_token!, newStatus);
    if (success) {
      _user!.status = newStatus;
      notifyListeners();
    }
  }

  // Méthode pour ajouter un ami
  Future<void> addFriend(String friendUsername) async {
    if (_token == null) return;

    final success = await ApiService.addFriend(_token!, friendUsername);
    if (success) {
      // Mettez à jour la liste des amis après l'ajout
      await fetchFriends();
    }
  }

  // Méthode pour récupérer la liste des amis et leurs états
  Future<void> fetchFriends() async {
    if (_token == null) return;

    final friendsData = await ApiService.getFriends(_token!);
    if (friendsData != null) {
      _friends = friendsData['friends'].map<User>((json) => User.fromJson(json)).toList();
      notifyListeners();
    }
  }

  //methode pour recuperer les menus,TODO  gerer les erreurs
  //example of a json response : 
  /*
  [
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "GRATIN DE COQUILETTES /DES DE DINDE",
            "BATONNIERE DE LEGUMES"
        ],
        "Menu végétalien": [
            "CHILI BOULGOUR"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "CORDON BLEU",
            "FRITES"
        ],
        "date": "vendredi 6 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "BLANQUETTE  D' EMINCE DE DINDE",
            "RIZ",
            "CAROTTES"
        ],
        "Menu végétalien": [
            "GNOCCHIS AUX CHAMPIGNONS"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "SAUCISSE FUMEE",
            "FRITES"
        ],
        "date": "lundi 9 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "ESCALOPE  DE PORC SC CURRY",
            "POISSON PANE A LA TOMATE",
            "SC CHARCUTIERE",
            "PUREE",
            "HARICOTS VERTS"
        ],
        "Menu végétalien": [
            "EMINCE DE POIS CHICHES"
        ],
        "Pizza": [
            "GARNITURE PARMENTIERE"
        ],
        "Cuisine italienne": "menu non communiqué",
        "Grill": "menu non communiqué",
        "date": "mardi 10 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "GARNITURE ESPAGNOLE",
            "PATES",
            "POELEE ORIENTALE"
        ],
        "Menu végétalien": [
            "RISOTTO VERTS AUX PETITS POIS"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "CUISSE DE POULET",
            "FRITES"
        ],
        "date": "mercredi 11 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "SAUTE PORC CREOLE  SC BLEU",
            "BLANQUETTE DE COLIN AUX PETITS LEGUMES",
            "BOULGOUR BIO",
            "CAROTTES"
        ],
        "Menu végétalien": [
            "OMELETTE NATURE"
        ],
        "Pizza": [
            "CHEVRES /LEGUMES"
        ],
        "Cuisine italienne": "menu non communiqué",
        "Grill": "menu non communiqué",
        "date": "jeudi 12 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "JAMBON GRILLE SC MADERE",
            "RIZ",
            "COURGETTES"
        ],
        "Menu végétalien": [
            "CURRY DE POIS CHICHES"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "CORDON BLEU DINDE",
            "FRITES"
        ],
        "date": "vendredi 13 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "COTE DE PORC SC IVOIRE",
            "BOULGOUR BIO",
            "HARICOTS BEURRE"
        ],
        "Menu végétalien": [
            "CHILI BOULGOUR"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "NUGGETS DE POULET",
            "FRITES"
        ],
        "date": "lundi 16 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "emince de dinde aux cacahuettes",
            "poisson blanc sc dijonnaise",
            "pates",
            "poelee asiatique"
        ],
        "Menu végétalien": [
            "bolognaise au soja"
        ],
        "Pizza": [
            "PIZZA         GARNITURE SAUCISSE FUMEE"
        ],
        "Cuisine italienne": "menu non communiqué",
        "Grill": "menu non communiqué",
        "date": "mardi 17 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "roti de veau farci sc echalotes",
            "RIZ BIO",
            "CHOUX FLEURS"
        ],
        "Menu végétalien": [
            "DAHL DE LENTILLES"
        ],
        "Pizza": "menu non communiqué",
        "Cuisine italienne": "menu non communiqué",
        "Grill": [
            "CREPE JAMBON/FROMAGE SC BECHAMEL",
            "FRITES"
        ],
        "date": "mercredi 18 septembre 2024"
    },
    {
        "Entrées": [
            "VARIATIONS DE SALADES VERTES.....",
            "COMPOSÉES  OU NATURES...",
            "CHARCUTERIE TERRE ET MER",
            "ASSORTIMENTS DE CRUDITÉS"
        ],
        "Cuisine traditionnelle": [
            "EMINCE DE BŒUF SC GOULASH",
            "CUBES DE POISSON SC GINGEMBRE",
            "PDT RONDES PERSILLEES",
            "EPINARDS"
        ],
        "Menu végétalien": [
            "GNOCCHIS COURGETTES /CHEVRE"
        ],
        "Pizza": [
            "PIZZA",
            "GARNITURE JAMBON"
        ],
        "Cuisine italienne": "menu non communiqué",
        "Grill": "menu non communiqué",
        "date": "jeudi 19 septembre 2024"
    }
]
  */
  //For now, the method returns a list of Menu objects, to be used in the MenuWidget, TODO : tester
  Future<List<Menu>> fetchMenus() async {
    if (_token == null) return [];
    final menusData = await ApiService.getMenusD(_token!);
    if (menusData != null) {
      return menusData;
    }
    return [];
  }

  // Méthode pour se déconnecter
  void logout() {
    _user = null;
    _token = null;
    _friends = [];
    notifyListeners();
  }

  
  void handleLoginError() {
    // TODO : Gérer les erreurs de connexion
  }
}
