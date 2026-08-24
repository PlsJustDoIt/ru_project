class Menu {
  /// Catégories libres selon le format du resto dans le flux CROUS
  /// (Entrées, Plats du jour, Sandwichs, "Soir — ...", ARSENAL...).
  /// Valeurs : liste de plats, ou texte brut ('menu non communiqué').
  Map<String, dynamic>? plats;
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

    // Sinon on garde les catégories telles que renvoyées par le backend
    return Menu(
      plats: json["plats"] != null
          ? Map<String, dynamic>.from(json["plats"] as Map)
          : null,
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
