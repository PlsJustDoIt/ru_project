import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/friend_in_sector.dart';
import 'package:ru_project/models/restaurant.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/restaurant_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/models/sector.dart';
import 'package:ru_project/services/restaurant_service.dart';
import 'package:ru_project/widgets/sectors_sessions_widget.dart';

class FloorPlan extends StatefulWidget {
  final double width;
  final double height;

  const FloorPlan({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  State<FloorPlan> createState() => _FloorPlanState();
}

class _FloorPlanState extends State<FloorPlan> {
  Sector? selectedSector;
  late final UserProvider userProvider;
  late final RestaurantTmp restaurant;
  late FriendsInSectors? sectorSessions;
  late Future<void> getRestaurantData;
  late final RestaurantService restaurantService;
  late final RestaurantProvider restaurantProvider;

  @override
  initState() {
    logger.d('FloorPlan initState');
    super.initState();
    restaurantService = Provider.of<RestaurantService>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    restaurantProvider =
        Provider.of<RestaurantProvider>(context, listen: false);

    restaurant = restaurantProvider.restaurant!; // ca bouge pas
    logger.d('Restaurant: $restaurant');

    getRestaurantData = machin();
  }

  // truc() async {
  //   await setRestaurantSectors();
  // }

  Future<void> machin() async {
    return await setSectorSessions();
  }

  @override
  dispose() {
    logger.d('FloorPlan dispose');
    super.dispose();
  }

  Future<void> setSectorSessions() async {
    sectorSessions =
        await restaurantService.getFriendsSessions(restaurant.restaurantId);
  }

  // Future<void> setRestaurantSectors() async {
  //   restaurant.sectors = await restaurantService.getRestaurantsSectors();
  // }

  @override
  Widget build(BuildContext context) {
    logger.d('FloorPlan build');

    return FutureBuilder(
      future: getRestaurantData, // Fetch sectors dynamically
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator()); // Show loading indicator
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Erreur: ${snapshot.error}')); // Show error message
        } else if (restaurant.sectors == null || restaurant.sectors!.isEmpty) {
          return const Center(child: Text('Aucun secteur disponible.'));
        }

        logger.d('Sectors Sessions: ${sectorSessions?.data}');

        return LayoutBuilder(
          builder: (context, constraints) {
            final containerWidth = constraints.maxWidth;
            final containerHeight = constraints.maxHeight;

            return Stack(
              children: [
                Container(
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
                ),
                ...restaurant.sectors!.map((sector) {
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
                        showSectorDetails(
                          context,
                          sector,
                          restaurantService,
                          userProvider,
                          (sectorSessions?.data ?? const {})[sector.sectorId],
                        );
                      },
                      child: Container(
                        width: sectorWidth,
                        height: sectorHeight,
                        decoration: BoxDecoration(
                          color: sector.occupiedByMe
                              ? Colors.orange
                              : ((sectorSessions?.data ??
                                          const {})[sector.sectorId] !=
                                      null
                                  ? Colors.red
                                  : sector.getColor()),
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
                            sector.sectorId,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SectorsSessionsWidget(
                            restaurantId: restaurant.restaurantId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.groups),
                    label: const Text('Sessions'),
                  ),
                ),
              ],
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

  void showSectorDetails(
      BuildContext context,
      Sector sector,
      RestaurantService restaurantService,
      UserProvider userProvider,
      List<FriendInSector>? sessionsForSector) {
    // if (!sector.isClickable) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SectorInfoWidget(
            sector: sector,
            restaurantService: restaurantService,
            userProvider: userProvider,
            sessionsForSector: sessionsForSector,
            onMove: refreshMap),
      ),
    );
  }

  // Removed wantKeepAlive override; add AutomaticKeepAliveClientMixin if persistence is needed
}

class SimpleMapWidget extends StatelessWidget {
  const SimpleMapWidget({super.key});

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
  final Sector sector;
  final RestaurantService restaurantService;
  final UserProvider userProvider;
  final void Function() onMove;
  final List<FriendInSector>? sessionsForSector;

  const SectorInfoWidget({
    super.key,
    required this.sector,
    required this.restaurantService,
    required this.userProvider,
    this.sessionsForSector,
    required this.onMove,
  });

  @override
  State<SectorInfoWidget> createState() => _SectorInfoWidgetState();
}

class _SectorInfoWidgetState extends State<SectorInfoWidget> {
  List<Friend> friendsInArea = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.sessionsForSector != null) {
      // Preload from provided sessions
      friendsInArea = widget.sessionsForSector!
          .map((s) => s.friend)
          .toList(growable: false);
      isLoading = false;
      setState(() {});
    } else {
      // If not provided, you can re-enable fetching here if desired
      // _fetchFriendsInArea();
      isLoading = false;
    }
  }

  // Future<void> _fetchFriendsInArea() async {
  //   try {
  //     logger.i(widget.sector);
  //     final friends =
  //         await widget.restaurantService.getFriendsInSector(widget.sector.id!);

  //     final users = await widget.restaurantService.getUsersInSector('r135');
  //     setState(() {
  //       logger.d('Amis dans le secteur ${widget.sector.sectorId}: $friends');
  //       friendsInArea = friends;
  //       isLoading = false;
  //     });
  //   } catch (error) {
  //     logger.e('Error fetching friends in sector: $error');
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = Provider.of<ApiClient>(context, listen: false);
    final RestaurantProvider restaurantProvider =
        Provider.of<RestaurantProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Détails du secteur : ${widget.sector.sectorId}'),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                      if (widget.sector.occupiedByMe)
                        Row(
                          children: const [
                            Icon(Icons.chair, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Vous êtes assis dans ce secteur',
                                style: TextStyle(color: Colors.orange)),
                          ],
                        ),
                      if (widget.sector.occupiedByMe) const SizedBox(height: 8),
                      Text('Nom : ${widget.sector.sectorId}'),
                      Text('ID : ${widget.sector.id}'),
                      Text(
                          'Position : (${widget.sector.x}, ${widget.sector.y})'),
                      Text(
                          'Dimensions : ${widget.sector.width}x${widget.sector.height}'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bouton d'action: se lever si je suis assis, sinon s'asseoir
            if (widget.sector.occupiedByMe)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    logger.d('Se lever du secteur ${widget.sector.sectorId}');
                    bool res = await widget.restaurantService
                        .leaveSector(widget.sector.id);
                    if (res) {
                      logger.d(
                          'Vous vous êtes levé du secteur ${widget.sector.sectorId}');
                      // Met à jour l'état local et provider
                      restaurantProvider.setSectorOccupiedByMe(
                          widget.sector, false);
                      widget.onMove();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vous vous êtes levé du secteur.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      // Retour à la carte
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } else {
                      logger.e(
                          'Erreur lors de la réservation du secteur ${widget.sector.sectorId}.');
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
                    logger.d(
                        'S\'assoir dans le secteur ${widget.sector.sectorId}');
                    _showTimeSelector(
                        context, widget.restaurantService, restaurantProvider);
                  },
                  icon: const Icon(Icons.chair),
                  label: const Text('S\'assoir ici ?'),
                ),
              ),
            const SizedBox(height: 16),

