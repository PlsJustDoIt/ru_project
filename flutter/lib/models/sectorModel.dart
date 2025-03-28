import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';

class SectorModel {
  final String? id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? name;
  final Color? color;
  final bool isClickable;
  List<User>? friendsInArea;

  SectorModel({
    this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.name,
    required this.color,
    required this.isClickable,
    this.friendsInArea,
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) {
    return SectorModel(
      id: json['_id'],
      x: json['x'],
      y: json['y'],
      width: json['width'],
      height: json['height'],
      name: json['name'],
      color: Color(int.parse(json['color'])),
      isClickable: json['isClickable'],
      friendsInArea: json['friendsInArea'] != null
          ? List<User>.from(json['friendsInArea'].map((friend) => User.fromJson(friend)))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'name': name,
      'color': color?.value.toString(),
      'isClickable': isClickable,
      'friendsInArea': friendsInArea?.map((friend) => friend.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SectorModel{id: $id, x: $x, y: $y, width: $width, height: $height, name: $name, color: $color, isClickable: $isClickable, friendsInArea: $friendsInArea}';
  }
}