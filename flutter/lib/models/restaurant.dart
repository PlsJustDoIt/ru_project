
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
  final String? address;
  final String? type;
  final String? zone;

  RestaurantPartial({
    required super.restaurantId,
    required super.name,
    this.address,
    this.type,
    this.zone,
  });

  factory RestaurantPartial.fromJson(Map<String, dynamic> json) {
    return RestaurantPartial(
      restaurantId: json['restaurantId'],
      name: json['name'],
      address: json['address'],
      type: json['type'],
      zone: json['zone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      if (address != null) 'address': address,
      if (type != null) 'type': type,
      if (zone != null) 'zone': zone,
    };
  }

  @override
  String toString() {
    return 'RestaurantPartial{restaurantId: $restaurantId, name: $name, type: $type, zone: $zone}';
  }
}
