import 'package:flutter/material.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/models/friend_request.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/models/message.dart';
class FriendsRequestWidget extends StatefulWidget {
  final List<FriendRequest>? initialFriendsRequests;
  final ApiService apiService;
  final void Function(User friend) onAddFriend;

  const FriendsRequestWidget({
    super.key,
    required this.initialFriendsRequests,
    required this.apiService,
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
                  return Padding(padding: const EdgeInsets.all(8), child: 
                  ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(widget.apiService.getImageNetworkUrl(request.sender["avatarUrl"])),
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text('Demande d\'ami de ${request.sender["username"]}'),
                    subtitle: Text('Envoyée il y a ${timeAgo(DateTime.parse(request.createdAt)) }'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            bool res = await widget.apiService.handleFriendRequest(request.requestId, true);
                            if (res) {
                              _removeFriendRequest(index);
                              widget.onAddFriend(User(id: request.sender["id"], username: request.sender["username"], status:  'absent', avatarUrl: request.sender["avatarUrl"]));
                              if (_friendsRequests!.isEmpty && mounted) {
                                Navigator.pop(context);
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Erreur lors de l\'acceptation de la demande d\'amis'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            bool res = await widget.apiService.handleFriendRequest(request.requestId, false);
                            if (res) {
                              _removeFriendRequest(index);
                            } else {
                              if (!mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Erreur lors du rejet de la demande d\'amis'),
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