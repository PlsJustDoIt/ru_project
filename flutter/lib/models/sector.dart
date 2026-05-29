import 'package:flutter/material.dart';
import 'package:ru_project/services/logger.dart';

//TODO save colors in hex format
//change fromJson and toJson to use hex format and to match what the backend sends
/* example of json :
  {position: {x: 10, y: 10}, size: {width: 20, height: 15}, _id: 67e7c2637eaaabbac66a0f0f, sectorId: 1}
 */
class Sector {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String sectorId;
  bool? occupied;
  bool occupiedByMe;

  Sector({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sectorId,
    this.occupied,
    this.occupiedByMe = false,
  });

  factory Sector.fromJson(Map<String, dynamic> json) {
    try {
      return Sector(
        id: json['id'],
        sectorId: json['sectorId'].toString(),
        x: json['position']['x']?.toDouble() ?? 0.0,
        y: json['position']['y']?.toDouble() ?? 0.0,
        width: json['size']['width']?.toDouble() ?? 0.0,
        height: json['size']['height']?.toDouble() ?? 0.0,
        occupiedByMe: false,
      );
    } catch (e) {
      logger.i('Error parsing sector: $e');
      // Handle parsing error
      return Sector(
        id: '',
        sectorId: '',
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
      );
    }
  }

  // Default green; orange if occupied by me
  Color getColor() {
    if (occupiedByMe == true) return Colors.orange;
    return const Color(0xFF00FF00);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'position': {
        'x': x,
        'y': y,
      },
      'size': {
        'width': width,
        'height': height,
      },
      'sectorId': sectorId,
    };
  }

  @override
  String toString() {
    return 'SectorModel{id: $id, x: $x, y: $y, width: $width, height: $height, sectorId: $sectorId ${occupied != null ? ', occupied: ${occupied.toString()}' : ''}}';
  }
}