            // Friends in Area Section
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (widget.sessionsForSector != null &&
                widget.sessionsForSector!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amis dans le secteur :',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: ListView.builder(
                      itemCount: widget.sessionsForSector!.length,
                      itemBuilder: (context, index) {
                        final s = widget.sessionsForSector![index];
                        final friend = s.friend;
                        final now = DateTime.now();
                        final remaining = s.expiresAt.difference(now);
                        final isExpired = remaining.inSeconds <= 0;
                        String remainingLabel;
                        if (isExpired) {
                          remainingLabel = 'Expiré';
                        } else {
                          final h = remaining.inHours;
                          final m = remaining.inMinutes.remainder(60);
                          final sec = remaining.inSeconds.remainder(60);
                          final parts = <String>[];
                          if (h != 0) parts.add('$h heure${h > 1 ? 's' : ''}');
                          if (m != 0) parts.add('$m minute${m > 1 ? 's' : ''}');
                          if (sec != 0) {
                            parts.add('$sec seconde${sec > 1 ? 's' : ''}');
                          }
                          remainingLabel = 'Restant: ${parts.join(', ')}';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(
                                apiClient.getImageNetworkUrl(friend.avatarUrl),
                              ),
                            ),
                            title: Text(friend.username),
                            subtitle: Text(remainingLabel),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              )
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(
                                apiClient.getImageNetworkUrl(friend.avatarUrl),
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

  void _showTimeSelector(
      BuildContext pageContext,
      RestaurantService restaurantService,
      RestaurantProvider restaurantProvider) {
    showModalBottomSheet(
      context: pageContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
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
                  final duration =
                      (index + 1) * 1; // Calculate duration in minutes
                  return ListTile(
                    leading: const Icon(Icons.timer),
                    title: Text('$duration minutes'),
                    onTap: () async {
                      logger.d(
                          'Durée sélectionnée : $duration minutes dans le secteur ${widget.sector.sectorId}');
                      bool success = await restaurantService.sitInSector(
                          duration, widget.sector.id);
                      if (success) {
                        logger.d(
                            'Vous êtes assis dans le secteur ${widget.sector.sectorId} pour $duration minutes.');
                        // Marque immédiate comme occupé par moi (orange)
                        restaurantProvider.setSectorOccupiedByMe(
                          widget.sector,
                          true,
                          duration: Duration(minutes: duration),
                        );
                        // to do
                        widget.onMove();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Vous êtes assis dans le secteur ${widget.sector.sectorId} pour $duration minutes.'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                        // Ferme la bottom sheet puis la page, retour à la map
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                        }
                        // Donne un micro-tour de boucle avant de pop la page
                        await Future.delayed(const Duration(milliseconds: 50));
                        if (pageContext.mounted) {
                          Navigator.pop(pageContext);
                        }
                      } else {
                        logger.e(
                            'Erreur lors de la réservation du secteur ${widget.sector.sectorId}.');
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
