import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/friendsInSector.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/services/api_client.dart';

class SectorsSessionsWidget extends StatefulWidget {
  final String restaurantId;
  const SectorsSessionsWidget({super.key, required this.restaurantId});

  @override
  State<SectorsSessionsWidget> createState() => _SectorsSessionsWidgetState();
}

class _SectorsSessionsWidgetState extends State<SectorsSessionsWidget> {
  FriendsInSectors? sessions;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = Provider.of<RestaurantService>(context, listen: false);
      final data = await service.getAllSectorsSessions(widget.restaurantId);
      setState(() {
        sessions = data;
        isLoading = false;
      });
    } catch (e) {
      logger.e('Error loading all sectors sessions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Provider.of<ApiClient>(context, listen: false);
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sessions des secteurs')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = sessions?.data ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions des secteurs')),
      body: data.isEmpty
          ? const Center(child: Text('Aucune session.'))
          : ListView(
              children: data.entries.map((entry) {
                final sectorId = entry.key;
                final list = entry.value;
                return ExpansionTile(
                  initiallyExpanded: true,
                  title: Text('Secteur $sectorId (${list.length})'),
                  children: [
                    for (final s in list)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                              api.getImageNetworkUrl(s.friend.avatarUrl)),
                        ),
                        title: Text(s.friend.username),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            (() {
                              final now = DateTime.now();
                              final remaining = s.expiresAt.difference(now);
                              if (remaining.inSeconds <= 0) {
                                return const Text('Expiré');
                              }
                              final h = remaining.inHours;
                              final m = remaining.inMinutes.remainder(60);
                              final sec = remaining.inSeconds.remainder(60);
                              final parts = <String>[];
                              if (h != 0)
                                parts.add('$h heure${h > 1 ? 's' : ''}');
                              if (m != 0)
                                parts.add('$m minute${m > 1 ? 's' : ''}');
                              if (sec != 0)
                                parts.add('$sec seconde${sec > 1 ? 's' : ''}');
                              return Text('Restant: ${parts.join(', ')}');
                            }()),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
