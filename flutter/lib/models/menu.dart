class Menu {
  List<String>? entrees;
  List<String>? cuisineTraditionnelle;
  List<String>? menuVegetalien;
  List<String>? pizza;
  List<String>? cuisineItalienne;
  List<String>? grill;
  int numberOfMenus = 6;
  List<String> menuNames = ["Entrées", "Cuisine traditionnelle", "Menu végétalien", "Pizza", "Cuisine italienne", "Grill"];
  List<String> menuKeys = ["entrees", "cuisineTraditionnelle", "menuVegetalien", "pizza", "cuisineItalienne", "grill"];
  String date;

  Menu({
    required this.entrees,
    required this.cuisineTraditionnelle,
    required this.menuVegetalien,
    required this.pizza,
    required this.cuisineItalienne,
    required this.grill,
    required this.date,
  });

  List<String>? getListFromKey(String key) {
    switch (key) {
      case "entrees":
        return entrees;
      case "cuisineTraditionnelle":
        return cuisineTraditionnelle;
      case "menuVegetalien":
        return menuVegetalien;
      case "pizza":
        return pizza;
      case "cuisineItalienne":
        return cuisineItalienne;
      case "grill":
        return grill;
      default:
        return null;
    }
  }

  // Factory constructor for creating a Menu instance from JSON
  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      entrees: json["Entrées"] != "menu non communiqué" ? List<String>.from(json["Entrées"]) : null,
      cuisineTraditionnelle: json["Cuisine traditionnelle"] != "menu non communiqué" ? List<String>.from(json["Cuisine traditionnelle"]) : null,
      menuVegetalien: json["Menu végétalien"] != "menu non communiqué" ? List<String>.from(json["Menu végétalien"]) : null,
      pizza: json["Pizza"] != "menu non communiqué" ? List<String>.from(json["Pizza"]) : null,
      cuisineItalienne: json["Cuisine italienne"] != "menu non communiqué" ? List<String>.from(json["Cuisine italienne"]) : null,
      grill: json["Grill"] != "menu non communiqué" ? List<String>.from(json["Grill"]) : null,
      date: json["date"],
    );
  }

  // Method to convert a Menu instance to JSON
  Map<String, dynamic> toJson() {
    return {
      "Entrées": entrees ?? "menu non communiqué",
      "Cuisine traditionnelle": cuisineTraditionnelle ?? "menu non communiqué",
      "Menu végétalien": menuVegetalien ?? "menu non communiqué",
      "Pizza": pizza ?? "menu non communiqué",
      "Cuisine italienne": cuisineItalienne ?? "menu non communiqué",
      "Grill": grill ?? "menu non communiqué",
      "date": date,
    };
  }
}
