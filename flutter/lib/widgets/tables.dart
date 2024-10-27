import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class CafeteriaTable {
  final int id;
  final double xPercent; // Position as percentage of container width
  final double yPercent; // Position as percentage of container height
  bool isOccupied;

  CafeteriaTable({
    required this.id,
    required this.xPercent,
    required this.yPercent,
    this.isOccupied = false,
  });
}

class CafeteriaLayout extends StatefulWidget {
  const CafeteriaLayout({super.key});

  @override
  State<CafeteriaLayout> createState() => _CafeteriaLayoutState();
}

class _CafeteriaLayoutState extends State<CafeteriaLayout> {
  // Define tables with positions as percentages
  final List<CafeteriaTable> tables = [
    CafeteriaTable(id: 1, xPercent: 0.2, yPercent: 0.15),
    CafeteriaTable(id: 2, xPercent: 0.5, yPercent: 0.2),
    CafeteriaTable(id: 3, xPercent: 0.8, yPercent: 0.15),
    CafeteriaTable(id: 4, xPercent: 0.15, yPercent: 0.45),
    CafeteriaTable(id: 5, xPercent: 0.4, yPercent: 0.5),
    CafeteriaTable(id: 6, xPercent: 0.7, yPercent: 0.45),
    CafeteriaTable(id: 7, xPercent: 0.25, yPercent: 0.8),
    CafeteriaTable(id: 8, xPercent: 0.6, yPercent: 0.75),
    CafeteriaTable(id: 9, xPercent: 0.80, yPercent: 0.8),
  ];

