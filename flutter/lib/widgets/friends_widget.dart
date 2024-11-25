
import 'package:flutter/material.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/logger.dart';

class FriendsListButton extends StatelessWidget {
  // Liste exemple d'amis
  final List<User> friends = [
    User(
      id: '1',
      username: 'Marie Dupont',
      avatarUrl : 'https://exemple.com/avatar.jpg',
      status: 'en ligne',
      friendIds:[],
    ),
    User(
      id: '2',
      username: 'Jean Martin',
      avatarUrl: 'https://exemple.com/avatar.jpg',
      status: 'au ru',
      friendIds:[],
    ),
    User(
      id: '3',
      username: 'Sophie Bernard',
      avatarUrl: 'https://exemple.com/avatar.jpg',
      status: 'en train de manger',
      friendIds:[],
    ),
  ];

  FriendsListButton({super.key});

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

class _FriendsListSheetState extends State<FriendsListSheet> {
  List<User> friends = [];

  @override
  void initState() {
    super.initState();
    // Appelle la fonction pour charger les amis au lancement du widget
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    // Remplace cette partie par ta requête pour récupérer les amis
    // List<User> fetchedFriends = await fetchFriendsFromApi();

    List<User> fetchedFriends = [
      User(
        id: '1',
        username: 'Marie Dupont',
        avatarUrl: 'https://exemple.com/avatar.jpg',
        status: 'en ligne',
        friendIds:[],
      ),
      User(
        id: '2',
        username: 'Jean Martin',
        avatarUrl: 'https://exemple.com/avatar.jpg',
        status: 'au ru',
        friendIds:[],
      ),
      User(
        id: '3',
        username: 'Sophie Bernard',
        avatarUrl: 'https://exemple.com/avatar.jpg',
        status: 'en train de manger',
        friendIds:[],
      ),
    ];

    // // Mets à jour l'état avec les amis récupérés
    setState(() {
      friends = fetchedFriends;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un ami...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),

          // Nombre d'amis
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${friends.length} amis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),

          // Liste des amis
          Expanded(
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    child: Text(friend.username[0]),
                    // backgroundImage: NetworkImage(friend.avatarUrl),
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
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.more_vert),
                        onPressed: () {
                          logger.i('Plus d\'options pour ${friend.username}');
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    logger.i('Profil de ${friend.username} sélectionné');
                  },
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
                  logger.i('Ajouter un nouvel ami');
                },
                child: Text(
                  'Ajouter un ami',
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
