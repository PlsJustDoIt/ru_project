import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/user_provider.dart';
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
    UserProvider userProvider = Provider.of<UserProvider>(context, listen: false);

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
                        showSectorDetails(context, sector, apiService, userProvider);
                      },
                      child: Container(
                        width: sectorWidth,
                        height: sectorHeight,
                        decoration: BoxDecoration(
                          color: sector.getColor(),
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

  // Function to refresh the map
  void refreshMap() {
    setState(() {
      selectedSector = null; // Reset selected sector
    });
  }

  void showSectorDetails(BuildContext context, SectorModel sector, ApiService apiService, UserProvider userProvider) {
    // if (!sector.isClickable) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectorInfoWidget(sector: sector, apiService: apiService, userProvider: userProvider, onMove: refreshMap),
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

class SectorInfoWidget extends StatefulWidget {
  final SectorModel sector;
  final ApiService apiService;
  final UserProvider userProvider;
  final void Function() onMove;

  const SectorInfoWidget({
    Key? key,
    required this.sector,
    required this.apiService,
    required this.userProvider,
    required this.onMove,
  }) : super(key: key);

  @override
  _SectorInfoWidgetState createState() => _SectorInfoWidgetState();
}

class _SectorInfoWidgetState extends State<SectorInfoWidget> {
  List<User> friendsInArea = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFriendsInArea();
  }

  Future<void> _fetchFriendsInArea() async {
    try {
      final friends = await widget.apiService.getFriendsInSector(widget.sector.id!);
      setState(() {
        logger.d('Amis dans le secteur ${widget.sector.name}: $friends');
        friendsInArea = friends;
        isLoading = false;
      });
    } catch (error) {
      logger.e('Error fetching friends in sector: $error');
      setState(() {
        isLoading = false;
      });
    }
  }

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
        title: Text('Détails du secteur : ${widget.sector.name ?? "N/A"}'),
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
                      Text('Nom : ${widget.sector.name ?? "N/A"}'),
                      Text('ID : ${widget.sector.id ?? "N/A"}'),
                      Text('Position : (${widget.sector.x}, ${widget.sector.y})'),
                      Text('Dimensions : ${widget.sector.width}x${widget.sector.height}'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Button (if userid not in participants then join button else leave button)
            if (widget.sector.participants!.contains(widget.userProvider.user!.id))
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    logger.d('Se lever du secteur ${widget.sector.name}');
                    bool res = await widget.apiService.leaveSector(widget.sector.id!);
                    if (res) {
                      logger.d('Vous vous êtes levé du secteur ${widget.sector.name}');
                      setState(() {
                        widget.sector.participants!.remove(widget.userProvider.user!.id);
                      });
                      widget.onMove();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vous vous êtes levé du secteur.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } else {
                      logger.e('Erreur lors de la réservation du secteur ${widget.sector.name}.');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Erreur lors de l\'opération.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chair),
                  label: const Text('Se lever ?'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Change button color to red
                    foregroundColor: Colors.white, // Change text color to white
                  ),
                ),
              )
            else
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    logger.d('S\'assoir dans le secteur ${widget.sector.name}');
                    _showTimeSelector(context, widget.apiService);
                  },
                  icon: const Icon(Icons.chair),
                  label: const Text('S\'assoir ici ?'),
                ),
              ),
            const SizedBox(height: 16),

            // Friends in Area Section
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (friendsInArea.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amis dans le secteur :',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: friendsInArea.length,
                      itemBuilder: (context, index) {
                        final friend = friendsInArea[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(
                                widget.apiService.getImageNetworkUrl(friend.avatarUrl),
                              ),
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
                      logger.d('Durée sélectionnée : $duration minutes dans le secteur ${widget.sector.name}');
                      bool success = await apiService.sitInSector(duration, widget.sector.id!);
                      if (success) {
                        logger.d('Vous êtes assis dans le secteur ${widget.sector.name} pour $duration minutes.');
                        setState(() {
                          widget.sector.participants!.add(widget.userProvider.user!.id);
                        });
                        widget.onMove();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Vous êtes assis dans le secteur ${widget.sector.name} pour $duration minutes.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        logger.e('Erreur lors de la réservation du secteur ${widget.sector.name}.');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Erreur lors de l\'opération.'),
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