  void _handleTableTap(CafeteriaTable table) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Table ${table.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status: ${table.isOccupied ? 'Occupied' : 'Available'}'),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        table.isOccupied = true;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Mark Occupied'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        table.isOccupied = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Mark Available'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        height: double.infinity,
        // padding: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.grey[200],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var tableSize = constraints.maxWidth * 0.03; // Table size as % of width
            if (tableSize <=30) {
              tableSize = 30;
            }
            Logger().i('Table size: $tableSize');

            return Stack(
              children: [
                // Room border
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.yellow,
                  ),
                ),
                
                // Tables
                ...tables.map((table) {
                  // Calculate actual positions based on container size
                  final xPos = constraints.maxWidth * table.xPercent - (tableSize / 2);
                  final yPos = constraints.maxHeight * table.yPercent - (tableSize / 2);

                  return Positioned(
                    left: xPos,
                    top: yPos,
                    child: GestureDetector(
                      onTap: () => _handleTableTap(table),
                      child: Container(
                        width: tableSize*2.3,
                        height: tableSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          color: table.isOccupied ? Colors.red : Colors.green,
                          border: Border.all(color: Colors.black),
                        ),
                        child: Center(
                          child: Text(
                            '${table.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Entrance
                Positioned(
                  bottom: 30,
                  left: constraints.maxWidth * 0.5 - 75, // Center entrance
                  child: Container(
                    width: 150,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Text(
                        'Entrée',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
  }
}


// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:logger/logger.dart';

// // Model for a table
// class CafeteriaTable {
//   final int id;
//   final double x;
//   final double y;
//   bool isOccupied;

//   CafeteriaTable({
//     required this.id,
//     required this.x,
//     required this.y,
//     this.isOccupied = false,
//   });
// }

// class CafeteriaLayout extends StatefulWidget {
//   const CafeteriaLayout({Key? key}) : super(key: key);

//   @override
//   State<CafeteriaLayout> createState() => _CafeteriaLayoutState();
// }

// class _CafeteriaLayoutState extends State<CafeteriaLayout> {
//   // List of tables in the cafeteria
//   final List<CafeteriaTable> tables = [
//     CafeteriaTable(id: 1, x: 50, y: 50),
//     CafeteriaTable(id: 2, x: 150, y: 50),
//     CafeteriaTable(id: 3, x: 250, y: 50),
//     CafeteriaTable(id: 5, x: 150, y: 150),
//     CafeteriaTable(id: 6, x: 250, y: 150),
//     CafeteriaTable(id: 7, x: 50, y: 250),
//     CafeteriaTable(id: 8, x: 150, y: 250),
//     CafeteriaTable(id: 9, x: 250, y: 250),
//   ];

//   void _handleTableTap(CafeteriaTable table) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Table ${table.id}'),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Status: ${table.isOccupied ? 'Occupied' : 'Available'}'),
//               const SizedBox(height: 20),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         table.isOccupied = true;
//                       });
//                       Navigator.pop(context);
//                     },
//                     child: const Text('Mark Occupied'),
//                   ),
//                   ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         table.isOccupied = false;
//                       });
//                       Navigator.pop(context);
//                     },
//                     child: const Text('Mark Available'),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildTable(CafeteriaTable table) {
//     return GestureDetector(
//       onTap: () => _handleTableTap(table),
//       child: Container(
//         margin: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           shape: BoxShape.rectangle,
//           color: table.isOccupied ? Colors.red : Colors.green,
//           border: Border.all(color: Colors.black),
//         ),
//         child: Center(
//           child: Text(
//             '${table.id}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Cafeteria Layout'),
//       ),
//       body: Container(
//         width: double.infinity,  // Take full width
//         height: double.infinity, // Take full height
//         decoration: BoxDecoration(
//           color: Colors.grey[200],
//         ),
//         child: Column(
//           children: [
//             // Tables area - takes all available space except for entrance
//             Expanded(
//               child: Container(
//                 margin: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: GridView.builder(
//                   padding: const EdgeInsets.all(20),
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 3,
//                     childAspectRatio: 1, // Square tables
//                     mainAxisSpacing: 20,  // Vertical spacing
//                     crossAxisSpacing: 20,  // Horizontal spacing
//                   ),
//                   itemCount: tables.length,
//                   itemBuilder: (context, index) {
//                     return _buildTable(tables[index]);
//                   },
//                 ),
//               ),
//             ),
//             // Entrance area at bottom
//             Container(
//               width: 150,
//               height: 40,
//               margin: const EdgeInsets.only(bottom: 20),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.black),
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(5),
//               ),
//               child: const Center(
//                 child: Text(
//                   'Entrance',
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // @override
//   // Widget build(BuildContext context) {
//   //   return Scaffold(
//   //     appBar: AppBar(
//   //       title: const Text('Cafeteria Layout'),
//   //     ),
//   //     body: Center(
//   //       child: LayoutBuilder(
//   //         builder: (context, constraints) {
//   //           double containerSize = constraints.maxWidth > 400 ? 400 : constraints.maxWidth * 0.9;
//   //           Logger().i('Container size: $containerSize');
//   //           return Container(
//   //             height: containerSize,
//   //             width: containerSize,
//   //             padding: const EdgeInsets.all(20),
//   //             decoration: BoxDecoration(
//   //               border: Border.all(color: Colors.grey),
//   //               color: Colors.yellow,
//   //             ),
//   //             child: Column(
//   //               mainAxisAlignment: MainAxisAlignment.center,
//   //               children: [
//   //                 // Tables area
//   //                 Expanded(
//   //                   child: GridView.builder(
//   //                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//   //                       crossAxisCount: 3,
//   //                       childAspectRatio: 1,
//   //                     ),
//   //                     itemCount: tables.length,
//   //                     itemBuilder: (context, index) {
//   //                       return _buildTable(tables[index]);
//   //                     },
//   //                   ),
//   //                 ),
//   //                 // Entrance area
//   //                 Container(
//   //                   width: 100,
//   //                   height: 30,
//   //                   margin: const EdgeInsets.only(top: 10),
//   //                   decoration: BoxDecoration(
//   //                     border: Border.all(color: Colors.black),
//   //                     color: Colors.white,
//   //                     borderRadius: BorderRadius.circular(5),
//   //                   ),
//   //                   child: const Center(
//   //                     child: Text('Entrance'),
//   //                   ),
//   //                 ),
//   //               ],
//   //             ),
//   //           );

//   //         }),
//   //     )
      
      
//   //     //  Container(
//   //     //   decoration: BoxDecoration(
//   //     //     border: Border.all(color: Colors.grey),
//   //     //     color: Colors.yellow,
//   //     //   ),
//   //     //   child: Stack(
//   //     //     children: [
//   //     //       // Draw entrance
//   //     //       Positioned(
//   //     //         bottom: 10,
//   //     //         left: 150,
//   //     //         child: Container(
//   //     //           width: 100,
//   //     //           height: 60,
//   //     //           decoration: BoxDecoration(
//   //     //             border: Border.all(color: Colors.black),
//   //     //             color: const Color.fromARGB(255, 155, 22, 22),
//   //     //           ),
//   //     //           child: const Center(
//   //     //             child: Text('Entrance', style: TextStyle(fontSize: 10)),
//   //     //           ),
//   //     //         ),
//   //     //       ),
//   //     //       // Draw tables
//   //     //       ...tables.map((table) => Positioned(
//   //     //             left: table.x,
//   //     //             top: table.y,
//   //     //             child: GestureDetector(
//   //     //               onTap: () => _handleTableTap(table),
//   //     //               child: Container(
//   //     //                 width: 100,
//   //     //                 height: 50,
//   //     //                 decoration: BoxDecoration(
//   //     //                   shape: BoxShape.rectangle,
//   //     //                   color: table.isOccupied ? Colors.red : Colors.green,
//   //     //                   border: Border.all(color: Colors.black),
//   //     //                 ),
//   //     //                 child: Center(
//   //     //                   child: Text(
//   //     //                     '${table.id}',
//   //     //                     style: const TextStyle(
//   //     //                       color: Colors.white,
//   //     //                       fontWeight: FontWeight.bold,
//   //     //                     ),
//   //     //                   ),
//   //     //                 ),
//   //     //               ),
//   //     //             ),
//   //     //           )),
//   //     //     ],
//   //     //   ),
//   //     // ),
//   //   );
//   // }
// }