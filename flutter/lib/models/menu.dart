import 'package:logger/logger.dart';
import 'package:ru_project/services/logger.dart';

class Menu {
  Map<String, dynamic> plats;
  String date;
  dynamic fermeture; //string or bool

  Menu({
    required this.plats,
    required this.date,
    required this.fermeture,
  });

  // Factory constructor for creating a Menu instance from JSON
  factory Menu.fromJson(Map<String, dynamic> json) {
    //logger.i('menu from json : $json');
    return Menu(
      plats: {
        "Entrées": json["Entrées"] ?? "menu non communiqué",
        "Cuisine traditionnelle":
            json["Cuisine traditionnelle"] ?? "menu non communiqué",
        "Menu végétalien": json["Menu végétalien"] ?? "menu non communiqué",
        "Pizza": json["Pizza"] ?? "menu non communiqué",
        "Cuisine italienne": json["Cuisine italienne"] ?? "menu non communiqué",
        "Grill": json["Grill"] ?? "menu non communiqué",
      },
      date: json["date"],
      fermeture: json["Fermeture"],
    );
  }

  // Method to convert a Menu instance to JSON
  Map<String, dynamic> toJson() {
    return {
      "plats": plats,
      "date": date,
      "fermeture": fermeture,
    };
  }

  @override
  String toString() {
    return 'Menu{plats: $plats, date: $date}';
  }
}
