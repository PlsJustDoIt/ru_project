import 'package:ru_project/services/logger.dart';

import 'sector.dart';

abstract class RestaurantBase {
  final String restaurantId;
  final String name;

  RestaurantBase({
    required this.restaurantId,
    required this.name,
  });
}

// restaurant qui contient les secteurs
class RestaurantTmp extends RestaurantBase {
  final String address;
  final String description;
  List<Sector>? sectors;

  RestaurantTmp({
    required super.restaurantId,
    required super.name,
    required this.address,
    required this.description,
    this.sectors,
  });

  factory RestaurantTmp.fromJson(Map<String, dynamic> json) {
    return RestaurantTmp(
      restaurantId: json['restaurantId'],
      name: json['name'],
      address: json['address'],
      description: json['description'],
      sectors: (json['sectors'] as List?)
              ?.map((item) => Sector.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'address': address,
      'description': description,
      'sectors': sectors?.map((item) => item.toJson()).toList() ?? [],
    };
  }

  @override
  String toString() {
    return 'RestaurantTmp{restaurantId: $restaurantId, name: $name, address: $address, description: $description, sectors: $sectors}';
  }
}

// uniquement pour récuperer la liste des restaurants dispos
class RestaurantPartial extends RestaurantBase {
  RestaurantPartial({
    required super.restaurantId,
    required super.name,
  });

  factory RestaurantPartial.fromJson(Map<String, dynamic> json) {
    return RestaurantPartial(
      restaurantId: json['restaurantId'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'RestaurantPartial{restaurantId: $restaurantId, name: $name}';
  }
}
