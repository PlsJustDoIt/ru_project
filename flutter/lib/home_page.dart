import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${userProvider.user?.username}'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              userProvider.logout();
              Navigator.pushReplacementNamed(context, '/login');
              
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Text('Status: ${userProvider.user?.status ?? 'Unknown'}'),
          ElevatedButton(
            onPressed: () async {
              await userProvider.updateStatus('Active');
            },
            child: Text('Set Status to Active'),
          ),
          // Liste des amis
          Expanded(
            child: ListView.builder(
              itemCount: userProvider.friends.length,
              itemBuilder: (context, index) {
                final friend = userProvider.friends[index];
                return ListTile(
                  title: Text(friend.username),
                  //subtitle: Text('Status: ${userProvider.friendsStatus[friend.id]}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
