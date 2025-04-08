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
  List<String>? participants;

  SectorModel({
    this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.name,
    this.participants,
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) {
    return SectorModel(
      id: json['_id'],
      x: json['position']['x']?.toDouble() ?? 0.0,
      y: json['position']['y']?.toDouble() ?? 0.0,
      width: json['size']['width']?.toDouble() ?? 0.0,
      height: json['size']['height']?.toDouble() ?? 0.0,
      name: json['name'],
      participants: json['participants'] != null
          ? List<String>.from(json['participants'])
          : [],
    );
  }

  //if there is no one then it's a default color else it's orange
  Color getColor() {
    return participants != null && participants!.isNotEmpty
        ? Colors.orange
        : const Color(0xFF00FF00); // Default color (green)
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
      'participants': participants,
    };
  }

  @override
  String toString() {
    return 'SectorModel{id: $id, x: $x, y: $y, width: $width, height: $height, name: $name, participants: $participants}';
  }
}