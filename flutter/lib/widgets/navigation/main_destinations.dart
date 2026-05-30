import 'package:flutter/material.dart';
import 'package:ru_project/widgets/friends_widget.dart';
import 'package:ru_project/widgets/inbox_widget.dart';
import 'package:ru_project/widgets/map_widget.dart';
import 'package:ru_project/widgets/menu_widget.dart';
import 'package:ru_project/widgets/more_widget.dart';

class MainDestination {
  const MainDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final List<MainDestination> kMainDestinations = [
  MainDestination(
    label: 'Carte',
    icon: Icons.map_outlined,
    builder: (_) => const SimpleMapWidget(),
  ),
  MainDestination(
    label: 'Menu',
    icon: Icons.restaurant_menu_outlined,
    builder: (_) => const MenuWidget(),
  ),
  MainDestination(
    label: 'Messages',
    icon: Icons.chat_bubble_outline,
    builder: (_) => const InboxWidget(),
  ),
  MainDestination(
    label: 'Amis',
    icon: Icons.people_outline,
    builder: (_) => const FriendsListSheet(),
  ),
  MainDestination(
    label: 'Plus',
    icon: Icons.more_horiz,
    builder: (_) => const MoreWidget(),
  ),
];
