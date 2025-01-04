import 'package:flutter/material.dart';

class TableModel {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String sector;

  TableModel({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.sector,
  });
}

class FloorPlan extends StatefulWidget {
  final double width;
  final double height;
  final List<TableModel> tables;
  final Map<String, Color> sectorColors;

  const FloorPlan({
    Key? key,
    required this.width,
    required this.height,
    required this.tables,
    required this.sectorColors,
  }) : super(key: key);

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan> {
  TableModel? selectedTable;

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
          ...widget.tables.map((table) => Positioned(
                left: table.x,
                top: table.y,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTable = table;
                    });
                    showTableDetails(context, table);
                  },
                  child: Container(
                    width: table.width,
                    height: table.height,
                    decoration: BoxDecoration(
                      color: widget.sectorColors[table.sector] ?? Colors.grey,
                      border: Border.all(
                        color: selectedTable?.id == table.id
                            ? Colors.blue
                            : Colors.black,
                        width: selectedTable?.id == table.id ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        table.id,
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

  void showTableDetails(BuildContext context, TableModel table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Table ${table.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secteur: ${table.sector}'),
            Text('Position: (${table.x}, ${table.y})'),
            Text('Dimensions: ${table.width}x${table.height}'),
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
  final tables = [
    TableModel(
      id: "T1",
      x: 50,
      y: 50,
      width: 60,
      height: 40,
      sector: "A",
    ),
    TableModel(
      id: "T2",
      x: 150,
      y: 50,
      width: 60,
      height: 40,
      sector: "B",
    ),
    // Ajoutez d'autres tables selon vos besoins
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
            tables: tables,
            sectorColors: sectorColors,
          )),
    );
  }
}
