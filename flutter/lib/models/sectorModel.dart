import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';

//TODO save colors in hex format
//change fromJson and toJson to use hex format and to match what the backend sends
/* example of json :
  {position: {x: 10, y: 10}, size: {width: 20, height: 15}, _id: 67e7c2637eaaabbac66a0f0f, name: A, participants: [], color: #00FF00}
 */
class SectorModel {
  final String? id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? name;
  final Color? color;
  List<User>? friendsInArea;

  SectorModel({
    this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.name,
    this.color,
    this.friendsInArea,
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) {
    return SectorModel(
      id: json['_id'],
      x: json['position']['x']?.toDouble() ?? 0.0,
      y: json['position']['y']?.toDouble() ?? 0.0,
      width: json['size']['width']?.toDouble() ?? 0.0,
      height: json['size']['height']?.toDouble() ?? 0.0,
      name: json['name'],
      color: json['color'] != null
          ? _colorFromHex(json['color']) // Convert hex string to Color
          : null,
      friendsInArea: json['friendsInArea'] != null
          ? List<User>.from(json['friendsInArea'].map((friend) => User.fromJson(friend)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'position': {
        'x': x,
        'y': y,
      },
      'size': {
        'width': width,
        'height': height,
      },
      'name': name,
      'color': color != null ? _colorToHex(color!) : null, // Convert Color to hex string
      'friendsInArea': friendsInArea?.map((friend) => friend.toJson()).toList(),
    };
  }

  /// Convert a hex string (e.g., "#00FF00") to a Flutter [Color]
  static Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.startsWith('#')) buffer.write('ff'); // Add alpha channel if missing
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convert a Flutter [Color] to a hex string (e.g., "#00FF00")
  static String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  @override
  String toString() {
    return 'SectorModel{id: $id, x: $x, y: $y, width: $width, height: $height, name: $name, color: $color, friendsInArea: $friendsInArea}';
  }
}