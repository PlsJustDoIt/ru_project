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

// class Restaurant {
//   String id;
//   List<Sector>? sectors;
//   String restaurantId;
//   String name;
//   String? address;
//   String? description;

//   Restaurant({
//     required this.id,
//     this.sectors,
//     required this.restaurantId,
//     required this.name,
//     required this.address,
//     required this.description,
//   });

//   factory Restaurant.fromJson(Map<String, dynamic> json) {
//     try {
//       return Restaurant(
//         id: json['_id'],
//         sectors: json['sectors'] != null
//             ? (json['sectors'] as List).map((item) => item as Sector).toList()
//             : null,
//         restaurantId: json['restaurantId'],
//         name: json['name'],
//         address: json['address'] ?? '',
//         description: json['description'] ?? '',
//       );
//     } catch (e) {
//       logger.e('Error parsing restaurant JSON: $e');
//       return Restaurant(
//         id: '',
//         sectors: [],
//         restaurantId: '',
//         name: '',
//         address: '',
//         description: '',
//       );
//     }
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       '_id': id,
//       'sectors': sectors ?? [],
//       'id': restaurantId,
//       'name': name,
//       'address': address ?? '',
//       'description': description ?? '',
//     };
//   }
// }
