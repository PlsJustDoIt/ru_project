import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/old_map_widget.dart';

class Restaurant {
  String id;
  List<Sector>? sectors;
  String restaurantId;
  String name;
  String? address;
  String? description;

  Restaurant({
    required this.id,
    this.sectors,
    required this.restaurantId,
    required this.name,
    required this.address,
    required this.description,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    try {
      return Restaurant(
        id: json['_id'],
        sectors: json['sectors'] != null
            ? (json['sectors'] as List).map((item) => item as Sector).toList()
            : null,
        restaurantId: json['restaurantId'],
        name: json['name'],
        address: json['address'] ?? '',
        description: json['description'] ?? '',
      );
    } catch (e) {
      logger.e('Error parsing restaurant JSON: $e');
      return Restaurant(
        id: '',
        sectors: [],
        restaurantId: '',
        name: '',
        address: '',
        description: '',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sectors': sectors ?? [],
      'id': restaurantId,
      'name': name,
      'address': address ?? '',
      'description': description ?? '',
    };
  }
}
