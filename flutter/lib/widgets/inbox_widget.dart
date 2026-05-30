import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ru_project/models/message.dart';
import 'package:ru_project/models/user.dart';
import 'package:ru_project/providers/notification_provider.dart';
import 'package:ru_project/providers/user_provider.dart';
import 'package:ru_project/services/api_client.dart';
import 'package:ru_project/services/chat_connection.dart';
import 'package:ru_project/services/socket_service.dart';
import 'package:ru_project/widgets/chat_ui.dart';

/// Boîte de réception unifiée : Global épinglé + une ligne par ami,
/// avec aperçu du dernier message et horodatage.
class InboxWidget extends StatefulWidget {
  const InboxWidget({super.key});

  @override
  State<InboxWidget> createState() => _InboxWidgetState();
}

class _InboxWidgetState extends State<InboxWidget> {
  late final SocketService _socketService;
  late final ApiClient _apiClient;
  Map<String, Message?> _summaries = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _socketService = Provider.of<SocketService>(context, listen: false);
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _load();
  }

  Future<void> _load() async {
    final summaries = await _socketService.getConversations();
    if (!mounted) return;
    setState(() {
      _summaries = summaries;
      _loading = false;
    });
  }

  void _openRoom(String roomName, String title, {List<Friend>? friends}) {
    final user = Provider.of<UserProvider>(context, listen: false).user!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: ChatUi(
            roomName: roomName,
            actualUser: user,
            friends: friends,
          ),
        ),
      ),
    ).then((_) => _load());
  }

  String _preview(Message? message) {
    if (message == null) return 'Aucun message';
    return '${message.sender} : ${message.content}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final user = Provider.of<UserProvider>(context).user!;
    final friends = Provider.of<UserProvider>(context).friends;
    final notifications = context.watch<NotificationProvider>();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          // Global épinglé en haut
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.public)),
            title: const Text('Global'),
            subtitle: Text(
              _preview(_summaries['Global']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _trailing(_summaries['Global'], notifications.unreadFor('Global')),
            onTap: () => _openRoom('Global', 'Global'),
          ),
          const Divider(height: 1),

          // Une ligne par ami
          for (final friend in friends)
            _friendTile(user, friend, notifications),
        ],
      ),
    );
  }

  Widget? _trailing(Message? last, int unread) {
    if (last == null && unread == 0) return null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (last != null) Text(timeAgo(last.createdAt)),
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Badge(label: Text('$unread')),
          ),
      ],
    );
  }

  Widget _friendTile(User user, Friend friend, NotificationProvider notifications) {
    final roomName = ChatConnection.privateRoomName(user.id, friend.id);
    final last = _summaries[roomName];
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            NetworkImage(_apiClient.getImageNetworkUrl(friend.avatarUrl)),
      ),
      title: Text(friend.username),
      subtitle: Text(
        _preview(last),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _trailing(last, notifications.unreadFor(roomName)),
      onTap: () =>
          _openRoom(roomName, friend.username, friends: [friend]),
    );
  }
}
