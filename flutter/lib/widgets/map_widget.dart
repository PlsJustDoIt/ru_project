import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/models/sectorModel.dart';

class FloorPlan extends StatefulWidget {
  final double width;
  final double height;

  const FloorPlan({
    Key? key,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan> {
  SectorModel? selectedSector;

  @override
  Widget build(BuildContext context) {
    ApiService apiService = Provider.of<ApiService>(context, listen: false);

    return FutureBuilder<List<SectorModel>>(
      future: apiService.getRestaurantsSectors(), // Fetch sectors dynamically
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator()); // Show loading indicator
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}')); // Show error message
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucun secteur disponible.')); // Show empty state
        }

        final sectors = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final containerWidth = constraints.maxWidth;
            final containerHeight = constraints.maxHeight;

            return Container(
              width: containerWidth,
              height: containerHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.grey[200],
                image: const DecorationImage(
                  image: AssetImage('assets/images/map_r135.jpg'),
                  fit: BoxFit.fill,
                ),
              ),
              child: Stack(
                children: sectors.map((sector) {
                  final sectorWidth = sector.width * containerWidth / 100;
                  final sectorHeight = sector.height * containerHeight / 100;
                  final sectorLeft = sector.x * containerWidth / 100;
                  final sectorTop = sector.y * containerHeight / 100;

                  return Positioned(
                    left: sectorLeft,
                    top: sectorTop,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedSector = sector;
                        });
                        showSectorDetails(context, sector, apiService);
                      },
                      child: Container(
                        width: sectorWidth,
                        height: sectorHeight,
                        decoration: BoxDecoration(
                          color: sector.color ?? Colors.grey,
                          border: Border.all(
                            color: selectedSector?.id == sector.id
                                ? Colors.blue
                                : Colors.black,
                            width: selectedSector?.id == sector.id ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            sector.name ?? "",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  void showSectorDetails(BuildContext context, SectorModel sector, ApiService apiService) {
    // if (!sector.isClickable) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectorInfoWidget(sector: sector, apiService: apiService),
      ),
    );
  }
}

class SimpleMapWidget extends StatelessWidget {
  const SimpleMapWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: AspectRatio(
          aspectRatio: 1, // Maintain a square aspect ratio
          child: FloorPlan(
            width: screenSize.width * 0.8, // 80% of screen width
            height: screenSize.height * 0.8, // 80% of screen height
          ),
        ),
      ),
    );
  }
}

class SectorInfoWidget extends StatelessWidget {
  final SectorModel sector;
  final ApiService apiService;

  const SectorInfoWidget({Key? key, required this.sector, required this.apiService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Détails du secteur: ${sector.name ?? "N/A"}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sector Details Section
            Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations du secteur',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Nom: ${sector.name ?? "N/A"}'),
                      Text('ID: ${sector.id ?? "N/A"}'),
                      Text('Position: (${sector.x}, ${sector.y})'),
                      Text('Dimensions: ${sector.width}x${sector.height}'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  logger.d('S\'assoir dans le secteur ${sector.name}');
                  _showTimeSelector(context, apiService);
                },
                icon: const Icon(Icons.chair),
                label: const Text('S\'assoir ici?'),
              ),
            ),
            const SizedBox(height: 16),

            // Friends in Area Section
            if (sector.friendsInArea != null && sector.friendsInArea!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amis dans le secteur:',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: sector.friendsInArea!.length,
                      itemBuilder: (context, index) {
                        final friend = sector.friendsInArea![index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(apiService.getImageNetworkUrl(friend.avatarUrl)),
                            ),
                            title: Text(friend.username),
                            subtitle: Text(friend.status),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
            else
              const Center(
                child: Text(
                  'Aucun ami dans ce secteur.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTimeSelector(BuildContext context, ApiService apiService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sélectionnez la durée',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: 6, // 5, 10, 15, 20, 25, 30 minutes
                itemBuilder: (context, index) {
                  final duration = (index + 1) * 5; // Calculate duration in minutes
                  return ListTile(
                    leading: const Icon(Icons.timer),
                    title: Text('$duration minutes'),
                    onTap: () async {
                      logger.d('Durée sélectionnée: $duration minutes dans le secteur ${sector.name}');
                      // Add your logic here for the selected duration
                      bool succes = await apiService.sitInSector(duration, sector.id!);
                      // Handle the response
                      if (succes) {
                        logger.d('Vous êtes assis dans le secteur ${sector.name} pour $duration minutes.');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Vous êtes assis dans le secteur ${sector.name} pour $duration minutes.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        logger.e('Erreur lors de la réservation du secteur ${sector.name}.');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Erreur lors de la réservation du secteur.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(context); // Close the bottom sheet
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}