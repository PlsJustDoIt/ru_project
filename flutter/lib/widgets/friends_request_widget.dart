import 'package:flutter/material.dart';
import 'package:ru_project/models/color.dart';
import 'package:ru_project/models/friends_request.dart';
import 'package:ru_project/services/api_service.dart';
import 'package:ru_project/models/message.dart';

class FriendsRequestWidget extends StatefulWidget {
  final List<FriendsRequest>? initialFriendsRequests;
  final ApiService apiService;

  const FriendsRequestWidget({
    super.key,
    required this.initialFriendsRequests,
    required this.apiService,
  });

  @override
  State<FriendsRequestWidget> createState() => _FriendsRequestWidgetState();
}

class _FriendsRequestWidgetState extends State<FriendsRequestWidget> {
  late List<FriendsRequest>? _friendsRequests;

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
                            bool res = await widget.apiService.acceptFriendRequest(request.requestId);
                            if (res) {
                              _removeFriendRequest(index);
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
                            bool res = await widget.apiService.rejectFriendRequest(request.requestId);
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