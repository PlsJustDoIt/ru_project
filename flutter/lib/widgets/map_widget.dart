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
    ApiService apiService = Provider.of<ApiService>(context, listen: false); //temp

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        color: Colors.grey[200],
      ),
      child: Stack(
        children: [
          ...widget.sectors.map((sector) => Positioned(
                left: sector.x * widget.width / 100, // Convert percentage to actual width
                top: sector.y * widget.height / 100, // Convert percentage to actual height
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSector = sector;
                    });
                    showSectorDetails(context, sector, apiService);
                  },
                  child: Container(
                    width: sector.width * widget.width / 100, // Convert percentage to actual width
                    height: sector.height * widget.height / 100, // Convert percentage to actual height
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
              )),
        ],
      ),
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
    // Wall
    SectorModel(
      x: 40,
      y: 30,
      width: 20,
      height: 50,
      color: Colors.red,
      isClickable: false,
    ),
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
        title: const Text('Détails du secteur'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sector ${sector.name ?? "N/A"}'),
            Text('id: ${sector.id ?? "N/A"}'),
            Text('Position: (${sector.x}, ${sector.y})'),
            Text('Dimensions: ${sector.width}x${sector.height}'),
            ElevatedButton(
              onPressed: () {
                logger.d('S\'assoir dans le secteur ${sector.name}');
                // Do something with api service etc
              },
              child: const Text('S\'assoir ici?'),
            ),
            const SizedBox(height: 20),
            if (sector.friendsInArea != null && sector.friendsInArea!.isNotEmpty)
              Column(
                children: [
                  const Text('Amis dans le secteur:'),
                  SizedBox(
                    height: 200,
                    width: 300,
                    child: ListView.builder(
                      itemCount: sector.friendsInArea!.length,
                      itemBuilder: (context, index) {
                        final friend = sector.friendsInArea![index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
              const Text('Aucun ami dans ce secteur.'),
          ],
        ),
      ),
    );
  }
}