import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/models/friend_request.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/friend_service.dart';

class FriendsRequestWidget extends StatefulWidget {
  final List<FriendRequest>? initialFriendsRequests;
  final FriendService friendService;
  final void Function(Friend friend) onAddFriend;

  const FriendsRequestWidget({
    super.key,
    required this.initialFriendsRequests,
    required this.friendService,
    required this.onAddFriend,
  });

  @override
  State<FriendsRequestWidget> createState() => _FriendsRequestWidgetState();
}

class _FriendsRequestWidgetState extends State<FriendsRequestWidget> {
  late List<FriendRequest>? _friendsRequests;

  @override
  void initState() {
    super.initState();
    _friendsRequests = widget.initialFriendsRequests;
  }

  void _removeFriendRequest(int index) {
    setState(() {
      _friendsRequests!.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ApiClient apiClient = Provider.of<ApiClient>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Demandes d\'amis'),
      ),
      body: Column(
        children: <Widget>[
          if (_friendsRequests == null || _friendsRequests!.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Aucune demande d\'amis'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _friendsRequests!.length,
                itemBuilder: (context, index) {
                  final request = _friendsRequests![index];
                  return Padding(
                      padding: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(apiClient
                              .getImageNetworkUrl(request.sender["avatarUrl"])),
                        ),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: AppColors.primaryColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Text(
                            'Demande d\'ami de ${request.sender["username"]}'),
                        subtitle: Text(
                            'Envoyée il y a ${timeAgo(DateTime.parse(request.createdAt))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(Icons.check),
                              onPressed: () async {
                                bool res = await widget.friendService
                                    .acceptFriendRequest(request.requestId);
                                if (res) {
                                  _removeFriendRequest(index);
                                  widget.onAddFriend(Friend(
                                      id: request.sender["id"],
                                      username: request.sender["username"],
                                      status: 'absent',
                                      avatarUrl: request.sender["avatarUrl"]));
                                  if (_friendsRequests!.isEmpty &&
                                      context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Erreur lors de l\'acceptation de la demande d\'amis'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                bool res = await widget.friendService
                                    .declineFriendRequest(request.requestId);
                                if (res) {
                                  _removeFriendRequest(index);
                                } else {
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Erreur lors du rejet de la demande d\'amis'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ));
                },
              ),
            ),
        ],
      ),
    );
  }
}
