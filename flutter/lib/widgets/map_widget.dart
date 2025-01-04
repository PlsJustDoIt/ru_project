import 'package:flutter/material.dart';

class RoomLayout extends StatefulWidget {
  const RoomLayout({Key? key}) : super(key: key);

  @override
  State<RoomLayout> createState() => _RoomLayoutState();
}

class _RoomLayoutState extends State<RoomLayout>
    with SingleTickerProviderStateMixin {
  Sector? selectedSector;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final roomSize = Size(screenSize.width * 0.9, screenSize.height * 0.9);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            child: Stack(
              children: [
                // Vue principale
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RoomPainter(
                        sectors: getSectorData(),
                        selectedSector: selectedSector,
                        animationValue: _animation.value,
                      ),
                      size: roomSize,
                    );
                  },
                ),

                // Gestion des clics
                if (selectedSector == null)
                  ...getSectorData().map(
                    (sector) => Positioned(
                      left: sector.dx * roomSize.width,
                      top: sector.dy * roomSize.height,
                      width: sector.width * roomSize.width,
                      height: sector.height * roomSize.height,
                      child: GestureDetector(
                        onTap: () => _selectSector(sector),
                        child: Container(
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                  ),

                // Tables du secteur sélectionné
                if (selectedSector != null)
                  ...selectedSector!.tables.map(
                    (table) => AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final relativeX = (table.dx - selectedSector!.dx) /
                            selectedSector!.width;
                        final relativeY = (table.dy - selectedSector!.dy) /
                            selectedSector!.height;

                        return Positioned(
                          left: (selectedSector!.dx +
                                  relativeX * selectedSector!.width) *
                              roomSize.width,
                          top: (selectedSector!.dy +
                                  relativeY * selectedSector!.height) *
                              roomSize.height,
                          width:
                              table.width * roomSize.width * _animation.value,
                          height:
                              table.height * roomSize.height * _animation.value,
                          child: GestureDetector(
                            onTap: () => _showTableDetails(table),
                            child: Opacity(
                              opacity: _animation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.brown,
                                  border: Border.all(color: Colors.black),
                                ),
                                child: Center(
                                  child: Text(
                                    table.name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      // Bouton retour quand un secteur est sélectionné
      floatingActionButton: selectedSector != null
          ? FloatingActionButton(
              onPressed: _unselectSector,
              child: const Icon(Icons.arrow_back),
            )
          : null,
    );
  }

  void _selectSector(Sector sector) {
    setState(() {
      selectedSector = sector;
    });
    _controller.forward(from: 0);
  }

  void _unselectSector() {
    _controller.reverse().then((_) {
      setState(() {
        selectedSector = null;
      });
    });
  }

  void _showTableDetails(Table table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(table.name),
        content: const Text('Détails de la table'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class RoomPainter extends CustomPainter {
  final List<Sector> sectors;
  final Sector? selectedSector;
  final double animationValue;

  RoomPainter({
    required this.sectors,
    this.selectedSector,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dessiner les murs
    final wallPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, wallPaint);

    // Dessiner les secteurs
    for (final sector in sectors) {
      final isSelected = sector == selectedSector;
      final sectorPaint = Paint()
        ..color = isSelected
            ? sector.color.withOpacity(0.1 + (0.2 * animationValue))
            : sector.color.withOpacity(selectedSector != null ? 0.1 : 0.3)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        sector.dx * size.width,
        sector.dy * size.height,
        sector.width * size.width,
        sector.height * size.height,
      );

      canvas.drawRect(rect, sectorPaint);

      // Afficher le nom du secteur seulement si aucun secteur n'est sélectionné
      // ou si c'est le secteur sélectionné
      if (selectedSector == null || isSelected) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: sector.name,
            style: TextStyle(
              color: Colors.black,
              fontSize: isSelected ? 20 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        final textOffset = Offset(
          rect.left + (rect.width - textPainter.width) / 2,
          rect.top + (rect.height - textPainter.height) / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(RoomPainter oldDelegate) {
    return oldDelegate.selectedSector != selectedSector ||
        oldDelegate.animationValue != animationValue;
  }
}

// Les classes Sector et Table restent les mêmes
class Sector {
  final String name;
  final double dx;
  final double dy;
  final double width;
  final double height;
  final Color color;
  final List<Table> tables;

  Sector({
    required this.name,
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    required this.color,
    required this.tables,
  });
}

class Table {
  final double dx;
  final double dy;
  final double width;
  final double height;
  final String name;

  Table({
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    required this.name,
  });
}

// Données de test
List<Sector> getSectorData() {
  return [
    Sector(
      name: 'Secteur A',
      dx: 0.1,
      dy: 0.1,
      width: 0.4,
      height: 0.3,
      color: Colors.blue,
      tables: [
        Table(
          dx: 0.15,
          dy: 0.15,
          width: 0.08,
          height: 0.12,
          name: 'A1',
        ),
        Table(
          dx: 0.35,
          dy: 0.15,
          width: 0.08,
          height: 0.12,
          name: 'A2',
        ),
      ],
    ),
    Sector(
      name: 'Secteur B',
      dx: 0.1,
      dy: 0.5,
      width: 0.4,
      height: 0.3,
      color: Colors.green,
      tables: [
        Table(
          dx: 0.15,
          dy: 0.55,
          width: 0.08,
          height: 0.12,
          name: 'B1',
        ),
        Table(
          dx: 0.35,
          dy: 0.55,
          width: 0.08,
          height: 0.12,
          name: 'B2',
        ),
      ],
    ),
  ];
}
