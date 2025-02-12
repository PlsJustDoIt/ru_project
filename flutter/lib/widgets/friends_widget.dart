import 'package:flutter/material.dart';
import 'package:ru_project/models/friend_request.dart';
import 'package:ru_project/models/user.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/services/logger.dart';
import 'package:ru_project/widgets/friends_request_widget.dart';
import 'package:ru_project/widgets/search_user_widget.dart';
import 'package:ru_project/widgets/chat_widget.dart';

class FriendsListButton extends StatelessWidget {
  const FriendsListButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          icon: Icon(Icons.people),
          label: Text('Mes amis'),
          onPressed: () => _showFriendsDialog(context),
        ),
      ],
    );
  }

  void _showFriendsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: FriendsListSheet(),
        );
      },
    );
  }
}

class FriendsListSheet extends StatefulWidget {
  const FriendsListSheet({super.key});

  @override
  State createState() => _FriendsListSheetState();
}

class _FriendsListSheetState extends State<FriendsListSheet>{
  List<User>? friends;
  List<FriendRequest>? friendsRequests;
  late ApiService apiService;
  late UserProvider userProvider;

  @override
  bool get wantKeepAlive => true; // Important !

  @override
  void initState() {
    super.initState();
    apiService = Provider.of<ApiService>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    friends = userProvider.friends;
  }

  static String generatePrivateRoomName(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort();
    return ids.join('_');
  }

  Future<void> addFriend(String friend) async {
    try {
      User? friendAdded = await apiService.addFriend(friend);
      if (friendAdded == null) {
        throw 'peut etre un jour des vrais messages d\'erreurs';
      } else {
        addFriendToFriendsList(friendAdded);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'ajout: $e')),
      );
    }
  }

  void addFriendToFriendsList(User friend) {
    setState(() {
      friends?.add(friend);
    });
  }

  void _showDeleteConfirmationDialog(String friendId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmation'),
        content: Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Supprimer', style: TextStyle(color: Colors.white)),
            onPressed: () {
              // Logique de suppression
              apiService.removeFriend(friendId);

              setState(() {
                friends?.removeWhere((friend) => friend.id == friendId);
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //super.build(context);
    //recuperer les demandes d'amis
    if (friendsRequests == null) {
      () async {
        try {
          Map<String, dynamic> response = await apiService.getFriendsRequests();
          if (!mounted) return;
          setState(() {
            friendsRequests = response['friendsRequests'];
          });
        } catch (e) {
          logger.e('Error loading friend requests: $e');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading friend requests: $e')),
          );
        }
      }();
    }
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Barre de drag
          Container(
            margin: EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mes amis',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),

            // Bouton de demande d'ami
            Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: IconButton(
              onPressed: () async {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                return FriendsRequestWidget(
                  initialFriendsRequests: friendsRequests,
                  apiService: apiService,
                  onAddFriend: addFriendToFriendsList,
                );
                }));
              },
              icon: (friendsRequests != null && friendsRequests!.isNotEmpty)
                ? Icon(Icons.notifications_active, color: Colors.red)
                : Icon(Icons.notifications),
              ),
            ),
            ),

          // Nombre d'amis
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${friends?.length} amis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
          ),

          friends == null
              ? Center(child: CircularProgressIndicator())
              : friends!.isEmpty
                  ? Expanded(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('HAHAHAH TA PAS DAMIS'),
                              SizedBox(height: 16),
                              Image.asset('assets/images/haha.webp'),
                            ],
                          )),
                    )
                  :
                  // Liste des amis
                  Expanded(
                      child: ListView.builder(
                        itemCount: friends?.length,
                        itemBuilder: (context, index) {
                          final friend = friends![index];
                          return GestureDetector(
                            onHorizontalDragEnd: (DragEndDetails details) {
                              if (details.primaryVelocity! > 0) {
                                // User swiped Left
                                _showDeleteConfirmationDialog(friend.id);
                              } else if (details.primaryVelocity! < 0) {
                                // User swiped Right
                                logger.i(
                                    'Swipe à droite sur ${friend?.username}');
                              }
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundImage: NetworkImage(apiService
                                    .getImageNetworkUrl(friend.avatarUrl)),
                              ),
                              title: Text(
                                friend.username,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(friend.status),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.message_outlined),
                                    onPressed: () {
                                      logger.i('Message à ${friend.username}');
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatWidget(
                                            roomname: generatePrivateRoomName(
                                                userProvider.user!.id,
                                                friend.id),
                                            actualUser: userProvider.user!,
                                            friends: [friend],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    color: Colors.red,
                                    icon: Icon(Icons.person_remove_rounded),
                                    onPressed: () {
                                      _showDeleteConfirmationDialog(friend.id);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                logger.i(
                                    'Profil de ${friend.username} sélectionné');
                              },
                            ),
                          );
                        },
                      ),
                    ),

          // Bouton d'ajout
          Padding(
            padding: EdgeInsets.all(16).copyWith(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        TextEditingController controller =
                            TextEditingController();
                        return AlertDialog(
                          title: Text('Ajouter un ami'),
                          content: TextField(
                            decoration: InputDecoration(
                              hintText: 'Nom d\'utilisateur',
                            ),
                            controller: controller,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                addFriend(controller.text);
                                controller.clear();
                                Navigator.of(context).pop();
                              },
                              child: Text('Ajouter'),
                            ),
                          ],
                        );
                      });
                },
                child: Text(
                  'Ajouter un ami',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          //bouton de d'ajout d'ami via une recherche
          Padding(
            padding: EdgeInsets.all(16).copyWith(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return RealtimeSearchWidget(
                      onRemoteSearch: apiService.searchUsers,
                      getImageNetworkUrl: apiService.getImageNetworkUrl,
                      addFriend: apiService.addFriend,
                      addFriendToFriendsList: addFriendToFriendsList,
                    );
                  }));
                },
                child: Text(
                  'Ajouter un ami via une recherche avancée',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
