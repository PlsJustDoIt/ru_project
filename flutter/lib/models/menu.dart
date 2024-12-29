class Menu {
  Map<String, dynamic>? plats; // Optional car peut être null si fermé
  String date;
  String? fermeture; // String pour le message de fermeture

  Menu({
    this.plats,
    required this.date,
    this.fermeture,
  });

  // Factory constructor for creating a Menu instance from JSON
  factory Menu.fromJson(Map<String, dynamic> json) {
    // Si on a une fermeture, on crée un menu avec uniquement date et fermeture
    if (json.containsKey('fermeture')) {
      return Menu(
        date: json['date'],
        fermeture: json['fermeture'],
      );
    }

    // Sinon on crée un menu normal avec les plats
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
    );
  }

  // Method to convert a Menu instance to JSON
  Map<String, dynamic> toJson() {
    if (fermeture != null) {
      return {
        "date": date,
        "fermeture": fermeture,
      };
    }
    return {
      "plats": plats,
      "date": date,
    };
  }

  @override
  String toString() {
    if (fermeture != null) {
      return 'Menu{date: $date, fermeture: $fermeture}';
    }
    return 'Menu{plats: $plats, date: $date}';
  }

  // Helper method to check if the menu indicates a closure
  bool isClosed() {
    return fermeture != null;
  }
}
