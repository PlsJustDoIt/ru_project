import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';

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
}

class FloorPlan extends StatefulWidget {
  final double width;
  final double height;
  final List<SectorModel> sectors;

  const FloorPlan({
    Key? key,
    required this.width,
    required this.height,
    required this.sectors,
  }) : super(key: key);

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan> {
  SectorModel? selectedSector;

  @override
  Widget build(BuildContext context) {
    ApiService apiService = Provider.of<ApiService>(context, listen: false);

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
              image: AssetImage('assets/images/map_Ru_Lumiere.jpg'), // Path to your image
              fit: BoxFit.fill,
            ),
          ),
          child: Stack(
            children: widget.sectors.map((sector) {
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
  }

  void showSectorDetailsDialog(BuildContext context, SectorModel sector) {
    if (!sector.isClickable) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sector ${sector.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('id: ${sector.id}'),
            Text('Position: (${sector.x}, ${sector.y})'),
            Text('Dimensions: ${sector.width}x${sector.height}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void showSectorDetails(BuildContext context, SectorModel sector, ApiService apiService) {
    if (!sector.isClickable) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectorInfoWidget(sector: sector, apiService: apiService),
      ),
    );
  }
}

class SimpleMapWidget extends StatelessWidget {
  SimpleMapWidget({Key? key}) : super(key: key);
  final sectors = [
    SectorModel(
      id: "S1",
      x: 10, // Percentage of the width
      y: 10, // Percentage of the height
      width: 20, // Percentage of the width
      height: 15, // Percentage of the height
      name: "A",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S2",
      x: 40,
      y: 10,
      width: 20,
      height: 15,
      name: "B",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S3",
      x: 70,
      y: 10,
      width: 20,
      height: 15,
      name: "C",
      color: Colors.green,
      isClickable: true,
    ),
    // // Wall TODO : i need to remove wall and isClickable things
    // SectorModel(
    //   x: 40,
    //   y: 30,
    //   width: 20,
    //   height: 50,
    //   color: Colors.red,
    //   isClickable: false,
    // ),
    SectorModel(
      id: "S4",
      x: 10,
      y: 30,
      width: 20,
      height: 15,
      name: "D",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S5",
      x: 70,
      y: 30,
      width: 20,
      height: 15,
      name: "E",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S6",
      x: 10,
      y: 50,
      width: 20,
      height: 15,
      name: "G",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S7",
      x: 70,
      y: 50,
      width: 20,
      height: 15,
      name: "H",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S8",
      x: 10,
      y: 70,
      width: 20,
      height: 15,
      name: "I",
      color: Colors.green,
      isClickable: true,
    ),
    SectorModel(
      id: "S9",
      x: 70,
      y: 70,
      width: 20,
      height: 15,
      name: "J",
      color: Colors.green,
      isClickable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: AspectRatio(
          aspectRatio: 1, // Maintain a square aspect ratio
          child: FloorPlan(
            width: screenSize.width * 0.8, // 80% of screen width
            height: screenSize.height * 0.8, // 80% of screen height
            sectors: sectors,
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
                  _showTimeSelector(context);
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

  void _showTimeSelector(BuildContext context) {
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
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      logger.d('Durée sélectionnée: $duration minutes dans le secteur ${sector.name}');
                      // Add your logic here for the selected duration
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