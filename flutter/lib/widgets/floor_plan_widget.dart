import 'package:flutter/material.dart';

class SectorModel {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String name;

  SectorModel({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.name,
  });
}

class FloorPlan extends StatefulWidget {
  final double width;
  final double height;
  final List<SectorModel> sectors;
  final Map<String, Color> sectorColors;

  const FloorPlan({
    Key? key,
    required this.width,
    required this.height,
    required this.sectors,
    required this.sectorColors,
  }) : super(key: key);

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan> {
  SectorModel? selectedSector;

  @override
  Widget build(BuildContext context) {
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
                left: sector.x,
                top: sector.y,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSector = sector;
                    });
                    showSectorDetails(context, sector);
                  },
                  child: Container(
                    width: sector.width,
                    height: sector.height,
                    decoration: BoxDecoration(
                      color: widget.sectorColors[sector.name] ?? Colors.grey,
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
                        sector.id,
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

  void showSectorDetails(BuildContext context, SectorModel sector) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sector ${sector.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secteur: ${sector.name}'),
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
}

class SimpleStatelessWidget extends StatelessWidget {
  SimpleStatelessWidget({Key? key}) : super(key: key);
  final sectors = [
    SectorModel(
      id: "S1",
      x: 50,
      y: 50,
      width: 60,
      height: 40,
      name: "A",
    ),
    SectorModel(
      id: "S2",
      x: 150,
      y: 50,
      width: 60,
      height: 40,
      name: "B",
    ),
    // Ajoutez d'autres secteurs selon vos besoins
  ];

  final sectorColors = {
    "A": Colors.blue,
    "B": Colors.green,
    // Définissez les couleurs pour chaque secteur
  };

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Center(
      child: Padding(
          padding: EdgeInsets.all(20.0),
          child: FloorPlan(
            width: screenSize.width,
            height: screenSize.height,
            sectors: sectors,
            sectorColors: sectorColors,
          )),
    );
  }
}